import boxy, opengl 
import windy
import os
import times

export boxy 
export windy
export os

type
  Area* = tuple[x1,y1,x2,y2:int]
  AreaHandle* = ref object of RootObj
    name*:string
    area*:Area
    rect*:Rect
    isActive*:bool = true
  DynamicImage*[T] = ref object of AreaHandle
    image*:Image
    when T is void:
      updateImage*:proc:Image
    else:
      updateImage*:proc(context:T):Image
      context*:T
    update*:bool
  KeyState = tuple[down,released,toggle:bool]
  SpecialKeys = tuple[ctrl,shift,alt:bool]
  KeyEvent* = object of RootObj
    keyState*:KeyState
    button*:Button
  KeyboardEvent* = object of KeyEvent
    rune*:Rune
    pressed*:SpecialKeys
  TimerCall* = object
    call*:proc()
    lastTime*:float
    secs*:float
  Call* = object
    reciever*:string
    active* = true
    mouseMoved*:proc()
    keyboard*:proc(keyboard:KeyboardEvent)
    mouse*:proc(mouse:KeyEvent)
    draw*:proc(boxy:var Boxy)
    cycle*:proc()
    timer*:TimerCall

let 
  window* = newWindow(
    "",
    ivec2(800,600),
    WindowStyle.DecoratedResizable, 
    visible = false
  )
  scr = getScreens()[0]
  scrWidth* = (int32)scr.right
  scrHeight* = (int32)scr.bottom
  winWidth* = scrWidth-(scrWidth div 50)
  winHeight* = scrHeight-(scrHeight div 10)
  boxyScale*: float = scrHeight/1080
  scaledHeight* = (int)(winHeight.toFloat/boxyScale)
  scaledWidth* = (int)(winWidth.toFloat/boxyScale)
echo "Scale: ",boxyScale

window.size = ivec2(winWidth,winHeight)
window.pos = ivec2((scrWidth-winWidth) div 2,(scrHeight-winHeight) div 3)
window.runeInputEnabled = true
window.makeContextCurrent
loadExtensions()

var
  calls:seq[Call]
  specialKeys:SpecialKeys
  bxy = newBoxy()

bxy.scale(boxyScale)

proc addCall*(call:Call) = calls.add(call)

proc excludeInputCallsExcept*(reciever:string) =
  for call in calls.mitems:
    call.active = call.reciever == reciever

proc includeInputCallsExcept*(reciever:string) =
  for call in calls.mitems:
    call.active = call.reciever != reciever

proc includeAllCalls* =
  for call in calls.mitems:
    call.active = true

proc removeImg*(key:string) =
  bxy.removeImage key

proc setFont*(font:var Font,size:float = 12.0,color:Color = color(1,1,1)) =
  font.paint = color
  font.size = size

proc setNewFont*(typeFacePath:string,size:float = 12.0,color:Color = color(1,1,1)):Font =
  result = newFont(typeFacePath.readTypeface)
  result.paint = color
  result.size = size

func setNewFont*(typeFace:Typeface,size:float = 12.0,color:Color = color(1,1,1)):Font =
  result = newFont(typeFace)
  result.paint = color
  result.size = size

proc addImage*(key:string,img:Image) = bxy.addImage(key,img)
  
func keyReleased*(event:KeyEvent):bool = event.keyState.released

func keyPressed*(event:KeyEvent):bool = event.keyState.down

func down*(event:KeyboardEvent,b:Button):bool = 
  event.keyState.down and event.button == b

func isKey*(b1:Button,b2:Button):bool = b1 == b2

func hasRune*(k:KeyboardEvent):bool = k.rune.toUTF8 != "¤"

func leftMousePressed*(m:KeyEvent):bool =
  m.keyState.down and m.button == MouseLeft

func rightMousePressed*(m:KeyEvent):bool =
  m.keyState.down and m.button == MouseRight

proc scaledMousePos*:(int,int) =
  ((int)(window.mousepos[0].toFloat/boxyScale),
  (int)(window.mousepos[1].toFloat/boxyScale))

template withScaledMousePos*(x,y,body:untyped) =
  let (x,y) = scaledMousePos()
  body

proc mouseOn*(area:Area):bool =
  let (mx,my) = scaledMousePos()
  area.x1 <= mx and area.y1 <= my and mx <= area.x2 and my <= area.y2

proc mouseOn*(handle:AreaHandle):bool = mouseOn handle.area

func imageArea*(area:Area,img:Image):Area =
  (area.x1,area.y1,area.x1+img.width,area.y1+img.height)

func imageArea*(x,y:int,img:Image):Area = (x,y,x+img.width,y+img.height)

