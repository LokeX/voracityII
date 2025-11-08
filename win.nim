import boxy, opengl 
import windy
import times
import sequtils

export boxy 
export windy

type
  Direction* = enum Up,Down,Right,Left
  Area* = tuple[x1,y1,x2,y2:int]
  AreaHandle* = ref object of RootObj
    name*:string
    area*:Area
    rect*:Rect
    center*:Vec2
    isActive*:bool = true
  DynamicImage*[T] = ref object of AreaHandle
    when T is void:
      updateImage*:proc:Image
    else:
      updateImage*:proc(context:T):Image
      context*:T
    update*:bool
    angle*:float32
    scale*:float32 = 1.0
    rotate*:proc:float32
    zoom*:proc:float32
    move*:proc:Rect
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
    mouseClick*:proc(mouse:KeyEvent)
    draw*:proc(boxy:var Boxy)
    cycle*:proc()
    timer*:TimerCall

let 
  window* = newWindow(
    "",
    ivec2(800,600),
    WindowStyle.DecoratedResizable, 
    visible = false,
    # vsync = false
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
  pushedCalls,calls:seq[Call]
  specialKeys:SpecialKeys
  bxy = newBoxy()

bxy.scale(boxyScale)

proc pushCalls* =
  pushedCalls = calls

proc popCalls* =
  calls = pushedCalls

proc addCall*(call:Call) = 
  calls.add(call)

proc excludeInputCalls* =
  for call in calls.mitems:
    call.active = false

# proc excludeInputCallsExcept*(reciever:string) =
#   for call in calls.mitems:
#     call.active = call.reciever == reciever

# proc includeInputCallsExcept*(reciever:string) =
#   for call in calls.mitems:
#     call.active = call.reciever != reciever

# proc includeAllCalls* =
#   for call in calls.mitems:
#     call.active = true

proc removeImg*(key:string) =
  bxy.removeImage key

proc setFont*(font:var Font,size:float = 12.0,color:Color = color(1,1,1)) =
  font.paint = color
  font.size = size

proc setNewFont*[T:Typeface or string](typeFace:T,size:float = 12.0,color:Color = color(1,1,1)):Font =
  result = newFont(
    when T is string:
      typeFace.readTypeface
    else: typeFace
  )
  result.paint = color
  result.size = size

proc addImage*(key:string,img:Image) = bxy.addImage(key,img)
  
func keyReleased*(event:KeyEvent):bool = event.keyState.released

func keyPressed*(event:KeyEvent):bool = event.keyState.down

func pressedIs*(event:KeyboardEvent,b:Button):bool = 
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

template mouseOn*(handle:AreaHandle):bool = mouseOn handle.area

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

func toRect*(area:Area):Rect = Rect(
  x:area.x1.toFloat,
  y:area.y1.toFloat,
  w:(area.x2-area.x1).toFloat,
  h:(area.y2-area.y1).toFloat
)

func rectangle*(rx,ry,rw,rh:int):Rect = Rect(
  x:rx.toFloat,
  y:ry.toFloat,
  w:rw.toFloat,
  h:rh.toFloat
)

func rectCenter*(r:Rect):Vec2 =
  result.x = r.x+(r.w/2)
  result.y = r.y+(r.h/2)

proc moveImage*(r:Rect,direction:Direction,frames:int):proc:Rect =
  var 
    zr = r
    ff:float
  case direction:
  of Up: 
    zr.y = scaledHeight.toFloat+zr.h
    ff = (zr.y-r.y)/frames.toFloat
  of Down: 
    zr.y -= zr.h
    ff = (r.y-zr.y)/frames.toFloat
  of Left: 
    zr.x = scaledWidth.toFloat-zr.w
    ff = (zr.x-r.x)/frames.toFloat
  of Right: 
    zr.x -= zr.w
    ff = (r.x-zr.x)/frames.toFloat
  return
    proc:Rect =
      case direction:
      of Up: 
        if zr.y < r.y: zr.y = r.y
        else: zr.y -= ff
      of Down: 
        if zr.y > r.y: zr.y = r.y
        else: zr.y += ff
      of Left: 
        if zr.x < r.x: zr.x = r.x
        else: zr.x -= ff
      of Right: 
        if zr.x > r.x: zr.x = r.x
        else: zr.x += ff
      zr
 
proc rotateImage*(frames:float32):proc:float32 =
  const maxAngle = 132
  var
    angleFactor = maxAngle/frames
    angle = angleFactor/2
  return 
    proc:float32 =
      if angle > 0:
        if angle < angleFactor:
          angle = angleFactor
        else: angle += angleFactor
        if angle > maxAngle: angle = 0
      angle

proc zoomImage*(frames:float32):proc:float32 =
  var
    scaleFactor = 1/frames
    scale:float32
  return 
    proc:float32 =
      scale += scaleFactor
      if scale > 1: scale = 1
      scale

proc dynMove*[T](dynImg:var DynamicImage[T],direction:Direction,frames:int) =
  dynImg.move = dynImg.rect.moveImage(direction,frames)

proc drawDynamicImage*[T](b:var Boxy,dynImg:DynamicImage[T]) =
  if dynImg.update: 
    b.removeImage(dynImg.name)
    when T is void: b.addImage(dynImg.name,dynImg.updateImage())
    else: b.addImage(dynImg.name,dynImg.updateImage(dynImg.context))
    let wh = b.getImageSize dynImg.name
    dynImg.rect.w = wh[0].toFloat
    dynImg.rect.h = wh[1].toFloat
    dynImg.area = dynImg.rect.toArea
    dynImg.center = dynImg.rect.rectCenter()
    dynImg.update = false
  if dynImg.move != nil:
    var moveRect = dynImg.move() 
    if dynImg.rect == moveRect: dynImg.move = nil
    dynImg.center = moveRect.rectCenter
  if dynImg.rotate != nil:
    dynImg.angle = dynImg.rotate()
    if dynImg.angle == 0: dynImg.rotate = nil
  if dynImg.zoom != nil:
    dynImg.scale = dynImg.zoom()
    if dynImg.scale == 1: dynImg.zoom = nil
  b.drawImage(dynImg.name,dynImg.center,dynImg.angle,scale = dynImg.scale)

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
  for call in calls.filterIt it.active:
    # if call.active:
    if button.isMouseKey:
      if call.mouseClick != nil: 
        call.mouseClick(newKeyEvent(button))
    elif call.keyboard != nil: 
      call.keyboard(newKeyboardEvent(button,"¤".toRunes[0]))

window.onButtonRelease = proc(button:Button) = button.callBack

window.onButtonPress = proc(button:Button) =
  if button == KeyF12:
    window.closeRequested = true
  else: button.callBack

window.onFrame = proc() =
  glClear(GL_COLOR_BUFFER_BIT)  
  bxy.beginFrame(window.size)
  for call in calls.filterIt it.draw != nil:
    call.draw(bxy)
  bxy.endFrame()
  window.swapBuffers()

window.onRune = proc(rune:Rune) =
  var button:Button
  for call in calls.filterIt it.keyboard != nil and it.active:
    call.keyboard(newKeyboardEvent(button,rune))

window.onMouseMove = proc() =
  for call in calls.filterIt it.mouseMoved != nil and it.active:
    call.mouseMoved()

proc callCycles* =
  for call in calls.filterIt it.cycle != nil and it.active:
    call.cycle()

proc timerCalls:seq[(int,Call)] =
  for idx,call in calls:
    if call.timer.call != nil and call.active:
      result.add (idx,call)

proc callTimers* =
  for (idx,call) in timerCalls():
    if cpuTime()-call.timer.lastTime > call.timer.secs:
      calls[idx].timer.lastTime = cpuTime()
      call.timer.call()

template runWinWith*(body:untyped) =
  window.visible = true
  while not window.closeRequested:
    pollEvents()
    body

template runWin* = 
  runWinWith:discard
