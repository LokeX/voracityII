import win except splitWhitespace
import graphics
import game
import play
import times
import megasound
import dialog
import menu
import batch
import sugar
import reports
import sequtils
import misc
import random
import eval
import strutils
import os
import stat
import cards

const
  showVolTime = 2.4
  settingsFile = "dat\\settings.cfg"
  logoFontPath = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
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
let
  voracityLogo = readImage "pics\\voracity.png"
  lets_rockLogo = readImage "pics\\lets_rock.png"
  barMan = readImage "pics\\barman.jpg"
  logoFont = setNewFont(logoFontPath,size = 16.0,color(1,1,1))

var 
  batchInputNr = -1
  frames:float
  vol = 0.05
  showVolume:float
  showPanel = true

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
      elif not showMenu:
        "Show Menu"
      elif turnPlayer.cash >= cashToWin: 
        "New Game"
      else: "End Turn"
    ),white),
  ]
  if moveSelection.fromSquare != -1:
    echo spans[^1].text
  ctx.image.fillText(spans.typeset(vec2(1150,20)),translate vec2(10,2))
  ctx.image

let keybarPainter = DynamicImage[void](
  name:"keybar",
  updateImage:paintKeybar,
  # area:(225,935,0,0),
  rect:Rect(x:225,y:935),
  update:true
)

proc paintSubText:Image =
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

proc paintLogo:Image =
  result = newImage(350,400)
  var ctx = result.newContext
  ctx.drawImage(voracityLogo,vec2(0,0))
  ctx.drawImage(lets_rockLogo,vec2(50,70))
  ctx.image.fillText(logoTextArrangement(350,200),translate vec2(0,150))

proc paintBarman:Image =
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

proc paintVolume:Image =
  var ctx = newImage(110,20).newContext
  ctx.image.fill color(255,255,255)
  ctx.fillStyle = color(1,1,1)
  ctx.fillRect(5,5,vol*100,10)
  ctx.image

proc reportAnimationMoves:seq[AnimationMove] =
  if selectedBatchColor == turnPlayer.color:
    result.add turnReport.moves.mapIt (it.fromSquare,it.toSquare)
  elif selectedBatchColor.reports.len > 0: 
    result.add selectedBatchColor
    .reports[^1].moves
    .mapIt (it.fromSquare,it.toSquare)

proc draw(b:var Boxy) =
  frames += 1
  if oldBg != -1: b.drawImage(backgrounds[oldBg].name,oldBgRect)
  b.drawImage(backgrounds[bgSelected].name,bgRect)
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.drawPlayerBatches
  b.drawStats
  if showPanel: 
    if updateKeybar:
      keybarPainter.update = true
      updateKeybar = false
    b.drawDynamicImage keybarPainter
  if showMenu: b.drawDynamicImage mainMenu
  if batchInputNr != -1: b.drawBatch inputBatch
  if showVolume > 0: b.drawImage("volume",vec2(750,15))
  if turn.nr > 0:
    if mouseOn squares[0].dims.area: b.drawKillMatrix
    b.doMoveAnimation
    b.drawCursor
    b.drawCardsFooter
    if not turn.diceMoved or turnPlayer.kind == Computer: b.drawDice
    if not isRollingDice() and turnPlayer.kind == Human: b.drawSquares
    if turnPlayer.kind == Human and turn.undrawnBlues > 0: 
      b.drawDynamicImage nrOfUndrawnBluesPainter
    if mouseOnBatchPlayerNr != -1 and gotReport mouseOnBatchColor:
      b.drawReport mouseOnBatchColor
  elif pinnedCards != AllDeck and not mouseOn drawPileArea: 
    b.drawImage("logo",vec2(1475,60))
    b.drawImage("advicetext",vec2(1525,450))
    b.drawImage("barman",Rect(x:1555,y:530,w:220,h:275))
  else:
    b.drawCardsFooter
  b.showCards

proc really(title:string,answer:string -> void) =
  let entries = @[
    "Really "&title&"\n",
    "\n",
    "Yes\n",
    "No",
  ]
  showMenu = false
  startDialog(entries,2..3,answer)

