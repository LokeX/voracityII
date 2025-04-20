import win
import batch
# import colors
import strutils
import game
import megasound
import sequtils

type
  BoardSquares* = array[61,Square]
  Square* = tuple[nr:int,name:string,dims:Dims,icon:Image]
  Dims* = tuple[area:Area,rect:Rect]
  MoveSelection* = tuple
    hoverSquare,fromSquare,toSquare:int
    toSquares:seq[int]
    event:bool
  AnimationMove* = tuple[fromSquare,toSquare:int]
  MoveAnimation* = object
    active*:bool
    frame,moveOnFrame,currentSquare,fromsquare*,toSquare*:int
    color:PlayerColor
    movesIdx:int
    moves:seq[AnimationMove]
    squares:seq[int]

const
  playerColors*:array[PlayerColor,Color] = [
    color(50,0,0),color(0,50,0),
    color(0,0,50),color(50,50,0),
    color(255,255,255),color(1,1,1)
  ]
  playerColorsTrans*:array[PlayerColor,Color] = [
    color(50,0,0,150),color(0,50,0,150),
    color(0,0,50,150),color(50,50,0,150),
    color(255,255,255,150),color(1,1,1,150)
  ]
  contrastColors*:array[PlayerColor,Color] = [
    color(1,1,1),
    color(255,255,255),
    color(1,1,1),
    color(255,255,255),
    color(1,1,1),
    color(255,255,255),
  ]  

const
  diceRollRects = (Rect(x:1450,y:60,w:50,h:50),Rect(x:1450,y:120,w:50,h:50))
  diceRollDims:array[1..2,Dims] = [
    (diceRollRects[0].toArea,diceRollRects[0]),
    (diceRollRects[1].toArea,diceRollRects[1])
  ]
  boardPos = vec2(225,50)
  (bx*,by*) = (boardPos.x,boardPos.y)
  sqOff = 43.0
  (tbxo,lryo) = (220.0,172.0)
  (tyo,byo) = (70.0,690.0)
  (lxo,rxo) = (70.0,1030.0)
  maxRollFrames = 120

var
  diceRolls*:seq[Dice]
  dieRollFrame* = maxRollFrames
  moveSelection*:MoveSelection = (-1,-1,-1,@[],false)
  moveAnimation*:MoveAnimation
  dieEdit:int

proc editDiceRoll*(input:string) =  
  if input.toUpper == "D": dieEdit = 1 
  elif dieEdit > 0 and (let dieFace = try: input.parseInt except: 0; dieFace in 1..6):
    diceRoll[dieEdit] = DieFace(dieFace)
    dieEdit = if dieEdit == 2: 0 else: dieEdit + 1
  else: dieEdit = 0

proc mouseOnDice*:bool = diceRollDims.anyIt mouseOn it.area

proc rotateDie(b:var Boxy,die:int) =
  b.drawImage(
    $diceRoll[die],
    center = vec2(
      (diceRollDims[die].rect.x+(diceRollDims[die].rect.w/2)),
      diceRollDims[die].rect.y+(diceRollDims[die].rect.h/2)),
    angle = ((dieRollFrame div 3)*9).toFloat,
    tint = color(1,1,1,1.0)
  )

proc drawDice*(b:var Boxy) =
  if dieRollFrame == maxRollFrames:
    for i,die in diceRoll:
      b.drawImage($die,vec2(diceRollDims[i].rect.x,diceRollDims[i].rect.y))
  else:
    rollDice()
    b.rotateDie(1)
    b.rotateDie(2)
    inc dieRollFrame
    if dieRollFrame == maxRollFrames: 
      diceRolls.add diceRoll #please: don't do as I do

proc isRollingDice*: bool = dieRollFrame < maxRollFrames

proc isDouble*: bool = diceRoll[1] == diceRoll[2]

proc startDiceRoll*(rollFrames:int) =
  if not isRollingDice(): 
    dieRollFrame = rollFrames
    playSound("wuerfelbecher")

proc endDiceRoll* = dieRollFrame = maxRollFrames

