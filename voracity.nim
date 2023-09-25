import win
import deck
import play
import board

const
  popUpCard = Rect(x:500,y:275,w:cardWidth,h:cardHeight)
  drawPile = Rect(x:855,y:495,w:110,h:180)
  discardPile = Rect(x:1025,y:495,w:cardWidth*0.441,h:cardHeight*0.441)

let
  bg = readImage "pics\\bgblue.png"
  bgRect = Rect(x:0,y:0,w:scaledWidth.toFloat,h:scaledHeight.toFloat)

var 
  blueDeck = newDeck "dat\\blues.txt"

proc draw(b:var Boxy) =
  b.drawImage "bg",bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.paintCards blueDeck,turnPlayer.hand
  b.drawPlayerBatches

proc mouse(m:KeyEvent) =
  if m.leftMousePressed:
    blueDeck.leftMousePressed
    m.leftMousePressed blueDeck

blueDeck.initCardSlots discardPile,popUpCard,drawPile
nextPlayerTurn()
drawFrom blueDeck
addImage("bg",bg)
addCall Call(draw:draw,mouse:mouse)
runWin
playerKindsToFile playerKinds
