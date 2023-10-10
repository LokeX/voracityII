import batch
import strutils
import win except strip

const
  thisDialog = "dialog"
  robotoRegular* = "fonts\\Roboto-Regular_1.ttf"
  menuPos:tuple[x,y:int] = (875,275)

var 
  selectorBorder*:Border = (0,10,color(1,0,0))
  menuBatchInit* = BatchInit(
    kind:MenuBatch,
    name:"dialog",
    pos:(menuPos.x,scaledHeight),
    padding:(20,20,20,20),
    hAlign:CenterAlign,
    font:(robotoRegular,25.0,color(1,1,0)),
    bgColor:color(0,0,0),
    opacity:25,
    selectorLine:(color(1,1,1),color(0,0,100),selectorBorder),
    border:(0,15,color(1,1,1)),
    shadow:(15,1.5,color(255,255,255,150))
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

proc startDialog*(entries:seq[string],selRange:HSlice[int,int],call:proc(s:string)) =
  menuEntries = entries
  menuBatchInit.entries = entries
  menuBatchInit.selectionRange = selRange
  menuBatch = newBatch menuBatchInit
  returnSelection = call
  pushCalls()
  excludeInputCallsExcept thisDialog
  menuBatch.setPos(menuPos.x,scaledHeight)
  menuBatch.isActive = true
  menuBatch.update = true
  echo "dialog started"

proc endDialog(selected:string) =
  menuBatch.setPos(menuPos.x,scaledHeight)
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
  if menuBatch.isActive and m.leftMousePressed and menuBatch.mouseOnSelectionArea != -1:
    echo "end dialog"
    endDialog menuEntries[menuBatch.selection].strip

proc mouseMoved =
  if menuBatch.isActive and mouseOn menuBatch: 
    menuBatch.mouseSelect

proc cycle =  
  if menuBatch != nil and (let (_,y) = menuBatch.pos; y != menuPos.y):
    if y > menuPos.y:
      menuBatch.setShallowPos(menuPos.x,y-60)
    else: 
      menuBatch.setShallowPos(menuPos.x,y+1)
      if menuBatch.pos.y == menuPos.y:
        menuBatch.setPos(menuPos.x,menuPos.y)

var 
  dialogCall* = Call(
    reciever:thisDialog,
    draw:draw,
    keyboard:keyboard,
    mouse:mouse,
    mouseMoved:mouseMoved,
    cycle:cycle,
    active:false
  )

