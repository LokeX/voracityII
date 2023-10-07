import win except strip
import strutils
import batch
import dialog

type 
  MenuKind* = enum SetupMenu,GameMenu

const
  menuEntries* = [
    SetupMenu: @["Start game\n","Quit Voracity"],
    GameMenu: @["End Turn\n","New Game","Quit Voracity"],
  ]

var 
  menuKind:MenuKind
  selectorBorder*:Border = (0,10,color(1,0,0))
  menuBatchInit* = BatchInit(
    kind:MenuBatch,
    name:"menu",
    pos:(860,280),
    entries:menuEntries[menuKind],
    selectionRange:0..menuEntries[menuKind].high,
    padding:(80,80,20,20),
    hAlign:CenterAlign,
    font:(robotoRegular,30.0,color(1,1,0)),
    bgColor:color(0,0,0),
    opacity:25,
    selectorLine:(color(1,1,1),color(100,0,0),selectorBorder),
    border:(0,15,color(1,1,1)),
    shadow:(10,1.5,color(255,255,255,150))
  )
  menu* = newBatch menuBatchInit

proc drawMenu*(b:var Boxy) =
  b.drawDynamicImage menu

proc menuLeftClicked* =
  menu.mouseSelect

proc mouseOnMenu* =
  if mouseOn menu.area:
    menu.mouseSelect

proc setMenu*(kind:MenuKind,entries:seq[string]) =
  menuKind = kind
  menu.setSpanTexts menuEntries[menuKind]
  menu.setSelectionRange 0..menuEntries[menuKind].high
  menu.update = true

proc selection*:string =
  if menu.selection != -1:
    menuEntries[menuKind][menu.selection].strip
  else: ""

proc mouseOnselection*(s:string):bool =
  if (let selection = menu.mouseOnSelectionArea; selection != -1):
    menuEntries[menuKind][selection].strip == s
  else: false

proc menuIs*:MenuKind = menuKind