proc mayReroll*:bool = isDouble() and not isRollingDice()

func squareDims:array[61,Dims] =
  result[0].rect = Rect(x:1225,y:150,w:35,h:100)
  for i in 0..17:
    result[37+i].rect = Rect(x:tbxo+(i.toFloat*sqOff),y:tyo,w:35,h:100)
    result[24-i].rect = Rect(x:tbxo+(i.toFloat*sqOff),y:byo,w:35,h:100)
    if i < 12:
      result[36-i].rect = Rect(x:lxo,y:lryo+(i.toFloat*sqOff),w:100,h:35)
      if i < 6:
        result[55+i].rect = Rect(x:rxo,y:lryo+(i.toFloat*sqOff),w:100,h:35)
      else:
        result[1+(i-6)].rect = Rect(x:rxo,y:lryo+(i.toFloat*sqOff),w:100,h:35)
  for dim in result.mitems:
    dim.area = toArea(dim.rect.x+bx,dim.rect.y+by,dim.rect.w,dim.rect.h)

func iconPath(square:Square):string =
  let squareName = square.name.toLower
  "pics\\board_icons\\"&(
    case squareName:
    of "villa","condo","slum": "livingspaces"
    of "bank","shop","bar","highway": squareName
    of "gas station": "gas_station"
    else: $square.nr
  )&".png"

func typesetIcon(font:Font,txt:string,width,height:int):Arrangement =
  typeset(
    font,txt,
    bounds = vec2(width.toFloat,height.toFloat),
    hAlign = CenterAlign,
    vAlign = MiddleAlign,
    wrap = false
  )

let
  asap = readTypeface "fonts\\AsapCondensed-Bold.ttf"
  whiteAsap16 = setNewFont(asap,size = 20,color = color(1,1,0))
  blackAsap16 = setNewFont(asap,size = 20,color = color(0,0,0))

proc initIcon(square:Square):Image =
  result = readImage square.iconPath
  if square.name in ["Villa","Condo","Slum","Bank","Shop"]:
    let 
      txt = whiteAsap16.typesetIcon(square.name,result.width,result.height)
      stroke = blackAsap16.typesetIcon(square.name,result.width,result.height)
    result.fillText(txt,translate vec2(0,0))
    result.strokeText(stroke,translate(vec2(0,0)),1.0)

proc paintIcon(square:Square):Image =
  let 
    shadowSize = 4.0
    icon = square.initIcon
    ctx = newImage(icon.width+shadowSize.toInt,icon.height+shadowSize.toInt).newContext
  ctx.fillStyle = color(0,0,0,150)
  ctx.fillrect(
    Rect(x:shadowSize,y:shadowSize,w:icon.width.toFloat,h:icon.height.toFloat))
  ctx.drawImage(icon,0,0)
  result = ctx.image

proc buildBoardSquares*(path:string):BoardSquares =
  const squareDims = squareDims()
  var count = 0
  result[0] = (0,"Removed",squareDims[0],nil)
  for name in lines path:
    inc count
    result[count] = (count,name,squareDims[count],nil)
    result[count].icon = result[count].paintIcon

let 
  boardImg* = readImage "pics\\engboard.jpg"
  squares* = buildBoardSquares "dat\\board.txt"

proc mouseOnSquare*:int =
  for square in squares:
    if mouseOn square.dims.area:
      return square.nr
  result = -1

proc paintSquares*(img:var Image,squareNrs:seq[int],color:Color) =
  var ctx = img.newContext
  ctx.fillStyle = color
  for i in squareNrs: 
    ctx.fillRect(squares[i].dims.rect)

proc paintSquares*(squareNrs:seq[int],color:Color):Image =
  result = newImage(boardImg.width,boardImg.height)
  result.paintSquares(squareNrs,color)

proc paintMoveToSquares*(squares:seq[int]):Image =
  result = newImage(boardImg.width,boardImg.height)
  result.paintSquares(squares.deduplicate,color(0,0,0,100))