proc confirmQuit = really("quit Voracity?",
  (answer:string) => (if answer == "Yes": window.closeRequested = true)
)

proc confirmEndGame = really("end this game?",
  (answer:string) => (if answer == "Yes": setupNewGame())
)

proc statReset =
  resetMatchingStats()
  updateStatsBatch()

proc confirmResetStats = really("reset stats?",
  (answer:string) => (if answer == "Yes": statReset())
)

proc menuSelection =
  if mouseOnMenuSelection("Quit Voracity"):
    confirmQuit()
  elif mouseOnMenuSelection("Start Game") or mouseOnMenuSelection("End Turn"):
    nextGameState()
  elif mouseOnMenuSelection("New Game"):
    if turnPlayer.cash >= cashToWin: setupNewGame()
    else: confirmEndGame()

proc togglePlayerKind* =
  if (let batchNr = mouseOnPlayerBatchNr(); batchNr != -1) and turn.nr == 0:
    playerKinds[batchNr] = 
      case playerKinds[batchNr]
      of Human:Computer
      of Computer:None
      of None:Human
    players[batchNr].kind = playerKinds[batchNr]
    players[batchNr].update = true
    piecesImg.update = true
    updateStatsBatch()

proc select*(square:int) =
  if turnPlayer.hasPieceOn square:
    moveSelection = (-1,square,-1,turnPlayer.movesFrom(square),false)
    moveToSquaresPainter.context = moveSelection.toSquares
    moveToSquaresPainter.update = true
    # updatePieces = true
    piecesImg.update = true
    playSound "carstart-1"

proc leftMouse* =
  if turn.undrawnBlues > 0 and mouseOn drawPileArea: 
    drawCardFrom blueDeck
    playCashPlansTo blueDeck
    turnPlayer.hand = turnPlayer.sortBlues
  elif not isRollingDice():
    if (let square = mouseOnSquare(); square != -1): 
      if moveSelection.fromSquare == -1 or square notIn moveSelection.toSquares:
        select square
        updateKeybar = true
      elif moveSelection.fromSquare != -1:
        move square
    elif turnPlayer.hand.len > 3: 
      if (let slotNr = turnPlayer.mouseOnCardSlot; slotNr != -1):
        turnPlayer.hand.playTo blueDeck,slotNr
        turnPlayer.hand = turnPlayer.sortBlues

proc rightMouse =
  if moveSelection.fromSquare != -1:
    moveSelection.fromSquare = -1
    piecesImg.update = true
  elif not showMenu:
    echo "setting menu visibility"
    showMenu = true
    # mainMenu.dynamicZoom 30
    mainMenu.zoom = zoomImage 15
  else: nextGameState()

proc aiRightMouse* =
  if phase == EndTurn: 
    if showMenu: 
      endTurn()

proc mouse(m:KeyEvent) =
  if mouseOnBatchPlayerNr != -1:
    if turn.nr > 0: pinnedBatchNr = mouseOnBatchPlayerNr
  else: 
    pinnedBatchNr = -1
    batchInputNr = -1
    inputBatch.deleteInput
  if statsBatchVisible and mouseOnStatsBatch: confirmResetStats()
  if m.rightMousePressed and turn.nr == 0 and mouseOnBatchPlayerNr != -1:
    batchInputNr = mouseOnBatchPlayerNr
  if m.leftMousePressed or m.rightMousePressed:
    if mouseOn discardPileArea: 
      pinnedCards = Discard
    elif turn.nr == 0 and mouseOn drawPileArea: 
      pinnedCards = AllDeck
    else: pinnedCards = None
  if m.leftMousePressed:
    if turn.nr == 0: togglePlayerKind()
    if showMenu and mouseOnMenuSelection():
      menuSelection()
    elif turnPlayer.kind == Human:
      leftMouse()
      if turn.nr > 0 and mouseOnDice() and mayReroll(): 
        startDiceRoll()
  elif m.rightMousePressed and batchInputNr == -1: 
    if turn.nr > 0 and turnPlayer.kind == Computer: 
      aiRightMouse()
    else:
      rightMouse()
    keybarPainter.update = true

