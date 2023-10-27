import win
import deck
import game
import play
import board
import times
import megasound
import dialog
import ai
import menu
import batch
import sugar
import reports
import sequtils
import misc
import random
 
# var frames:float

type ShowCashedCards = enum LastCashed,AllCashed

var 
  mouseOnBatchPlayerNr = -1
  showCashedCards:ShowCashedCards

template mouseOnBatchColor:untyped = players[mouseOnBatchPlayerNr].color

proc cashedCards:seq[BlueCard] =
  if showCashedCards == LastCashed:
    if mouseOnBatchColor == turnPlayer.color:
      result.add turnReport.cards.cashed
    else:
      result.add mouseOnBatchColor.reports[^1].cards.cashed
  else: 
    result.add mouseOnBatchColor.reports.mapIt(it.cards.cashed).flatMap
    if turnPlayer.kind == Human and mouseOnBatchColor == turnPlayer.color:
      result.add turnReport.cards.cashed

proc drawCards(b:var Boxy) =
  if mouseOnBatchPlayerNr != -1 and mouseOnBatchColor.reports.len > 0:
    if (let cashedCards = cashedCards(); cashedCards.len > 0):
      let storedRevealSetting = blueDeck.reveal
      blueDeck.reveal = Front
      b.paintCards blueDeck,cashedCards
      blueDeck.reveal = storedRevealSetting   
    else: b.paintCards blueDeck,turnPlayer.hand
  else: b.paintCards blueDeck,turnPlayer.hand

proc setRevealCards(deck:var Deck,playerKind:PlayerKind) =
  if deck.reveal != UserSetFront: 
    if playerKind == Computer:
      deck.reveal = Back
    else: deck.reveal = Front

proc draw(b:var Boxy) =
  # frames += 1
  if oldBg != -1: b.drawImage backgrounds[oldBg].name,oldBgRect
  b.drawImage backgrounds[bgSelected].name,bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.drawPlayerBatches
  if showMenu: b.drawDynamicImage mainMenu
  if turn.nr > 0:  
    b.doMoveAnimation
    b.drawCards
    b.drawCursor
    b.drawDice
    if not isRollingDice() and turnPlayer.kind == Human: b.drawSquares
    if turnPlayer.kind == Human and turn.undrawnBlues > 0: 
      b.drawDynamicImage nrOfUndrawnBluesPainter
    if mouseOnBatchPlayerNr != -1 and gotReport mouseOnBatchColor:
      b.drawReport mouseOnBatchColor

proc really(title:string,answer:string -> void) =
  let entries:seq[string] = @[
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

proc menuSelection =
  if mouseOnMenuSelection("Quit Voracity"):
    confirmQuit()
  elif mouseOnMenuSelection("Start Game") or mouseOnMenuSelection("End Turn"):
    nextGameState()
  elif mouseOnMenuSelection("New Game"):
    if turnPlayer.cash >= cashToWin:
      setupNewGame()
    else: confirmEndGame()

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    blueDeck.leftMousePressed
    if mouseOnBatchPlayerNr != -1:
      case showCashedCards
      of LastCashed: showCashedCards = AllCashed
      of AllCashed: showCashedCards = LastCashed
    if turn.nr == 0: togglePlayerKind()
    if showMenu and mouseOnMenuSelection():
      menuSelection()
    elif turnPlayer.kind == Human:
      m.leftMouse()
      echo "left mouse done"
      if turn.nr > 0 and mouseOnDice() and mayReroll(): 
        startDiceRoll(humanRoll)
  elif m.rightMousePressed: 
    if turn.nr > 0 and turnPlayer.kind == Computer: 
      m.aiRightMouse
    else:
      m.rightMouse

proc mouseMoved = 
  mouseOnBatchPlayerNr = mouseOnPlayerBatchNr()
  if showMenu and mouseOn mainMenu.area:
    mainMenu.mouseSelect

proc keyboard (key:KeyboardEvent) =
  if key.keyPressed: 
    case key.button
    of KeyE: autoEndTurn = not autoEndTurn
    of KeyR: 
      case blueDeck.reveal
      of UserSetFront: blueDeck.reveal = Back
      of Back,Front: blueDeck.reveal = UserSetFront
    of KeyS:
      if volume() == 0:
        setVolume 0.05
      else: setVolume 0
    else:discard
  if key.button == ButtonUnknown and not isRollingDice():
    editDiceRoll key.rune.toUTF8

proc cycle = 
  blueDeck.setRevealCards turnPlayer.kind
  if bgRect.w < scaledWidth.toFloat:
    if bgRect.w+90 < scaledWidth.toFloat:
      bgRect.w += 90
    else: 
      bgRect.w = scaledWidth.toFloat
      oldBg = -1
  if turnPlayer.kind == Computer and not moveAnimationActive() and aiTurn():
    aiTakeTurn()

proc timer = 
  if not moveAnimation.active and mouseOnBatchPlayerNr != -1:
    if (let reports = mouseOnBatchColor.reports; reports.len > 0):
      startMoveAnimation(
        mouseOnBatchColor,
        reports[^1].moves[^1].fromSquare,
        reports[^1].moves[^1].toSquare,
      )
  # echo frames*2.5
  # frames = 0
  showCursor = not showCursor

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

window.icon = readImage "pics\\BarMan.png"
randomize()
setVolume 0.05
addCall call
addCall dialogCall # we add dialog second - or it will be drawn beneath the board
runWinWith: 
  callCycles()
  callTimers()
playerKindsToFile playerKinds
