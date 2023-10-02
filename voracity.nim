import win
import deck
import play
import board
import times
import megasound
import dialog

let
  bg = readImage "pics\\bggreen.png"
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)

proc draw(b:var Boxy) =
  b.drawImage "bg",bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.paintCards blueDeck,turnPlayer.hand
  b.drawPlayerBatches
  b.drawCursor
  if turn.nr > 0: b.drawDice
  if turn.nr > 0 and not isRollingDice(): b.drawSquares
  if turn.nr > 0 and turn.undrawnBlues > 0: 
    b.drawDynamicImage nrOfUndrawnBluesPainter

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    blueDeck.leftMousePressed
    m.leftMouse()
    if turn.nr > 0 and mouseOnDice() and mayReroll(): 
      startDiceRoll()
  elif m.rightMousePressed: m.rightMouse

proc keyboard (k:KeyboardEvent) =
  if k.button == ButtonUnknown and not isRollingDice():
    editDiceRoll k.rune.toUTF8

proc timer = showCursor = not showCursor

proc timerCall:TimerCall =
  TimerCall(call:timer,lastTime:cpuTime(),secs:0.4)

setVolume 0.15
addImage("bg",bg)
addCall Call(draw:draw,mouse:mouse,keyboard:keyboard,timer:timerCall())
addCall dialogCall
echo "still here"
runWinWith: callTimers()
playerKindsToFile playerKinds
