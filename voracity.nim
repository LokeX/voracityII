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
import eval
import strutils
import os
import stat
import cards
import board

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
  if showVolume > 0: b.drawImage(volumeImg,vec2(750,15))
  if turn.nr > 0:
    b.drawSquareText
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
    b.drawImage(logoImg,vec2(1475,60))
    b.drawImage(adviceImg,vec2(1525,450))
    b.drawImage(barmanImg,Rect(x:1555,y:530,w:220,h:275))
  else:
    b.drawCardsFooter
  b.showCards

proc statReset =
  resetMatchingStats()
  updateStatsBatch()

proc confirmResetStats = really("reset stats?",
  (answer:string) => (if answer == "Yes": statReset())
)

proc confirmQuit = really("quit Voracity?",
  (answer:string) => (if answer == "Yes": window.closeRequested = true)
)

proc confirmEndGame = really("end this game?",
  (answer:string) => (if answer == "Yes": setupNewGame())
)

proc menuSelection =
  if mouseOnMenuSelection("Quit Voracity"):
    showMenu = false
    confirmQuit()
  elif mouseOnMenuSelection("Start Game") or mouseOnMenuSelection("End Turn"):
    nextGameState()
  elif mouseOnMenuSelection("New Game"):
    if turnPlayer.cash >= cashToWin: setupNewGame()
    else: 
      showMenu = false
      confirmEndGame()

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

proc leftMousePlay* =
  if turn.undrawnBlues > 0 and mouseOn drawPileArea: 
    drawCardFrom blueDeck
    playCashPlansTo blueDeck
    turnPlayer.hand = turnPlayer.sortBlues
  elif not isRollingDice():
    if (let square = mouseOnSquare(); square != -1): 
      if moveSelection.fromSquare == -1 or square notIn moveSelection.toSquares:
        selectPiece square
      elif moveSelection.fromSquare != -1:
        movePiece square
    elif turnPlayer.hand.len > 3: 
      if (let slotNr = turnPlayer.mouseOnCardSlot; slotNr != -1):
        turnPlayer.hand.playTo blueDeck,slotNr
        turnPlayer.hand = turnPlayer.sortBlues

proc rightMousePlay =
  if moveSelection.fromSquare != -1:
    moveSelection.fromSquare = -1
    piecesImg.update = true
  elif not showMenu:
    showMenu = true
    mainMenu.zoom = zoomImage 15
  else: nextGameState()

proc aiRightMouse* =
  if phase == EndTurn: 
    if showMenu: 
      endTurn()

proc mouseClicked(m:KeyEvent) =
  if mouseOnBatchPlayerNr != -1:
    if turn.nr > 0: pinnedBatchNr = mouseOnBatchPlayerNr
  else: 
    pinnedBatchNr = -1
    batchInputNr = -1
    inputBatch.deleteInput
  if statsBatchVisible and mouseOnStatsBatch: 
    showMenu = false
    confirmResetStats()
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
      leftMousePlay()
      if turn.nr > 0 and mouseOnDice() and mayReroll(): 
        startDiceRoll()
  elif m.rightMousePressed and batchInputNr == -1: 
    if turn.nr > 0 and turnPlayer.kind == Computer: 
      aiRightMouse()
    else:
      rightMousePlay()
    keybarPainter.update = true

proc mouseMoved = 
  mouseSquare = mouseOnSquare()
  let batchNr = mouseOnPlayerBatchNr()
  if altPressed: 
    if batchNr != -1: mouseOnBatchPlayerNr = batchNr
  else: mouseOnBatchPlayerNr = batchNr
  if showMenu and mouseOn mainMenu.area:
    mainMenu.mouseSelect

proc keyboard(key:KeyboardEvent) =
  altPressed = key.pressed.alt
  if batchInputNr != -1: 
    key.handleInput
    if key.button == KeyEnter:
      updateStatsBatch()
  elif key.keyPressed: 
    case key.button
    of NumpadAdd,NumpadSubtract:
      key.setVolume
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

proc configStartGame =
  playerBatches = newPlayerBatches()
  setMenuTo GameMenu
  showMenu = false

proc configGameWon =
  writeGamestats()
  updateStatsBatch()
  if turnPlayer.kind == Human:
    playSound "applause-2"
    setMenuTo WonGameMenu
  else:
    playSound "sad-trombone"
    setMenuTo LostGameMenu
  updateKeybar = true
  showMenu = true
  turn.undrawnBlues = 0

proc barMoveMouseMoved(entries:seq[string]):proc =
  var square = -1
  proc =
    let selectedSquare = try: 
      entries[dialogBatch.selection]
      .splitWhitespace[^1]
      .parseInt 
    except: -1
    if selectedSquare notin [-1,square]:
      square = selectedSquare
      moveToSquaresPainter.context = @[square]
      moveToSquaresPainter.update = true
      if entries[dialogBatch.selection].startsWith "from":
        moveSelection.fromSquare = square #yeah, it's a hack

proc selectBarMoveDest(selection:string) =
  let 
    entries = dialogBarMoves.dialogEntries move => move.toSquare
    fromSquare = selection.splitWhitespace[^1].parseInt
  if fromSquare != -1:
    moveSelection.fromSquare = fromSquare
  if entries.len > 1:
    dialogOnMouseMoved = entries.barMoveMouseMoved()
    startDialog(entries,0..entries.high,endBarMoveSelection)
  elif entries.len == 1: 
    moveSelection.toSquare = dialogBarMoves[0].toSquare
    moveSelection.event = true
    movePiece moveSelection.toSquare

proc selectBar =
  showMenu = false
  let entries = dialogBarMoves.dialogEntries move => move.fromSquare
  if entries.len > 1:
    dialogOnMouseMoved = entries.barMoveMouseMoved()
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
  if squareTimer > 0: dec squareTimer
  if showVolume > 0: showVolume -= 0.4
  showCursor = not showCursor
  if turn.nr > 0 and not moveAnimation.active and mouseOnBatchPlayerNr != -1:
    if mouseOnBatchColor.gotReport:
      if (let moves = reportAnimationMoves(); moves.len > 0):
          startMovesAnimations(mouseOnBatchColor,moves)
  # echo frames*2.5
  frames = 0

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
  voracityCall = Call(
    reciever:"voracity",
    draw:draw,
    mouseClick:mouseClicked,
    mouseMoved:mouseMoved,
    keyboard:keyboard,
    cycle:cycle,
    timer:timerCall()
  )

template initPlay =
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

template initSettings =
  if fileExists(settingsFile): 
    settingsFromFile()
  else: settingsToFile()
  setVolume vol

initGame()
initPlay()
initGraphics()
initBoard()
initCards()
initReports()
initSettings()
addCall voracityCall
# addCall dialogCall 
window.onCloseRequest = quitVoracity
window.icon = readImage "pics\\BarMan.png"
runWinWith: 
  callCycles()
  callTimers()
