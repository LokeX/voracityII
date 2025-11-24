import win except strip
import strutils
import batch
import game
import megasound
import play

type
  Background = tuple[name:string,img:Image]
  MenuKind* = enum SetupMenu,GameMenu,LostGameMenu,WonGameMenu

const
  ibmBold* = "fonts\\IBMPlexMono-Bold.ttf"
  ibmSemiBold* = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  showVolTime* = 2.4
  settingsFile* = "dat\\settings.cfg"

  logoText = [
    "Created by",
    "Sebastian Tue Øltieng",
    "Per Ulrik Bøge Nielsen",
    "",
    "Coded by",
    "Per Ulrik Bøge Nielsen",
    "",
    "All rights reserved (1998 - 2023)",
  ]
  adviceText = [
    "The way is long, dark and lonely",
    "Let perseverance light your path"
  ]

  logoImg* = "logo"
  barmanImg* = "barman"
  adviceImg* = "advicetext"
  volumeImg* = "volume"

  inputEntries: seq[string] = @[
    "Write player handle:\n",
    "\n",
  ]

  condensedRegular = "fonts\\AsapCondensed-Regular.ttf"

  titleBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBatchInit = BatchInit(
    kind: InputBatch,
    name: "inputBatch",
    titleOn: true,
    titleLine: (color:color(1,1,0),bgColor:color(0,0,0),border:titleBorder),
    pos: (400,200),
    inputCursor: (0.5,color(0,1,0)),
    inputLine: (color(0,1,0),color(0,0,0),inputBorder),
    padding: (40,40,20,20),
    entries: inputEntries,
    inputMaxChars: 8,
    alphaOnly: true,
    font: (condensedRegular,30.0,color(1,1,1)),
    bgColor: color(0,0,0),
    border: (15,25,color(0,0,100)),
    shadow: (15,1.5,color(255,255,255,200))
  )

  ibmPlexSansCondensedSemiBold = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  menuEntries = [
    SetupMenu: @["Start Game\n","Quit Voracity"],
    GameMenu: @["End Turn\n","New Game\n","Quit Voracity"],
    LostGameMenu: @["New Game\n","Quit Voracity"],
    WonGameMenu: @["New Game\n","Quit Voracity"],
  ]

  selectorBorder:Border = (0,10,color(1,0,0))
  menuBatchInit = BatchInit(
    kind:MenuBatch,
    name:"mainMenu",
    pos:(860,280),
    entries:menuEntries[SetupMenu],
    selectionRange:0..menuEntries[SetupMenu].high,
    padding:(80,80,20,20),
    hAlign:CenterAlign,
    font:(ibmPlexSansCondensedSemiBold,30.0,color(1,1,0)),
    bgColor:color(0,0,0),
    opacity:25,
    selectorLine:(color(1,1,1),color(100,0,0),selectorBorder),
    border:(0,15,color(1,1,1)),
    shadow:(10,1.5,color(255,255,255,150))
  )

let
  voracityLogo = readImage "pics\\voracity.png"
  lets_rockLogo = readImage "pics\\lets_rock.png"
  barMan = readImage "pics\\barman.jpg"
  logoFont = setNewFont(ibmSemiBold,size = 16.0,color(1,1,1))

  backgrounds*:array[4,Background] = [
    ("skylines",readImage "pics\\2015-02-24-BestSkylines_11.jpg"),
    ("darkgrain",readImage "pics\\dark-wood-grain.jpg"),
    ("loser",readImage "pics\\loser.jpg"),
    ("fireworks2",readImage "pics\\fireworks.jpg")
  ]

var
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)
  bgSelected = 0
  oldBg = -1
  oldBgRect = bgRect
  menuKind = SetupMenu
  mainMenu* = newBatch menuBatchInit
  showMenu* = true
  inputBatch* = newBatch inputBatchInit
  batchInputNr* = -1
  frames*:float
  vol* = 0.05
  showVolume*:float
  showPanel* = true


proc setMenuTo*(kind:MenuKind) =
  oldBg = bgSelected
  menuKind = kind
  bgSelected = menuKind.ord
  bgRect.w = 0
  mainMenu.resetMenu menuEntries[menuKind],0..menuEntries[menuKind].high
  mainMenu.update = true
  showMenu = true
  mainMenu.dynMove(Up,20)

proc menuSelectionString*:string =
  if (let selection = mainMenu.mouseOnSelectionArea; selection != -1):
    menuEntries[menuKind][selection].strip
  else: "N/A"

proc mouseOnMenuSelection*(s:string):bool =
  menuSelectionString() == s

proc mouseOnMenuselection*:bool = mainMenu.mouseOnSelectionArea != -1

proc menuIs*:MenuKind = menuKind

proc drawMenuBackground*(b:var Boxy) =
  if bgRect.w < scaledWidth.toFloat:
    if bgRect.w+90 < scaledWidth.toFloat:
      bgRect.w += 90
    else: 
      bgRect.w = scaledWidth.toFloat
      oldBg = -1
  if oldBg != -1: b.drawImage(backgrounds[oldBg].name,oldBgRect)
  b.drawImage(backgrounds[bgSelected].name,bgRect)

# template initMenu* = 
#   for bg in backgrounds:
#     addImage(bg.name,bg.img)

