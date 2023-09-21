import win
import deck
import players
# import batch

const
  popUpCard = Rect(x:500,y:50,w:cardWidth,h:cardHeight)
  drawPile = Rect(x:650,y:500,w:cardWidth*0.5,h:cardHeight*0.5)
  discardPile = Rect(x:800,y:500,w:cardWidth*0.5,h:cardHeight*0.5)

let
  bg = readImage "pics\\bgblue.png"
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)

var blueDeck = newDeck "dat\\blues.txt"

proc draw(b:var Boxy) =
  b.drawImage "bg",bgRect
  b.paintCards blueDeck,turnPlayer.hand
  b.drawPlayerBatches

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    blueDeck.leftMousePressed
    m.leftMousePressed blueDeck

blueDeck.initCardSlots discardRect = discardPile,drawRect = drawPile,popUpRect = popUpCard
nextPlayerTurn()
drawFrom blueDeck
addImage("bg",bg)
addCall Call(draw:draw,mouse:mouse)
runWin
playerKindsToFile playerKinds