proc mouseMoved = 
  let batchNr = mouseOnPlayerBatchNr()
  if altPressed: 
    if batchNr != -1: mouseOnBatchPlayerNr = batchNr
  else: mouseOnBatchPlayerNr = batchNr
  if showMenu and mouseOn mainMenu.area:
    mainMenu.mouseSelect

proc keyboard(key:KeyboardEvent) =
  altPressed = key.pressed.alt
  if batchInputNr != -1 and key.button != KeyEnter: 
    key.batchKeyb inputBatch
  elif key.keyPressed: 
    case key.button
    of NumpadAdd,NumpadSubtract:
      vol += (
        if key.button.isKey NumpadAdd: 
          if vol < 0.95: 0.05 else: 0
        elif vol <= 0.05: 0 else: -0.05
      )
      setVolume vol
      removeImg("volume")
      addImage("volume",paintVolume())
      showVolume = showVolTime
    of KeyEnter:
      if batchInputNr != -1: 
        if inputBatch.input.len > 0:
          playerKinds[batchInputNr] = Human
          players[batchInputNr].kind = Human
        playerHandles[batchInputNr] = inputBatch.input
        players[batchInputNr].update = true
        # updateBatch batchInputNr
        batchInputNr = -1
        inputBatch.deleteInput
        updateStatsBatch()
    of KeyA: 
      keybarPainter.update = true
      autoEndTurn = not autoEndTurn
    of KeyP: showPanel = not showPanel
    of KeyR: reveal = not reveal
    of KeyS:
      keybarPainter.update = true
      if volume() == 0:
        setVolume vol
      else: setVolume 0
    else:discard
  if key.button == ButtonUnknown and not isRollingDice():
    editDiceRoll key.rune.toUTF8

proc configSetupGame =
  playerBatches = newPlayerBatches()
  piecesImg.update = true
  setMenuTo SetupMenu
  showMenu = true
  playSound "carhorn-1"
  # configState = None

proc configStartGame =
  playerBatches = newPlayerBatches()
  setMenuTo GameMenu
  showMenu = false
  # configState = None

proc configGameWon =
  writeGamestats()
  updateStatsBatch()
  playSound "applause-2"
  setMenuTo NewGameMenu
  updateKeybar = true
  showMenu = true
  turn.undrawnBlues = 0
  # configState = None

proc selectBarMoveDest(selection:string) =
  let 
    entries = dialogBarMoves.dialogEntries move => move.toSquare
    fromSquare = selection.splitWhitespace[^1].parseInt
  if fromSquare != -1:
    moveSelection.fromSquare = fromSquare
  if entries.len > 1:
    startDialog(entries,0..entries.high,endBarMoveSelection)
  elif entries.len == 1: 
    moveSelection.toSquare = dialogBarMoves[0].toSquare
    moveSelection.event = true
    move moveSelection.toSquare

proc selectBar =
  showMenu = false
  let entries = dialogBarMoves.dialogEntries move => move.fromSquare
  if entries.len > 1:
    startDialog(entries,0..entries.high,selectBarMoveDest)
  elif entries.len == 1: 
    moveSelection.fromSquare = dialogBarMoves[0].fromSquare
    selectBarMoveDest entries[0]

proc startKillDialog(square:int) =
  let 
    targetPlayer = players[singlePiece.playerNr]
    targetSquare = targetPlayer.pieces[singlePiece.pieceNr]
    cashChance = targetPlayer.cashChanceOn(targetSquare,blueDeck)*100
    entries:seq[string] = @[
      "Remove piece on:\n",
      board[square].name&" Nr."&($board[square].nr)&"?\n",
      "Cash chance: "&cashChance.formatFloat(ffDecimal,2)&"%\n",
      "\n",
      "Yes\n",
      "No",
    ]
  showMenu = false
  startDialog(entries,4..5,killPieceAndMove)

proc animateMove* =
  startMoveAnimation(
    turnPlayer.color,
    moveSelection.fromSquare,
    moveSelection.toSquare
  )
  move()