var 
  moveToSquaresPainter* = DynamicImage[seq[int]](
    name:"moveToSquares",
    area:(bx.toInt,by.toInt,0,0),
    updateImage:paintMoveToSquares,
    update:true
  )

proc pieceOn*(color:PlayerColor,squareNr:int):Rect =
  let 
    r = squares[squareNr].dims.rect
    colorOffset = (color.ord*15).toFloat
  if squareNr == 0: Rect(x:r.x,y:r.y+6+colorOffset,w:r.w-10,h:12)
  elif r.w == 35: Rect(x:r.x+5,y:r.y+6+colorOffset,w:r.w-10,h:12)
  else: Rect(x:r.x+6+colorOffset,y:r.y+5,w:12,h:r.h-10)

func squareDistance(fromSquare,toSquare:int):int =
  if fromSquare < toSquare:
    toSquare-fromSquare
  else: (toSquare+60)-fromSquare

func animationSquares(fromSquare,toSquare:int):seq[int] =
  var count = fromSquare
  for _ in 1..squareDistance(fromSquare,toSquare):
    result.add count
    inc count
    if count > 60: 
      count = 1

proc startMoveAnimation*(color:PlayerColor,fromSquare,toSquare:int) =
  moveAnimation.fromsquare = fromSquare
  moveAnimation.toSquare = toSquare
  moveAnimation.squares = animationSquares(
    moveAnimation.fromSquare,
    moveAnimation.toSquare
  )
  moveAnimation.color = color
  moveAnimation.frame = 0
  moveAnimation.moveOnFrame = 60 div moveAnimation.squares.len
  moveAnimation.currentSquare = 0
  moveAnimation.active = true
 
proc startMovesAnimations*(color:PlayerColor,moves:seq[AnimationMove]) =
  moveAnimation.moves = moves
  moveAnimation.movesIdx =  0
  startMoveAnimation(color,
    moves[moveAnimation.movesIdx].fromSquare,
    moves[moveAnimation.movesIdx].toSquare
  )

proc nextMoveAnimation =
  inc moveAnimation.movesIdx
  startMoveAnimation(moveAnimation.color,
    moveAnimation.moves[moveAnimation.movesIdx].fromSquare,
    moveAnimation.moves[moveAnimation.movesIdx].toSquare
  )

proc moveAnimationActive*:bool = moveAnimation.active

proc doMoveAnimation*(b:var Boxy) =
  if moveAnimation.active:
    inc moveAnimation.frame
    if moveAnimation.frame >= moveAnimation.moveOnFrame-1:
      moveAnimation.frame = 0
      inc moveAnimation.currentSquare
    for square in 0..moveAnimation.currentSquare:
      var pieceRect = pieceOn(
        moveAnimation.color,moveAnimation.squares[square]
      )
      pieceRect.x = bx+pieceRect.x
      pieceRect.y = by+pieceRect.y
      b.drawRect(pieceRect,playerColors[moveAnimation.color])
    if moveAnimation.currentSquare == moveAnimation.squares.high:
      if moveAnimation.moves.len > 1 and moveAnimation.movesIdx < moveAnimation.moves.high:
        nextMoveAnimation()
      else: moveAnimation.active = false

proc drawBoard*(b:var Boxy) =
  b.drawImage("board",boardPos)

addImage("board",boardImg)
for die in DieFace: 
  addImage $die,("pics\\diefaces\\"&($die.ord)&".png").readImage

# import win
# import game
# import sequtils
# import strutils
import random
# import board

type
  Reveal* = enum Front,Back
  CardSlot = tuple[area:Area,rect:Rect]
  # ProtoCard = array[4,string]
  # PlanSquares = tuple[required,oneInMany:seq[int]]
  # CardKind* = enum Deed,Plan,Job,Event,News,Mission
  # BlueCard* = object
  #   title*:string
  #   case cardKind*:CardKind
  #   of Plan,Mission,Job,Deed:
  #     squares*:PlanSquares
  #     cash*:int
  #     eval*:int
  #     covered*:bool
  #   of Event,News:
  #     moveSquares*:seq[int]
  #     bgPath:string
  # Deck* = object 
  #   fullDeck*,drawPile*,discardPile*:seq[BlueCard]
  #   lastDrawn*:string

