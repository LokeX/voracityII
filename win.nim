import boxy, opengl 
import windy
import times

export boxy 
export windy

type
  Direction* = enum Up,Down,Right,Left
  Area* = tuple[x1,y1,x2,y2:int]
  AreaHandle* = ref object of RootObj
    name*:string
    area*:Area
    rect*:Rect
    isActive*:bool = true
  DynamicImage*[T] = ref object of AreaHandle
    when T is void:
      updateImage*:proc:Image
    else:
      updateImage*:proc(context:T):Image
      context*:T
    update*:bool
    animRect:proc:Rect
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

proc initMove(r:Rect,direction:Direction,frames:int):proc:Rect =
  var zr = r
  case direction:
  of Up: zr.y = scaledHeight.toFloat+zr.h
  of Down: zr.y -= zr.h
  of Left: zr.x = scaledWidth.toFloat-zr.w
  of Right: zr.x -= zr.w
  return
    proc:Rect =
      case direction:
      of Up: 
        zr.y -= frames.toFloat
        if zr.y <= r.y: zr.y = r.y
      of Down: 
        zr.y += frames.toFloat
        if zr.y >= r.y: zr.y = r.y
      of Left: 
        zr.x -= frames.toFloat
        if zr.x <= r.x: zr.x = r.x
      of Right: 
        zr.x += frames.toFloat
        if zr.x >= r.x: zr.x = r.x
      zr

proc initZoom*(r:Rect,frames:int):proc:Rect =
  var
    # zw = if r.w > r.h: r.w / r.h else: 1.0
    # zh = if zw == 1.0: r.h / r.w else: 1.0
    zw = r.w / frames.toFloat
    zh = r.h / frames.toFloat
  var zr = Rect(
    x:r.x+(r.w / 2),
    y:r.y+(r.h / 2),
    w:zw,
    h:zh
  )
  # echo "org rect: ",zr
  return 
    proc:Rect =
      zr.x -= zw
      if zr.x-zw <= r.x: 
        # echo "x done"
        return r
      zr.y -= zh
      if zr.y-zh <= r.y: 
        # echo "y done"
        return r
      zr.w += (zw*2)
      if zr.w+(zw*2) >= r.w: 
        # echo "w done"
        return r
      zr.h += (zh*2)
      if zr.h+(zh*2) >= r.h: 
        # echo "h done"
        return r
      zr

proc dynamicZoom*[T](dynImg:var DynamicImage[T],frames:int) =
  dynImg.animRect = dynImg.rect.initZoom frames

proc dynamicMove*[T](dynImg:var DynamicImage[T],direction:Direction,frames:int) =
  dynImg.animRect = dynImg.rect.initMove(direction,frames)

proc drawDynamicImage*[T](b:var Boxy,dynImg:DynamicImage[T]) =
  if dynImg.update: 
    b.removeImage(dynImg.name)
    when T is void: b.addImage(dynImg.name,dynImg.updateImage())
    else: b.addImage(dynImg.name,dynImg.updateImage(dynImg.context))
    let wh = b.getImageSize dynImg.name
    dynImg.area.x2 = dynImg.area.x1+wh[0]
    dynImg.area.y2 = dynImg.area.y1+wh[1]
    dynImg.rect = dynImg.area.toRect
    dynImg.update = false
  if dynImg.animRect == nil:
    b.drawImage(dynImg.name,dynImg.rect)
  else:
    let animRect = dynImg.animRect()
    b.drawImage(dynImg.name,animRect)
    if dynImg.rect == animRect:
      dynImg.animRect = nil
    
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
    if call.active:
      if button.isMouseKey:
        if call.mouse != nil: 
          call.mouse(newKeyEvent(button))
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
    if call.cycle != nil: call.cycle()

proc callTimers* =
  for call in calls.mitems:
    if call.timer.call != nil:
      if cpuTime()-call.timer.lastTime > call.timer.secs:
        call.timer.lastTime = cpuTime()
        call.timer.call()

template runWinWith*(body:untyped) =
  window.visible = true
  while not window.closeRequested:
    # sleep 5
    pollEvents()
    body

template runWin* = 
  runWinWith:discard