proc aiTurn(): bool =
  turn.nr != 0 and 
  turnPlayer.kind == Computer and 
  not isRollingDice()

proc resetReports* =
  for batch in reportBatches.mitems:
    batch.setSpans @[]
  selectedBatch = -1
  killMatrixPainter.update = true

proc menuShow(show:bool) =
  showMenu = show

proc setConfigState(config:ConfigState) =
  case config:
  of StartGame: configStartGame()
  of SetupGame: configSetupGame()
  of GameWon: configGameWon()

proc cycle = 
  if soundToPlay.len > 0:
    playSound soundToPlay[0]
    soundToPlay.delete 0
  if bgRect.w < scaledWidth.toFloat:
    if bgRect.w+90 < scaledWidth.toFloat:
      bgRect.w += 90
    else: 
      bgRect.w = scaledWidth.toFloat
      oldBg = -1
  if turnPlayer.kind == Computer and not moveAnimationActive() and aiTurn():
    aiTakeTurnPhase()

proc timer = 
  if showVolume > 0: showVolume -= 0.4
  showCursor = not showCursor
  if turn.nr > 0 and not moveAnimation.active and mouseOnBatchPlayerNr != -1:
    if mouseOnBatchColor.gotReport:
      if (let moves = reportAnimationMoves(); moves.len > 0):
          startMovesAnimations(mouseOnBatchColor,moves)
  # echo frames*2.5
  frames = 0

proc playerKindsFromFile:seq[PlayerKind] =
  try:
    readFile(kindFile)
    .split("@[,]\" ".toRunes)
    .filterIt(it.len > 0)
    .mapIt(PlayerKind(PlayerKind.mapIt($it).find(it)))
  except: defaultPlayerKinds

proc playerKindsToFile*(playerKinds:openArray[PlayerKind]) =
  writeFile(kindFile,$playerKinds.mapIt($it))

proc settingsToFile =
  let f = open(settingsFile,fmWrite)
  f.writeIt autoEndTurn
  f.writeIt reveal
  f.writeIt vol
  f.writeIt showPanel
  f.close

proc settingsFromFile =
  let f = open(settingsFile,fmRead)
  f.readIt autoEndTurn
  f.readIt reveal
  f.readIt vol
  f.readIt showPanel
  f.close

proc quitVoracity =
  playerKindsToFile playerKinds
  playerHandlesToFile playerHandles
  settingsToFile()
  closeSound()

proc timerCall:TimerCall =
  TimerCall(call:timer,lastTime:cpuTime(),secs:0.4)

var
  call = Call(
    reciever:"voracity",
    draw:draw,
    mouse:mouse,
    mouseMoved:mouseMoved,
    keyboard:keyboard,
    cycle:cycle,
    timer:timerCall()
  )

template hookUpGamePlayInterface =
  configState = setConfigState
  killDialog = startKillDialog
  runSelectBar = selectBar
  rollTheDice = startDiceRoll
  menuControl = menuShow
  updatePieces = updatePiecesPainter
  updateUndrawnBlues = undrawnPainterUpdate
  updateKillMatrix = killMatrixUpdate
  turnReportUpdate = writeTurnReportUpdate
  turnReportBatchesInit = initReportBatchesTurn
  resetReportsUpdate = resetReports
  runMoveAnimation = animateMove

hookUpGamePlayInterface()
blueDeck.initGraphics
addImage("logo",paintLogo())
addImage("barman",paintBarman())
addImage("advicetext",paintSubText())
addImage("volume",paintVolume())
randomize()
for i,kind in playerKindsFromFile(): 
  playerKinds[i] = kind
initPlayers()
playerBatches = newPlayerBatches()
reportBatches = initReportBatches()
readGameStatsFrom statsFile
updateStatsBatch()
if fileExists(settingsFile): 
  settingsFromFile()
else: settingsToFile()
echo gameStats.len
setVolume vol
addCall call
addCall dialogCall 
window.onCloseRequest = quitVoracity
window.icon = readImage "pics\\BarMan.png"
runWinWith: 
  callCycles()
  callTimers()
