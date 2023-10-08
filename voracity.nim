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

proc draw(b:var Boxy) =
  b.drawImage backgrounds[bgSelected].name,bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.drawPlayerBatches
  if showMenu: b.drawDynamicImage mainMenu
  if turn.nr > 0: 
    if turnPlayer.kind == Computer:
      blueDeck.reveal = Back
    else: blueDeck.reveal = Front
    b.paintCards blueDeck,turnPlayer.hand
    b.drawCursor
    b.drawDice
    if not isRollingDice(): b.drawSquares
    if turnPlayer.kind == Human and turn.undrawnBlues > 0: 
      b.drawDynamicImage nrOfUndrawnBluesPainter

proc menuSelection =
  if mouseOnMenuSelection("Quit Voracity"):
    window.closeRequested = true
  elif mouseOnMenuSelection("Start Game"):
    nextTurn()
  elif mouseOnMenuSelection("New Game"):
    setupNewGame()

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    if mouseOnMenuSelection():
      menuSelection()
    else:
      blueDeck.leftMousePressed
      m.leftMouse()
      if turn.nr > 0 and mouseOnDice() and mayReroll(): 
        startDiceRoll()
  elif m.rightMousePressed: 
    if turnPlayer.kind == Computer: 
      m.aiRightMouse
    m.rightMouse

proc mouseMoved = 
  if mouseOn mainMenu.area:
    mainMenu.mouseSelect

proc keyboard (key:KeyboardEvent) =
  if key.keyPressed:
    case key.button
    of KeyLeft: 
      if bgSelected > 0: dec bgSelected 
      else: bgSelected = backgrounds.high
    of KeyRight:
      if bgSelected < backgrounds.high: inc bgSelected 
      else: bgSelected = backgrounds.low
    else:discard
  if key.button == ButtonUnknown and not isRollingDice():
    editDiceRoll key.rune.toUTF8

proc cycle = 
  if turnPlayer.kind == Computer and aiTurn():
    aiTakeTurn()

proc timer = showCursor = not showCursor

proc timerCall:TimerCall =
  TimerCall(call:timer,lastTime:cpuTime(),secs:0.4)

var
  call = Call(
    draw:draw,
    mouse:mouse,
    mouseMoved:mouseMoved,
    keyboard:keyboard,
    cycle:cycle,
    timer:timerCall()
  )

setVolume 0.20
addCall call
addCall dialogCall
runWinWith: 
  callCycles()
  callTimers()
playerKindsToFile playerKinds
