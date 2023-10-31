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
import eval
 
# var frames:float

let
  voracityLogo = readImage "pics\\voracity.png"
  lets_rockLogo = readImage "pics\\lets_rock.png"

var 
  mouseOnBatchPlayerNr = -1
  pinnedBatchNr = -1

template mouseOnBatchColor:untyped = players[mouseOnBatchPlayerNr].color

template selectedBatchColor:untyped =
  if mouseOnBatchPlayerNr != -1: players[mouseOnBatchPlayerNr].color
  else: players[pinnedBatchNr].color

template batchSelected:bool =
  mouseOnBatchPlayerNr != -1 or pinnedBatchNr != -1

proc cashedCards:seq[BlueCard] =
  echo "cashed cards collect"
  result.add selectedBatchColor.reports.mapIt(it.cards.cashed).flatMap
  if turnPlayer.kind == Human and selectedBatchColor == turnPlayer.color:
    result.add turnReport.cards.cashed
  echo "cashed cards collect end"

proc reportAnimationMoves:seq[AnimationMove] =
  echo "collect animation moves"
  if selectedBatchColor == turnPlayer.color:
    result.add turnReport.moves.mapIt (it.fromSquare,it.toSquare)
  else: result.add selectedBatchColor
    .reports[^1].moves
    .mapIt (it.fromSquare,it.toSquare)
  echo "collect animation moves end"

proc drawCards(b:var Boxy) =
  if batchSelected and selectedBatchColor.reports.len > 0:
    if (let cashedCards = cashedCards(); cashedCards.len > 0):
      let storedRevealSetting = blueDeck.reveal
      blueDeck.reveal = Front
      b.paintCards blueDeck,cashedCards
      blueDeck.reveal = storedRevealSetting   
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
  if turn.nr == 0:
    b.drawImage("voracitylogo",vec2(1475,100))
    b.drawImage("lets_rocklogo",vec2(1525,160))
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
      pinnedBatchNr = mouseOnBatchPlayerNr
    else: pinnedBatchNr = -1
    if turn.nr == 0: togglePlayerKind()
    if showMenu and mouseOnMenuSelection():
      menuSelection()
    elif turnPlayer.kind == Human:
      m.leftMouse()
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
  if turnPlayer.kind == Human and turnReport.diceRolls.len < diceRolls.len:
    updateTurnReport diceRolls[^1]
  if not moveAnimation.active and mouseOnBatchPlayerNr != -1:
    if (let moves = reportAnimationMoves(); moves.len > 0):
        startMovesAnimations(mouseOnBatchColor,moves)
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

addImage("voracitylogo",voracityLogo)
addImage("lets_rocklogo",lets_rockLogo)
window.icon = readImage "pics\\BarMan.png"
randomize()
setVolume 0.05
addCall call
addCall dialogCall # we add dialog second - or it will be drawn beneath the board
runWinWith: 
  callCycles()
  callTimers()
playerKindsToFile playerKinds