template area_wh*(area:Area,body:untyped) =
  let
    width {.inject.} = area.x2-area.x1
    height {.inject.} = area.y2-area.y1
  body

func area_wh*(area:Area):(int,int) = (area.x2-area.x1,area.y2-area.y1)

func toArea*(x,y,w,h:float):Area = (x.toInt,y.toInt,(x+w).toInt,(y+h).toInt)

func toArea*(rect:Rect):Area =
  (rect.x.toInt,rect.y.toInt,(rect.x+rect.w).toInt,(rect.y+rect.h).toInt)

func toRect*(area:Area):Rect = 
  Rect(
    x:area.x1.toFloat,
    y:area.y1.toFloat,
    w:(area.x2-area.x1).toFloat,
    h:(area.y2-area.y1).toFloat
  )

func rectangle*(rx,ry,rw,rh:int):Rect = 
  Rect(
    x:rx.toFloat,
    y:ry.toFloat,
    w:rw.toFloat,
    h:rh.toFloat
  )

proc updateImageArea*[T](dynImg:DynamicImage[T]) =
  when T is void:
    dynImg.image = dynImg.updateImage()
  else:
    dynImg.image = dynImg.updateImage(dynImg.context)
  dynImg.area.x2 = dynImg.area.x1+dynImg.image.width
  dynImg.area.y2 = dynImg.area.y1+dynImg.image.height
  dynImg.rect = dynImg.area.toRect

proc updateDynamicImage*[T](b:var Boxy,dynImg:DynamicImage[T]) =
  if dynImg.updateImage != nil: 
    updateImageArea dynImg
    b.removeImage(dynImg.name)
    b.addImage(dynImg.name,dynImg.image)
    dynImg.update = false

proc drawDynamicImage*[T](b:var Boxy,dynImg:DynamicImage[T]) =
  if dynImg.update: b.updateDynamicImage dynImg
  b.drawImage(dynImg.name,dynImg.rect)

# proc drawImageArea*(b:var Boxy,imageArea:ImageArea) =
#   b.drawImage(imageArea.name,imageArea.area.toRect)

proc keyState(b:Button):KeyState =
  (window.buttonDown[b],window.buttonReleased[b],window.buttonToggle[b])

proc specKeys(b:Button):SpecialKeys =
  case b:
    of KeyLeftShift,KeyRightShift: specialKeys.shift = b.keyState.down
    of KeyLeftControl,KeyRightControl: specialKeys.ctrl = b.keyState.down
    of KeyLeftAlt,KeyRightAlt: specialKeys.alt = b.keyState.down
    else:discard
  specialKeys

proc newKeyboardEvent(b:Button,r:Rune):KeyboardEvent = 
  KeyboardEvent(pressed:specKeys(b),rune:r,keyState:keyState(b),button:b)

proc newKeyEvent(b:Button):KeyEvent = 
  KeyEvent(keyState:keyState(b),button:b)

func isMouseKey(button:Button):bool = 
  button in [
    MouseLeft,MouseRight,MouseMiddle,
    DoubleClick,TripleClick,QuadrupleClick
  ]

proc callBack(button:Button) =
  for call in calls:
    if button.isMouseKey:
      if call.mouse != nil and call.active: 
        call.mouse(newKeyEvent(button))
    elif call.keyboard != nil and call.active: 
      call.keyboard(newKeyboardEvent(button,"¤".toRunes[0]))

window.onButtonRelease = proc(button:Button) = button.callBack

window.onButtonPress = proc(button:Button) =
  if button == KeyF12:
    window.closeRequested = true
  else: button.callBack

window.onFrame = proc() =
  glClear(GL_COLOR_BUFFER_BIT)  
  bxy.beginFrame(window.size)
  for call in calls:
    if call.draw != nil: call.draw(bxy)
  bxy.endFrame()
  window.swapBuffers()

window.onRune = proc(rune:Rune) =
  var button:Button
  for call in calls:
    if call.keyboard != nil and call.active: 
      call.keyboard(newKeyboardEvent(button,rune))

window.onMouseMove = proc() =
  for call in calls:
    if call.mouseMoved != nil and call.active: 
      call.mouseMoved()

proc callCycles* =
  for call in calls:
    if call.cycle != nil and call.active: call.cycle()

proc callTimers* =
  for call in calls.mitems:
    if call.timer.call != nil and call.active:
      if cpuTime()-call.timer.lastTime > call.timer.secs:
        call.timer.lastTime = cpuTime()
        call.timer.call()

template runWinWith*(body:untyped) =
  window.visible = true
  while not window.closeRequested:
    sleep 5
    pollEvents()
    body

template runWin* = 
  runWinWith:discard