func buildCardSlots(r:Rect,cardsInRow:range[2..8]):seq[CardSlot] =
  const
    slotRanges:array[2..8,HSlice[int,int]] = [0..7,0..17,0..31,0..49,0..71,0..97,0..128]
    padding:array[2..8,float] = [20,10,5,3,2,1,1]
  let
    sizeFactor = 1.0/cardsInRow.toFloat
    rect = Rect(x:r.x,y:r.y,w:r.w*sizeFactor,h:r.h*sizeFactor)
  var slot:Rect
  for i in slotRanges[cardsInRow]:
    slot = Rect(w:rect.w,h:rect.h,
      x:rect.x+((rect.w+padding[cardsInRow])*(i mod cardsInRow).toFloat),
      y:rect.y+((rect.h+padding[cardsInRow])*(i div cardsInRow).toFloat)
    )
    result.add (slot.toArea,slot)

func buildCardSlots(initPosDim:Rect):seq[seq[CardSlot]] =
  for cardsInRow in 2..8: result.add buildCardSlots(initPosDim,cardsInRow)

const
  (cardWidth*,cardHeight*) = (255.0,410.0)
  popUpCardRect = Rect(x:500,y:275,w:cardWidth*0.9,h:cardHeight*0.9)
  drawPileRect = Rect(x:855,y:495,w:110,h:180)
  discardPileRect = Rect(x:1025,y:495,w:cardWidth*0.441,h:cardHeight*0.441)
  drawPileArea* = drawPileRect.toArea
  discardPileArea* = discardPileRect.toArea
  slotCapacities = [8,18,32,50,72,98,128]
  initPosDim = Rect(x:1580.0,y:50.0,w:cardWidth,h:cardHeight)
  cardSlotsX = initPosDim.buildCardSlots

let
  deedbg = readImage "pics\\deedbg.jpg"
  planbg = readImage "pics\\bronze_plates.jpg"
  jobbg = readImage "pics\\silverback.jpg"
  missionbg = readImage "pics\\mission.jpg"
  blueBack = readImage "pics\\blueback.jpg"
  roboto = readTypeface "fonts\\Roboto-Regular_1.ttf"
  point = readTypeface "fonts\\StintUltraCondensed-Regular.ttf"
  ibmplex = readTypeFace "fonts\\IBMPlexSansCondensed-SemiBold.ttf"

func nrOfslots(nrOfCards:int):int =
  for i,capacity in slotCapacities:
    if nrOfCards <= capacity: return i
  cardSlotsX.high

iterator cardSlots*(cards:seq[BlueCard]):(BlueCard,CardSlot) =
  if cards.len > 0:
    var i = 0
    let slots = cardSlotsX[cards.len.nrOfslots]
    while i <= cards.high and i <= slots.high:
      yield (cards[i],slots[i])
      inc i

# func parseProtoCards(lines:sink seq[string]):seq[ProtoCard] =
#   var 
#     cardLine:int
#     protoCard:ProtoCard 
#   for line in lines:
#     protocard[cardLine] = line
#     if cardLine == 3:
#       result.add protoCard
#       cardLine = 0
#     else: inc cardLine

# func parseCardSquares(str:string,brackets:array[2,char]):seq[int] =
#   let (f,l) = (str.find(brackets[0]),str.find(brackets[1]))
#   if -1 in [f,l]: @[] else: str[f+1..l-1].split(',').mapIt it.parseInt

# func parseCardKindFrom(kind:string):CardKind =
#   try: CardKind(CardKind.mapIt(($it).toLower).find kind[0..kind.high-1].toLower) 
#   except: raise newException(CatchableError,"Error, parsing CardKind: "&kind)

