import win
import deck
import play
import board
import times
import megasound
import strutils

const
  popUpCard = Rect(x:500,y:275,w:cardWidth,h:cardHeight)
  drawPile = Rect(x:855,y:495,w:110,h:180)
  discardPile = Rect(x:1025,y:495,w:cardWidth*0.441,h:cardHeight*0.441)

let
  bg = readImage "pics\\bggreen.png"
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)

var 
  blueDeck = newDeck "dat\\blues.txt"
  dieEdit:int

proc draw(b:var Boxy) =
  b.drawImage "bg",bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.paintCards blueDeck,turnPlayer.hand
  b.drawPlayerBatches
  b.drawCursor
  if turn.nr > 0: b.drawDice
  if turn.nr > 0 and not isRollingDice(): b.drawMoveToSquares mouseOnSquare()

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    blueDeck.leftMousePressed
    m.leftMousePressed blueDeck
  elif m.rightMousePressed: m.rightMousePressed blueDeck

proc keyboard (k:KeyboardEvent) =
  if k.button == ButtonUnknown and not isRollingDice():
    let c = k.rune.toUTF8
    var i = try: c.parseInt except: 0
    if c.toUpper == "D": dieEdit = 1 
    elif dieEdit > 0 and i in 1..6:
      diceRoll[dieEdit] = DieFaces(i)
      dieEdit = if dieEdit == 2: 0 else: dieEdit + 1
    else: dieEdit = 0

proc timer = showCursor = not showCursor

proc timerCall:TimerCall =
  TimerCall(call:timer,lastTime:cpuTime(),secs:0.4)

setVolume 0.15
blueDeck.initCardSlots discardPile,popUpCard,drawPile
addImage("bg",bg)
addCall Call(draw:draw,mouse:mouse,keyboard:keyboard,timer:timerCall())
runWinWith: callTimers()
playerKindsToFile playerKinds
