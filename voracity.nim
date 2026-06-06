import win except splitWhitespace
import batch
import times
import sequtils
import sugar
import os
import game
import play
import megasound
import dialog
import menu
import reports
import misc
import stat
import cards
import gameplay

proc configSetupGame =
  playerBatches = newPlayerBatches()
  resetReports()
  piecesImg.update = true
  setMenuTo SetupMenu
  playSound "carhorn-1"

proc configStartGame =
  playerBatches = newPlayerBatches()
  setMenuTo GameMenu
  showMenu = false

proc configGameWon =
  mainGame.writeGamestats report
  updateStatsBatch()
  if turnPlayer.kind == Human or not players.anyHuman:
    playSound "applause-2"
    setMenuTo WonGameMenu
  else:
    playSound "sad-trombone"
    setMenuTo LostGameMenu
  updateKeybar = true
  turn.undrawnBlues = 0

proc setConfigState(config:ConfigState) =
  case config:
  of StartGame: configStartGame()
  of SetupGame: configSetupGame()
  of GameWon: configGameWon()

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
  (answer:string) => (if answer == "Yes": setupGame())
)

proc menuSelection =
  case menuSelectionString():
    of "New Game":
      if turnPlayer.cash >= cashToWin: 
        setupGame()
      else:
        showMenu = false
        confirmEndGame()
    of "Quit Voracity":
      showMenu = false
      confirmQuit()
    of "Start Game","End Turn":
      nextGameState()

proc humanPlayLeftClick =
  if turn.undrawnBlues > 0 and mouseOn drawPileArea:
    gamePlay.drawCard()
  elif not isRollingDice():
    if turn.nr > 0 and mouseOnDice() and diceRoll.isDouble():
      startDiceRoll()  
    elif mouseSquare > -1:
      handleMoveSelection()
    elif turnPlayer.hand.len > 3:
      discardCard()

proc humanPlayRightClick =
  if moveSelection.fromSquare != -1:
    moveSelection.fromSquare = -1
    piecesImg.update = true
  elif not showMenu:
    showMenu = true
    mainMenu.zoom = zoomImage 15
  elif players.anyIt it.kind != None: 
    nextGameState()
    playCashPlans()

proc aiPlayRightClick =
  if phase == EndTurn:
    if showMenu:
      endTurn()
  showMenu = true

proc draw(b:var Boxy) =
  frames += 1
  b.drawMenuBackground
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.drawPlayerBatches
  b.drawStats
  if showPanel: b.drawKeybar
  b.showCards
  if showMenu: b.drawDynamicImage mainMenu
  if batchInputNr != -1: b.drawBatch inputBatch
  if showVolume > 0: b.drawImage(volumeImg,vec2(750,15))
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
    b.drawImage(logoImg,vec2(1475,60))
    b.drawImage(adviceImg,vec2(1525,450))
    b.drawImage(barmanImg,Rect(x:1555,y:530,w:220,h:275))
  else:
    b.drawCardsFooter

proc mouseClicked(m:KeyEvent) =
  m.handlePlayerBatch()
  m.handlePinnedCards()
  if statsBatchVisible and mouseOnStatsBatch:
    showMenu = false
    confirmResetStats()
  if m.leftMousePressed:
    if showMenu and mouseOnMenuSelection():
      menuSelection()
    elif turnPlayer.kind == Human:
      humanPlayLeftClick()
  elif m.rightMousePressed and batchInputNr == -1:
    if turn.nr > 0 and turnPlayer.kind == Computer:
      aiPlayRightClick()
    else:
      humanPlayRightClick()
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

proc cycle =
  pieceSelected = moveSelection.fromSquare != -1
  if soundToPlay.len > 0:
    playSound soundToPlay[0]
    soundToPlay.delete 0
  if gameWon: phase = EndTurn
  if isAiTurn(): aiTakeTurn()

proc timer =
  if showVolume > 0: showVolume -= 0.4
  showCursor = not showCursor
  if turn.nr > 0 and not moveAnimation.active:
    handleReportMovesAnimations()
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

var
  voracityCall = Call(
    reciever:"voracity",
    draw:draw,
    mouseClick:mouseClicked,
    mouseMoved:mouseMoved,
    keyboard:keyboard,
    cycle:cycle,
    timer:TimerCall(
      call:timer,
      lastTime:cpuTime(),
      secs:0.4
    )
  )

# proc updates(updates:array[Update,bool]) =
#   for update in updates:
#     case update
#     Pieces:updatePiecesPainter
#     KillMatrix:killMatrixUpdate
#     ReportBatches:updateReportBatches

template hookUpGui =  # gui hook ups
  configState = setConfigState
  killDialog = startKillDialog
  runSelectBar = selectBar
  rollTheDice = startDiceRoll
  menuControl = menuShow
  updatePieces = updatePiecesPainter
  updateUndrawnBlues = undrawnPainterUpdate
  updateKillMatrix = killMatrixUpdate
  reportBatchesUpdate = updateReportBatches
  runMoveAnimation = animateMoveSelection

template initSettings =
  if fileExists(settingsFile):
    settingsFromFile()
  else: settingsToFile()
  setVolume vol

template initVoracity =
  addCall voracityCall
  window.onCloseRequest = quitVoracity
  window.icon = readImage "pics\\BarMan.png"

initGame()
initMenu()
initGamePlay()
initCards()
initStats()
initReports()
initSettings()
initVoracity()
hookUpGui()
runWinWith:
  callCycles()
  callTimers()