# func newBlueCards(protoCards:seq[ProtoCard]):seq[BlueCard] =
#   for protoCard in protoCards:
#     result.add BlueCard(title:protoCard[1],cardKind:parseCardKindFrom protoCard[0])
#     if result[^1].cardKind in [Event,News]:
#       result[^1].moveSquares = parseCardSquares(protoCard[2],['{','}'])
#       result[^1].bgPath = protoCard[3]
#     else:
#       result[^1].squares = (
#         parseCardSquares(protoCard[2],['{','}']),
#         parseCardSquares(protoCard[2],['[',']']),
#       )
#       result[^1].cash = protoCard[3].parseInt

func required(plan:BlueCard,squares:BoardSquares):seq[string] =
  let 
    planSquares = plan.squares.required.deduplicate
    squareAdresses = planSquares.mapIt squares[it].name&" Nr. " & $squares[it].nr
    nrOfPieces = planSquares.mapit plan.squares.required.count it
    piecesTxt = nrOfPieces.mapIt(if it > 1: " pieces on the " else: " piece on the ")
    piecesOn = zip(nrOfPieces,piecesTxt).mapIt $it[0]&it[1]
    squareLines = zip(piecesOn,squareAdresses).mapIt it[0]&it[1]
  result = squareLines
  if plan.squares.oneInMany.len > 0: 
    result.add "1 piece on any "&squares[plan.squares.oneInMany[0]].name 

func buildShadowRect(rect:Rect,borderSize,shadowSize:float):Rect =
  result = rect
  result.x += shadowSize+borderSize
  result.y += shadowSize+borderSize

func buildInnerRect(rect:Rect,borderSize:float):Rect =
  result = rect
  result.x += borderSize
  result.y += borderSize
  result.w -= (borderSize*2)
  result.h -= (borderSize*2)

func eventSquaresTxt(blue:BlueCard,squares:BoardSquares):seq[string] =
  for i,square in blue.moveSquares:
    result.add "The "&squares[square].name&" Nr."&($squares[square].nr)
    if i < blue.moveSquares.high: result[^1].add " or:"

func eventText(blue:BlueCard,squares:BoardSquares):seq[string] =
  case blue.title
  of "Sour piss":
    result.add "Must: Shuffle piles"
    result.add "May: Draw a card"
  of "Happy hour": 
    result.add "Draw up to 3 extra cards"
  of "Massacre": 
    result.add "All pieces on a random bar,"
    result.add "with the most pieces,"
    result.add "where you have a piece,"
    result.add "are removed from the board"
  of "Deja vue": 
    result.add "Must: Draw a card"
    result.add "from the discard pile"
  else:
    result.add "A piece of yours,"
    result.add "on any random Bar, moves to:"
    result.add blue.eventSquaresTxt squares

func newsText(blue:BlueCard,squares:BoardSquares):seq[string] =
  result.add "All pieces on: "&
    squares[blue.moveSquares[0]].name&" Nr."&($squares[blue.moveSquares[0]].nr)
  if blue.moveSquares[1] == 0:
    result.add "Are removed from the board"
  else: result.add "Moves to: "&
    squares[blue.moveSquares[1]].name&" Nr."&($squares[blue.moveSquares[1]].nr)

proc typesetBoxedText(blue:BlueCard,squares:BoardSquares):(Arrangement,float32) =
  var txt:seq[string]
  case blue.cardKind
  of Plan,Mission,Job,Deed:
    txt = blue.required squares
    txt.insert "Requires: ",0
    txt.add "Rewards:\n" & ($blue.cash).insertSep('.')&" in cash"
  of Event: txt.add blue.eventText squares
  of News: txt.add blue.newsText squares
  let 
    font = setNewFont(roboto,13.0,color(0,0,0))
    boxText = font.typeset txt.join "\n"
  (boxText,boxText.layoutBounds.y)

