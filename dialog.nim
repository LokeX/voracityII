import batch
import strutils
import win except strip

const
  thisDialog = "dialog"
  robotoRegular = "fonts\\Roboto-Regular_1.ttf"

var 
  selectorBorder*:Border = (0,10,color(1,0,0))
  menuBatchInit* = BatchInit(
    kind:MenuBatch,
    name:"kill_dialog",
    centerOnWin:true,
    padding:(20,20,20,20),
    hAlign:CenterAlign,
    font:(robotoRegular,25.0,color(1,1,0)),
    bgColor:color(0,0,0),
    opacity:50,
    selectorLine:(color(1,1,1),color(0,0,100),selectorBorder),
    border:(5,15,color(1,1,1)),
    shadow:(15,1.5,color(255,255,255,200))
  )
  menuEntries:seq[string] = @[
    "Remove piece on:\n",
    "Townhall nr.4?\n",
    "\n",
    "Yes\n",
    "No",
  ]
  menuBatch:Batch
  returnSelection:proc(s:string)

proc recieveMessage(message:string) =
  echo message

proc startDialog*(entries:seq[string],selRange:HSlice[int,int],call:proc(s:string)) =
  menuEntries = entries
  menuBatchInit.entries = entries
  menuBatchInit.selectionRange = selRange
  menuBatch = newBatch menuBatchInit
  returnSelection = call
  pushCalls()
  excludeInputCallsExcept thisDialog
  menuBatch.isActive = true

proc endDialog(selected:string) =
  menuBatch.isActive = false
  popCalls()
  returnSelection selected

proc draw(b:var Boxy) =
  if menuBatch != nil and menuBatch.isActive:
    b.drawDynamicImage menuBatch

proc keyboard(k:KeyboardEvent) = 
  if menuBatch.isActive and k.down KeyEnter:
    endDialog menuEntries[menuBatch.selection].strip
  else: k.batchKeyb menuBatch

proc mouse(m:KeyEvent) =
  if m.leftMousePressed and menuBatch.mouseOnSelectionArea != -1:
    endDialog menuEntries[menuBatch.selection].strip

proc mouseMoved =
  if menuBatch.isActive and mouseOn menuBatch: 
    menuBatch.mouseSelect

var 
  dialogCall* = Call(
    reciever:thisDialog,
    draw:draw,
    keyboard:keyboard,
    mouse:mouse,
    mouseMoved:mouseMoved,
    active:false
  )

when isMainModule:
  addCall dialogCall
  startDialog(menuEntries,3..4,recieveMessage)
  runWin
