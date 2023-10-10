import win except strip
import strutils
import batch

type
  Background* = tuple[name:string,img:Image]
  MenuKind* = enum SetupMenu,GameMenu,NewGameMenu

const
  ibmPlexSansCondensedSemiBold = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  menuEntries = [
    SetupMenu: @["Start Game\n","Quit Voracity"],
    GameMenu: @["End Turn\n","New Game\n","Quit Voracity"],
    NewGameMenu: @["New Game\n","Quit Voracity"],
  ]

let
  backgrounds*:array[3,Background] = [
    ("skylines",readImage "pics\\2015-02-24-BestSkylines_11.jpg"),
    ("darkgrain",readImage "pics\\dark-wood-grain.jpg"),
    ("fireworks2",readImage "pics\\fireworks.jpg")
  ]

var
  bgRect* = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)
  showMenu* = true
  bgSelected* = 0
  menuKind:MenuKind
  selectorBorder:Border = (0,10,color(1,0,0))
  menuBatchInit = BatchInit(
    kind:MenuBatch,
    name:"mainMenu",
    pos:(860,280),
    entries:menuEntries[menuKind],
    selectionRange:0..menuEntries[menuKind].high,
    padding:(80,80,20,20),
    hAlign:CenterAlign,
    font:(ibmPlexSansCondensedSemiBold,30.0,color(1,1,0)),
    bgColor:color(0,0,0),
    opacity:25,
    selectorLine:(color(1,1,1),color(100,0,0),selectorBorder),
    border:(0,15,color(1,1,1)),
    shadow:(10,1.5,color(255,255,255,150))
  )
  mainMenu* = newBatch menuBatchInit

proc setMenuTo*(kind:MenuKind) =
  menuKind = kind
  bgSelected = menuKind.ord
  bgRect.w = 0
  mainMenu.resetMenu menuEntries[menuKind],0..menuEntries[menuKind].high
  mainMenu.update = true

proc mouseOnMenuSelection*(s:string):bool =
  if (let selection = mainMenu.mouseOnSelectionArea; selection != -1):
    menuEntries[menuKind][selection].strip == s
  else: false

proc mouseOnMenuselection*:bool = mainMenu.mouseOnSelectionArea != -1

proc menuIs*:MenuKind = menuKind

for bg in backgrounds:
  addImage(bg.name,bg.img)