proc paintTextBoxOn(card:BlueCard,img:var Image,squares:BoardSquares) =
  let
    (textPadX,textPadY,borderSize,shadowSize,angle) = (15.0,15.0,0.0,3.0,0.0)  
    (boxText,textHeight) = card.typesetBoxedText squares
    boxPosX = 20.0
    boxWidth = img.width.toFloat-(boxPosX*2)-shadowSize-(borderSize*2)-3
    boxHeight = (textheight+(textPadY*2)+(borderSize*2))
    boxPosY = (img.height-25).toFloat-shadowSize-(borderSize*2)-boxHeight
    boxRect = Rect(x:boxPosX,y:boxPosY,w:boxWidth,h:boxHeight)
    shadowRect = boxRect.buildShadowRect(borderSize,shadowsize)
    innerBoxRect = boxRect.buildInnerRect borderSize
    textX = boxRect.x+textPadX+borderSize
    textY = boxRect.y+textPadY+borderSize
    ctx = img.newContext
  ctx.fillStyle = color(0,0,0,150)
  ctx.fillRoundedRect(shadowRect,angle)
  ctx.fillStyle = color(1,1,1,150)
  ctx.fillRoundedRect(boxRect,angle)
  ctx.fillStyle = color(1,1,1,150)
  ctx.fillRoundedRect(innerBoxRect,angle)
  img = ctx.image
  img.fillText(boxText,translate vec2(textX,textY))

proc titleArrangements(card:BlueCard):(Arrangement,Arrangement,Arrangement) =
  let 
    titleFont = setNewFont(point,45.0,color(1,1,0))
    titleStroke = setNewFont(point,45.0,color(0,0,0))
    titleShadow = setNewFont(point,45.0,color(0,0,0,50))
  (titleFont.typeset(card.title),
  titleStroke.typeset(card.title),
  titleShadow.typeset(card.title))

proc paintTitleOn(card:BlueCard,img:var Image,borderSize:float) =
  let
    (title,strokeTitle,shadowTitle) = card.titleArrangements
    shadowOffset = 2.0
    titleX = 10.0+borderSize
    titleY = 5.0+borderSize
  img.fillText(shadowTitle,translate vec2(titleX+shadowOffset,titleY+shadowOffset))
  img.fillText(title,translate vec2(titleX,titleY))
  img.strokeText(strokeTitle,translate vec2(titleX,titleY),0.75)

proc paintBackgroundImage(card:BlueCard,ctx:Context,borderSize:float):Image =
  result = ctx.image
  case card.cardKind
  of Deed: result.draw(deedbg,translate vec2(borderSize,borderSize))
  of Plan: result.draw(planbg,translate vec2(borderSize,borderSize))
  of Mission: result.draw(missionbg,translate vec2(borderSize,borderSize))
  of Job: result.draw(jobbg,translate vec2(borderSize,borderSize))
  of Event,News:result.draw(readImage(card.bgPath),translate vec2(borderSize,borderSize))

proc paintBackground(card:BlueCard,borderSize:float):Image =
  let
    shadowSize = 5.0
    offset = shadowSize+borderSize
    dimAdd = borderSize*2
    width = planbg.width.toFloat+dimAdd
    height = planbg.height.toFloat+dimAdd
    ctx = newContext((width+shadowSize).toInt,(height+shadowSize).toInt)
  ctx.fillStyle = color(0,0,0,175)
  ctx.fillRect(Rect(x:offset,y:offset,w:width,h:height))
  ctx.fillStyle = color(0,0,0)
  ctx.fillRect(Rect(x:0,y:0,w:width,h:height))
  card.paintBackgroundImage(ctx,borderSize)

proc paintCardKindOn(card:BlueCard,img:var Image,borderSize:float) =
  let 
    kindFont = setNewFont(ibmplex,16.0,color(0,0,0))
    cardKind = kindFont.typeset $card.cardKind
  img.fillText(cardKind,translate vec2(10+borderSize,60))

