import win except splitWhitespace
import strutils
import game
import megasound
import sequtils
import play
import menu
import batch

type
  Dims* = tuple[area:Area,rect:Rect]

const
  playerColors*:array[PlayerColor,Color] = [
    color(50,0,0),color(0,50,0),
    color(0,0,50),color(50,50,0),
    color(255,255,255),color(1,1,1)
  ]
  playerColorsTrans*:array[PlayerColor,Color] = [
    color(50,0,0,150),color(0,50,0,150),
    color(0,0,50,150),color(50,50,0,150),
    color(255,255,255,150),color(1,1,1,150)
  ]
  contrastColors*:array[PlayerColor,Color] = [
    color(1,1,1),color(255,255,255),
    color(1,1,1),color(255,255,255),
    color(1,1,1),color(255,255,255),
  ]

  (humanRoll*, computerRoll*) = (0,80)
  maxRollFrames = 120
  diceRollRects = (Rect(x:1450,y:60,w:50,h:50),Rect(x:1450,y:120,w:50,h:50))
  diceRollDims:array[1..2,Dims] = [
    (diceRollRects[0].toArea, diceRollRects[0]),
    (diceRollRects[1].toArea, diceRollRects[1])
  ]

  ibmBold* = "fonts\\IBMPlexMono-Bold.ttf"

  showVolTime* = 2.4
  settingsFile* = "dat\\settings.cfg"

  logoFontPath* = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
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

# let
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

let
  voracityLogo = readImage "pics\\voracity.png"
  lets_rockLogo = readImage "pics\\lets_rock.png"
  barMan = readImage "pics\\barman.jpg"
  logoFont = setNewFont(logoFontPath,size = 16.0,color(1,1,1))

var 
  inputBatch* = newBatch inputBatchInit
  batchInputNr* = -1
  frames*:float
  vol* = 0.05
  showVolume*:float
  showPanel* = true
  dieRollFrame* = maxRollFrames
  dieEdit:int

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
    white = setNewFont(logoFontPath,18,color(1,1,1))
    yellow = setNewFont(logoFontPath,18,color(1,1,0))
    green = setNewFont(logoFontPath,18,color(0,1,0))
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

proc paintKeybar*(b:var Boxy) =
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

proc editDiceRoll*(input:string) =
  if input.toUpper == "D": dieEdit = 1
  elif dieEdit > 0 and (let dieFace = try: input.parseInt except: 0; dieFace in 1..6):
    diceRoll[dieEdit] = DieFace(dieFace)
    dieEdit = if dieEdit == 2: 0 else: dieEdit + 1
  else: dieEdit = 0

proc mouseOnDice*:bool = diceRollDims.anyIt mouseOn it.area

proc rotateDie(b:var Boxy,die:int) =
  b.drawImage(
    $diceRoll[die],
    center = vec2(
      (diceRollDims[die].rect.x+(diceRollDims[die].rect.w/2)),
      diceRollDims[die].rect.y+(diceRollDims[die].rect.h/2)),
    angle = ((dieRollFrame div 3)*9).toFloat,
    tint = color(1, 1, 1, 1.0)
  )

proc drawDice*(b:var Boxy) =
  if dieRollFrame == maxRollFrames:
    for i,die in diceRoll:
      b.drawImage($die,vec2(diceRollDims[i].rect.x, diceRollDims[i].rect.y))
  else:
    rollDice()
    b.rotateDie(1)
    b.rotateDie(2)
    inc dieRollFrame
    if dieRollFrame == maxRollFrames:
      # diceRolls.add diceRoll
      turnReport.diceRolls.add diceRoll
      #please: don't do as I do

proc isRollingDice*:bool = dieRollFrame < maxRollFrames

proc startDiceRoll* =
  if not isRollingDice():
    dieRollFrame = 
      if turnPlayer.kind == Human: humanRoll 
      else: computerRoll
    playSound("wuerfelbecher")

proc endDiceRoll* = dieRollFrame = maxRollFrames

proc mayReroll*:bool = isDouble() and not isRollingDice()

template initGraphics* =
  addImage(logoImg,paintLogo())
  addImage(barmanImg,paintBarman())
  addImage(adviceImg,paintSubText())
  addImage(volumeImg,paintVolume())
  # addImage("board",boardImg)
  for die in DieFace:
    addImage($die,("pics\\diefaces\\"&($die.ord)&".png").readImage)
