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

let
  bg = readImage "pics\\downtown-city-skyline-river.jpg"
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)

proc draw(b:var Boxy) =
  b.drawImage "bg",bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.drawPlayerBatches
  b.drawMenu
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

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    if menu.mouseOnSelection("Quit Voracity"):
      window.closeRequested = true
    else:
      blueDeck.leftMousePressed
      m.leftMouse()
      if turn.nr > 0 and mouseOnDice() and mayReroll(): 
        startDiceRoll()
  elif m.rightMousePressed: 
    if turnPlayer.kind == Computer: 
      m.aiRightMouse
    m.rightMouse

proc mouseMoved = mouseOnMenu()

proc keyboard (key:KeyboardEvent) =
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
addImage("bg",bg)
addCall call
addCall dialogCall
runWinWith: 
  callCycles()
  callTimers()
playerKindsToFile playerKinds