proc paintIconsOn(card:BlueCard,img:var Image,squares:BoardSquares) =
  var cardSquares:seq[int] 
  case card.cardKind
  of Mission,Plan,Job,Deed:
    cardSquares = card.squares.required
    if card.squares.oneInMany.len > 0:
      cardSquares.add card.squares.oneInMany[0]
  of Event,News: cardSquares.add card.moveSquares
  let x_offset = if cardSquares.len == 1: 100.0 else: 55.0
  var (x,y) = (x_offset,120.0)
  for idx,squareNr in cardSquares:
    img.draw(squares[squareNr].icon,translate vec2(x,y))
    x += squares[squareNr].icon.width.toFloat*1.5
    if idx == 1: 
      x = x_offset+(if cardSquares.len == 3: 45 else: 0)
      y += squares[squareNr].icon.height.toFloat*1.5

proc paintBlue(card:BlueCard,squares:BoardSquares):Image =
  let borderSize = 1.0
  result = card.paintBackground borderSize
  card.paintTitleOn(result,borderSize)
  card.paintCardKindOn(result,borderSize)
  if (card.cardKind notIn [Event,News]) or card.moveSquares[^1] notIn [0,-1]:
    card.paintIconsOn(result,squares)
  card.paintTextBoxOn(result,squares)

proc initGraphics*(deck:Deck) =
  addImage("blueback",blueBack)
  for idx,img in deck.fullDeck.mapIt it.paintBlue squares:
    addImage(deck.fullDeck[idx].title,img)

# proc newDeck*(path:string):Deck =
#   result = Deck(fullDeck:path.lines.toSeq.parseProtoCards.newBlueCards)
#   result.drawPile = result.fullDeck
#   result.drawPile.shuffle

# proc resetDeck*(deck:var Deck) =
#   deck.discardPile.setLen 0
#   deck.drawPile = deck.fullDeck
#   deck.drawPile.shuffle
#   deck.lastDrawn = ""

# proc shufflePiles*(deck:var Deck) =
#   deck.drawPile.add deck.discardPile
#   deck.discardPile.setLen 0
#   deck.drawPile.shuffle

# proc drawFrom*(hand:var seq[BlueCard],deck:var Deck) =
#   if deck.drawPile.len == 0:
#     deck.shufflePiles
#   hand.add deck.drawPile.pop
#   deck.lastDrawn = hand[^1].title

# proc drawFromDiscardPile*(hand:var seq[BlueCard],deck:var Deck) =
#   if deck.discardPile.len > 0:
#     hand.add deck.discardPile.pop
#     deck.lastDrawn = hand[^1].title

# proc playTo*(hand:var seq[BlueCard],deck:var Deck,card:int) =
#   deck.discardPile.add hand[card]
#   hand.del card

proc paintCardSquares*(blue:BlueCard):Image =
  result = newImage(boardImg.width,boardImg.height)
  result.paintSquares(blue.squares.required.deduplicate,color(0,0,0,100))
  if blue.squares.oneInMany.len > 0:
    result.paintSquares(blue.squares.oneInMany,color(100,0,0,100))

var 
  cardSquaresPainter* = DynamicImage[BlueCard](
    name:"cardSquares",
    area:(bx.toInt,by.toInt,0,0),
    updateImage:paintCardSquares,
    update:true
  )

proc drawCardSquares(b:var Boxy,blue:BlueCard) =
  if blue.cardKind in [Mission,Plan,Job,Deed]:
    if cardSquaresPainter.context.title != blue.title:
      cardSquaresPainter.update = true
      cardSquaresPainter.context = blue
    b.drawDynamicImage cardSquaresPainter

proc paintCards*(b:var Boxy,deck:Deck,cards:seq[BlueCard],show:Reveal = Front) =
  if show == Front and deck.lastDrawn.len > 0 and mouseOn drawPileArea:
    b.drawImage(deck.lastDrawn,popUpCardRect)
    if (let cardNr = deck.fullDeck.mapIt(it.title).find(deck.lastDrawn); cardNr != -1):
      b.drawCardSquares deck.fullDeck[cardNr]
  if deck.discardPile.len > 0:
    b.drawImage(deck.discardPile[^1].title,discardPileRect)
    if mouseOn discardPileArea:
      b.drawImage(deck.discardPile[^1].title,popUpCardRect)
      b.drawCardSquares deck.discardPile[^1]
  for (card,slot) in cards.cardSlots:
    if show == Back:
      b.drawImage("blueback",slot.rect)
    else: 
      b.drawImage(card.title,slot.rect)
    if show == Front and mouseOn slot.area:
      b.drawImage(card.title,popUpCardRect)
      b.drawCardSquares card

