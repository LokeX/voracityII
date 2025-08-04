import batch
import game
import strutils
import win except strip,splitWhitespace
from graphics import moveToSquaresPainter

const
  thisDialog = "dialog"
  robotoRegular* = "fonts\\Roboto-Regular_1.ttf"

var 
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
  dialogEntries:seq[string]
  dialogBatch:Batch
  returnSelection:proc(s:string)
  square = -1

proc startDialog*(entries:seq[string],selRange:HSlice[int,int],call:proc(s:string)) =
  square = -1
  dialogEntries = entries
  menuBatchInit.entries = entries
  menuBatchInit.selectionRange = selRange
  dialogBatch = newBatch menuBatchInit
  returnSelection = call
  pushCalls()
  excludeInputCallsExcept thisDialog
  dialogBatch.isActive = true
  dialogBatch.update = true
  dialogBatch.dynMove(Up,13)

proc endDialog(selected:string) =
  square = -1
  dialogBatch.isActive = false
  popCalls()
  returnSelection selected

proc draw(b:var Boxy) =
  if dialogBatch != nil and dialogBatch.isActive:
    b.drawDynamicImage dialogBatch

proc keyboard(k:KeyboardEvent) = 
  if dialogBatch.isActive and k.pressedIs KeyEnter:
    endDialog dialogEntries[dialogBatch.selection].strip
  else: k.batchKeyb dialogBatch

proc mouse(m:KeyEvent) =
  if dialogBatch.isActive and m.leftMousePressed and dialogBatch.mouseOnSelectionArea != -1:
    dialogBatch.mouseSelect
    endDialog dialogEntries[dialogBatch.selection].strip

proc mouseMoved =
  if dialogBatch.isActive and mouseOn dialogBatch:
    dialogBatch.mouseSelect
    let selectedSquare = try: 
      dialogEntries[dialogBatch.selection]
      .splitWhitespace[^1]
      .parseInt 
    except: -1
    if selectedSquare notin [-1,square]:
      square = selectedSquare
      moveToSquaresPainter.context = @[square]
      moveToSquaresPainter.update = true
      if dialogEntries[dialogBatch.selection].startsWith "from":
        moveSelection.fromSquare = square #yeah, it's a hack

var 
  dialogCall* = Call(
    reciever:thisDialog,
    draw:draw,
    keyboard:keyboard,
    mouse:mouse,
    mouseMoved:mouseMoved,
    active:false
  )

