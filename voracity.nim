import win
import deck
import play
import board
import times
import megasound

const
  popUpCard = Rect(x:500,y:275,w:cardWidth,h:cardHeight)
  drawPile = Rect(x:855,y:495,w:110,h:180)
  discardPile = Rect(x:1025,y:495,w:cardWidth*0.441,h:cardHeight*0.441)

let
  bg = readImage "pics\\bggreen.png"
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)

var 
  blueDeck = newDeck "dat\\blues.txt"

proc draw(b:var Boxy) =
  b.drawImage "bg",bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.paintCards blueDeck,turnPlayer.hand
  b.drawPlayerBatches
  b.drawCursor
  if turn.nr > 0: b.drawDice
  if turn.nr > 0 and not isRollingDice(): 
    b.drawMoveToSquares mouseOnSquare()

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    blueDeck.leftMousePressed
    m.leftMousePressed blueDeck
    if turn.nr > 0 and mouseOnDice() and mayReroll(): 
      startDiceRoll()
  elif m.rightMousePressed: m.rightMousePressed blueDeck

proc keyboard (k:KeyboardEvent) =
  if k.button == ButtonUnknown and not isRollingDice():
    editDiceRoll k.rune.toUTF8

proc timer = showCursor = not showCursor

proc timerCall:TimerCall =
  TimerCall(call:timer,lastTime:cpuTime(),secs:0.4)

setVolume 0.15
blueDeck.initCardSlots discardPile,popUpCard,drawPile
addImage("bg",bg)
addCall Call(draw:draw,mouse:mouse,keyboard:keyboard,timer:timerCall())
runWinWith: callTimers()
playerKindsToFile playerKinds