type
  BatchSetup = tuple
    name:string
    bgColor:PlayerColor
    entries:seq[string]
    hAlign:HorizontalAlignment
    font:string
    fontSize:float
    padding:(int,int,int,int)

const
  (pbx,pby) = (20,20)
  kalam* = "fonts\\Kalam-Bold.ttf"
  fjallaOneRegular* = "fonts\\FjallaOne-Regular.ttf"
  ibmBold* = "fonts\\IBMPlexMono-Bold.ttf"
  inputEntries:seq[string] = @[
    "Write player handle:\n",
    "\n",
  ]
  condensedRegular = "fonts\\AsapCondensed-Regular.ttf"
  titleBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBatchInit = BatchInit(
    kind:InputBatch,
    name:"inputBatch",
    titleOn:true,
    titleLine:(color:color(1,1,0),bgColor:color(0,0,0),border:titleBorder),
    pos:(400,200),
    inputCursor:(0.5,color(0,1,0)),
    inputLine:(color(0,1,0),color(0,0,0),inputBorder),
    padding:(40,40,20,20),
    entries:inputEntries,
    inputMaxChars:8,
    alphaOnly:true,
    font:(condensedRegular,30.0,color(1,1,1)),
    bgColor:color(0,0,0),
    border:(15,25,color(0,0,100)),
    shadow:(15,1.5,color(255,255,255,200))
  )

var
  inputBatch* = newBatch inputBatchInit
  playerBatches*:array[6,Batch]
  showCursor*:bool

proc playerBatch(setup:BatchSetup,yOffset:int):Batch = 
  newBatch BatchInit(
    kind:TextBatch,
    name:setup.name,
    pos:(pbx,pby+yOffset),
    padding:setup.padding,
    entries:setup.entries,
    hAlign:setup.hAlign,
    fixedBounds:(175,110),
    font:(setup.font,setup.fontSize,contrastColors[setup.bgColor]),
    border:(3,20,contrastColors[setup.bgColor]),
    blur:2,
    opacity:25,
    bgColor:playerColors[setup.bgColor],
    shadow:(10,1.75,color(255,255,255,100))
  )

proc playerBatchTxt(playerNr:int):seq[string] =
  if turn.nr == 0:
    if playerKinds[playerNr] == Human and playerHandles[playerNr].len > 0:
      @[playerHandles[playerNr]]
    else:
      @[$playerKinds[playerNr]]
  else: @[
    "Turn Nr: "&($turn.nr)&"\n",
    "Cards: "&($players[playerNr].hand.len)&"\n",
    "Cash: "&(insertSep($players[playerNr].cash,'.'))
  ]

proc updateBatch*(playerNr:int) =
  playerBatches[playerNr].setSpanTexts playerBatchTxt playerNr
  playerBatches[playerNr].update = true

proc batchSetup(playerNr:int):BatchSetup =
  let player = players[playerNr]
  result.name = $player.color
  result.bgColor = player.color
  if turn.nr == 0: 
    result.hAlign = CenterAlign
    result.font = fjallaOneRegular
    result.fontSize = 30
    result.padding = (0,0,35,35)
  else: 
    result.hAlign = LeftAlign
    result.font = kalam
    result.fontSize = 18
    result.padding = (20,20,12,10)
  result.entries = playerBatchTxt playerNr

proc newPlayerBatches*:array[6,Batch] =
  var 
    yOffset = pby
    setup:BatchSetup
  for playerNr,_ in players:
    if playerNr > 0: 
      yOffset = pby+((result[playerNr-1].rect.h.toInt+15)*playerNr)
    setup = batchSetup playerNr
    result[playerNr] = setup.playerBatch yOffset
    result[playerNr].update = true

randomize()

