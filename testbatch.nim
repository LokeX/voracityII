import batch
import win except strip
import times
import sequtils
import strutils

const 
  robotoRegular = "fonts\\Roboto-Regular_1.ttf"
  condensedRegular = "fonts\\AsapCondensed-Regular.ttf"
  fjallaOneRegular = "fonts\\FjallaOne-Regular.ttf"
  menuEntries:seq[string] = @[
    "Main Menu\n",
    "\n",
    "Clock\n",
    "Select\n",
    "Write\n",
    "Quit",
    "\n",
  ]
  titleBorder:Border = (size:0,angle:0,color:color(0,0,100))
  selectorBorder:Border = (2,20,color(1,0,0))
  menuBatchInit = BatchInit(
    kind:MenuBatch,
    name:"menuBatch",
    titleOn:true,
    titleLine:(color:color(1,1,0),bgColor:color(0,0,100),border:titleBorder),
    pos:(100,100),
    padding:(40,40,0,0),
    entries:menuEntries,
    hAlign:CenterAlign,
    font:(robotoRegular,50.0,color(1,1,1)),
    bgColor:color(0,0,0),
    # opacity:100,
    selectorLine:(color(0,0,0),color(1,1,1),selectorBorder),
    selectionRange:2..5,
    border:(15,5,color(0,0,100)),
    shadow:(15,1.5,color(255,255,255,200))
  )
  textEntries:seq[string] = @[
    "Copenhagen time:",
    "\n",
    "",
    "\n",
  ]
  textBatchInit = BatchInit(
    kind:TextBatch,
    name:"textBatch",
    titleOn:true,
    titleLine:(color:color(1,1,1),bgColor:color(0,0,0),border:titleBorder),
    pos:(1000,100),
    padding:(40,40,0,0),
    entries:textEntries,
    hAlign:LeftAlign,
    # opacity:100,
    font:(fjallaOneRegular,50.0,color(1,0,0)),
    bgColor:color(0,100,0),
    border:(5,10,color(10,10,0)),
    shadow:(10,1.75,color(255,255,255,200))
  )
  inputMenuEntries:seq[string] = @[
    "Select:\n",
    # "\n",
    "1. New game\n",
    "2. Reveal code\n",
    "3. Quit\n",
  ]
  inputMenuBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputMenuBatchInit = BatchInit(
    kind:InputBatch,
    name:"inputBatch",
    titleOn:true,
    titleLine:(color:color(1,1,0),bgColor:color(0,0,0),border:titleBorder),
    pos:(100,600),
    inputCursor:(0.5,color(0,1,0)),
    inputLine:(color(0,1,0),color(0,0,0),inputMenuBorder),
    padding:(40,40,10,10),
    entries:inputMenuEntries,
    inputMaxChars:1,
    inputNumbers:1..3,
    font:(condensedRegular,30.0,color(1,1,1)),
    bgColor:color(0,0,0),
    border:(15,5,color(0,0,100)),
    shadow:(15,1.5,color(255,255,255,200))
  )
  inputEntries:seq[string] = @[
    "Write something:\n",
    "\n",
  ]
  inputBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBatchInit = BatchInit(
    kind:InputBatch,
    name:"inputBatch",
    titleOn:true,
    titleLine:(color:color(1,1,0),bgColor:color(0,0,0),border:titleBorder),
    pos:(600,200),
    inputCursor:(0.5,color(0,1,0)),
    inputLine:(color(0,1,0),color(0,0,0),inputBorder),
    padding:(40,40,10,10),
    entries:inputEntries,
    inputMaxChars:75,
    font:(condensedRegular,30.0,color(1,1,1)),
    bgColor:color(0,0,0),
    border:(15,5,color(0,0,100)),
    shadow:(15,1.5,color(255,255,255,200))
  )
  selections = [
    "Clock\n",
    "Select\n",
    "Write\n",
    "Quit",
  ]

let 
  bgPic = readImage "pics\\bgblue.png"
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)

var
  menuBatch = newBatch menuBatchInit
  textBatch = newBatch textBatchInit
  inputBatch = newBatch inputBatchInit
  inputMenuBatch = newBatch inputMenuBatchInit
  batches = [textBatch,inputMenuBatch,inputBatch,menuBatch]

template menuSelection:int =
  selections.find(menuEntries[menuBatch.selection])

proc draw(b:var Boxy) =
  b.drawImage("bg",bgRect)
  for batch in batches:
    if batch.isActive:
      b.drawBatch batch

proc keyboard(k:KeyboardEvent) = 
  for batch in batches:
    if batch.isActive:
      if batch.kind == MenuBatch and k.down KeyEnter:
        echo menuEntries[batch.selection].strip
        if menuSelection == batches.high:
          window.closeRequested = true
      else: k.batchKeyb batch

proc mouseMoved =
  if mouseOn menuBatch: 
    menuBatch.mouseSelect

template updateClock =
  textBatch.setSpanText("\n"&now().format("hh:mm:ss"),2)
  textBatch.update = true

proc time = 
  if textBatch.isActive: updateClock

proc cycle = 
  let idx = menuSelection
  for i,batch in batches[0..batches.high-1]:
    batch.isActive = i == idx

template timer:TimerCall = TimerCall(
  call:time,
  lastTime:cpuTime(),
  secs:1
)

template call:Call = Call(
  draw:draw,
  keyboard:keyboard,
  mouseMoved:mouseMoved,
  timer:timer,
  cycle:cycle
)

let test = inputBatch.commands:
  inputBatch.input.cursor.blinkPrSec = 0.2
  inputBatch.area
echo test

inputBatch.isActive = false
inputMenuBatch.isActive = false
textBatch.isActive = false
updateClock
addCall call
addImage("bg",bgPic)
var count = 0
runWinWith: 
  callTimers()
  inc count
  if count > 5:
    callCycles()
    count = 0
