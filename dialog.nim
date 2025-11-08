import win
import batch
import sugar

const
  thisDialog = "dialog"
  robotoRegular* = "fonts\\Roboto-Regular_1.ttf"
  selectorBorder*:Border = (0,10,color(1,0,0))
  menuBatchInit* = BatchInit(
    kind:MenuBatch,
    name:"dialog",
    pos:(875,275),
    padding:(50,50,20,20),
    hAlign:CenterAlign,
    font:(robotoRegular,26.0,color(1,1,0)),
    bgColor:color(0,0,0),
    opacity:25,
    selectorLine:(color(1,1,1),color(0,0,100),selectorBorder),
    border:(0,15,color(1,1,1)),
    shadow:(15,1.5,color(255,255,255,150))
  )

var 
  dialogBatch* = newBatch menuBatchInit
  returnSelection:proc(s:string)
  dialogOnMouseMoved*:proc()

proc endDialog(selected:string) =
  dialogBatch.isActive = false
  dialogOnMouseMoved = nil
  popCalls()
  returnSelection selected

proc draw(b:var Boxy) =
  if dialogBatch != nil and dialogBatch.isActive:
    b.drawDynamicImage dialogBatch

proc keyboard(k:KeyboardEvent) = 
  if dialogBatch.isActive and k.pressedIs KeyEnter:
    endDialog dialogBatch.stringSelection
  else: k.batchKeyb dialogBatch

proc mouseClicked(m:KeyEvent) =
  if dialogBatch.isActive and m.leftMousePressed and dialogBatch.mouseOnSelectionArea != -1:
    dialogBatch.mouseSelect
    endDialog dialogBatch.stringSelection

proc mouseMoved =
  if dialogBatch.isActive and mouseOn dialogBatch:
    dialogBatch.mouseSelect
    if dialogOnMouseMoved != nil:
      dialogOnMouseMoved()

var 
  dialogCall* = Call(
    reciever:thisDialog,
    draw:draw,
    keyboard:keyboard,
    mouseClick:mouseClicked,
    mouseMoved:mouseMoved,
    active:true
  )

proc startDialog*(entries:seq[string],selRange:HSlice[int,int],call:proc(s:string)) =
  dialogBatch.resetMenu(entries,selRange)
  returnSelection = call
  pushCalls()
  excludeInputCalls()
  addCall dialogCall
  dialogBatch.isActive = true
  dialogBatch.update = true
  dialogBatch.dynMove(Up,13)

proc really*(title:string,answer:string -> void) =
  let entries = @[
    "Really "&title&"\n",
    "\n",
    "Yes\n",
    "No",
  ]
  startDialog(entries,2..3,answer)