proc handleInput*(key:KeyboardEvent) = 
  if key.button != KeyEnter: key.batchKeyb inputBatch
  else:
    if inputBatch.input.len > 0:
      playerKinds[batchInputNr] = Human
      players[batchInputNr].kind = Human
    playerHandles[batchInputNr] = inputBatch.input
    players[batchInputNr].update = true
    batchInputNr = -1
    inputBatch.deleteInput

proc paintKeybar:Image =
  let 
    ctx = newImage(1200,30).newContext
    white = setNewFont(ibmSemiBold,18,color(1,1,1))
    yellow = setNewFont(ibmSemiBold,18,color(1,1,0))
    green = setNewFont(ibmSemiBold,18,color(0,1,0))
  ctx.image.fill color(0,0,0,75)
  let spans = [
    newSpan("Keys:  ",green),
    newSpan("P",yellow),
    newSpan("anel (this):  ",white),
    newSpan("on",(if showPanel: yellow else: white)),
    newSpan("/",white),
    newSpan("off",(if showPanel: white else: yellow)),
    newSpan("  |  ",green),
    newSpan("S",yellow),
    newSpan("ound:  ",white),
    newSpan("on",(if volume() == 0: white else: yellow)),
    newSpan("/",white),
    newSpan("off",(if volume() == 0: yellow else: white)),
    newSpan("  |  ",green),
    newSpan("A",yellow),
    newSpan("uto end turn (Computer):  ",white),
    newSpan("on",(if autoEndTurn: yellow else: white)),
    newSpan("/",white),
    newSpan("off",(if autoEndTurn: white else: yellow)),
    newSpan("  |  ",green),
    newSpan("+/- ",yellow),
    newSpan("(NumPad):  Adjust volume",white),
    newSpan("  |  ",green),
    newSpan("Right-click-mouse:  ",yellow),
    newSpan((
      if turn.nr == 0: 
        "Start Game" 
      elif moveSelection.fromSquare != -1:
        "Deselect piece"
      elif not menu.showMenu:
        "Show Menu"
      elif turnPlayer.cash >= cashToWin: 
        "New Game"
      else: "End Turn"
    ),white),
  ]
  ctx.image.fillText(spans.typeset(vec2(1150,20)),translate vec2(10,2))
  ctx.image

let keybarPainter* = DynamicImage[void](
  name:"keybar",
  updateImage:paintKeybar,
  rect:Rect(x:225,y:935),
  update:true
)

proc drawKeybar*(b:var Boxy) =
  if updateKeybar:
    keybarPainter.update = true
    updateKeybar = false
  b.drawDynamicImage keybarPainter

proc paintSubText*:Image =
  var 
    spans:seq[Span]
    logoFontYellow = logoFont.copy
    logoFontBlack = logoFont.copy
  logoFontYellow.paint = color(1,1,0)
  logoFontBlack.paint = color(0,0,0)
  spans.add newSpan(adviceText[0]&"\n",logoFontBlack)
  spans.add newSpan(adviceText[1],logoFontYellow)
  let 
    arrangement = spans.typeset(
      bounds = vec2(250,100),
      hAlign = CenterAlign
    )
  result = newImage(250,100)
  result.fillText(arrangement,translate vec2(0,0))

proc logoTextArrangement(width,height:float):Arrangement =
  logoFont.lineHeight = 22
  logoFont.typeset(
    logoText.join("\n"),
    bounds = vec2(width,height),
    hAlign = CenterAlign
  )

proc paintLogo*:Image =
  result = newImage(350,400)
  var ctx = result.newContext
  ctx.drawImage(voracityLogo,vec2(0,0))
  ctx.drawImage(lets_rockLogo,vec2(50,70))
  ctx.image.fillText(logoTextArrangement(350,200),translate vec2(0,150))

proc paintBarman*:Image =
  let 
    (w,h) = ((int)(barMan.width.toFloat*0.9),barMan.height)
    shadow = 5
  result = newImage(w+shadow,h+shadow)
  var ctx = result.newContext
  ctx.fillStyle = color(0,0,0,100)
  ctx.fillRect(Rect(x:shadow.toFloat,y:shadow.toFloat,w:w.toFloat*0.9,h:h.toFloat))
  ctx.image.blur 2
  ctx.drawImage(barman,Rect(x:0,y:0,w:w.toFloat*0.9,h:h.toFloat))
  ctx.image.applyOpacity 25

proc paintVolume*:Image =
  var ctx = newImage(110,20).newContext
  ctx.image.fill color(255,255,255)
  ctx.fillStyle = color(1,1,1)
  ctx.fillRect(5,5,vol*100,10)
  ctx.image

proc setVolume*(key:KeyboardEvent) =
  vol += (
    if key.button.isKey NumpadAdd: 
      if vol < 0.95: 0.05 else: 0
    elif vol <= 0.05: 0 else: -0.05
  )
  setVolume vol
  removeImg("volume")
  addImage("volume",paintVolume())
  showVolume = showVolTime

template initMenu* =
  addImage(logoImg,paintLogo())
  addImage(barmanImg,paintBarman())
  addImage(adviceImg,paintSubText())
  addImage(volumeImg,paintVolume())
  # for die in DieFace:
  #   addImage($die,("pics\\diefaces\\"&($die.ord)&".png").readImage)
  for bg in backgrounds:
    addImage(bg.name,bg.img)

