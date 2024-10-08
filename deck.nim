import win
import sequtils
import strutils
import random
import board
import misc

type
  Reveal* = enum Front,Back
  ProtoCard = array[4,string]
  PlanSquares = tuple[required,oneInMany:seq[int]]
  CardKind* = enum Deed,Plan,Job,Event,News,Mission
  BlueCard* = object
    title*:string
    case cardKind*:CardKind
    of Plan,Mission,Job,Deed:
      squares*:PlanSquares
      cash*:int
      eval*:int
      covered*:bool
    of Event,News:
      moveSquares*:seq[int]
      bgPath:string
  Deck* = object 
    fullDeck*,drawPile*,discardPile*:seq[BlueCard]
    popUpSlot*,drawSlot*,discardSlot*:CardSlot
    lastDrawn*:string
  CardSlot = tuple[nr:int,name:string,area:Area,rect:Rect]

const
  (cardWidth*,cardHeight*) = (255.0,410.0)
  popUpCard = Rect(x:100,y:100,w:cardWidth,h:cardHeight)
  drawPile = Rect(x:500,y:500,w:cardWidth,h:cardHeight)
  discardPile = Rect(x:800,y:500,w:cardWidth,h:cardHeight)
  slotCapacities = [8,18,32,50,72,98,128]
  slotRanges:array[2..8,HSlice[int,int]] = [0..7,0..17,0..31,0..49,0..71,0..97,0..128]
  padding:array[2..8,float] = [20,10,5,3,2,1,1]

func buildCardSlots(r:Rect,cardsInRow:range[2..8]):seq[CardSlot] =
  let
    sizeFactor = 1.0/cardsInRow.toFloat
    rect = Rect(x:r.x,y:r.y,w:r.w*sizeFactor,h:r.h*sizeFactor)
  for i in slotRanges[cardsInRow]:
    let slot = Rect(w:rect.w,h:rect.h,
      x:rect.x+((rect.w+padding[cardsInRow])*(i mod cardsInRow).toFloat),
      y:rect.y+((rect.h+padding[cardsInRow])*(i div cardsInRow).toFloat))
    result.add (i,"slot"&($i),slot.toArea,slot)

func buildCardSlots(initPosDim:Rect):seq[seq[CardSlot]] =
  for cardsInRow in 2..8: result.add buildCardSlots(initPosDim,cardsInRow)

const
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

func parseProtoCards(lines:sink seq[string]):seq[ProtoCard] =
  var 
    cardLine:int
    protoCard:ProtoCard 
  for line in lines:
    protocard[cardLine] = line
    if cardLine == 3:
      result.add protoCard
      cardLine = 0
    else: inc cardLine

func parseCardSquares(str:string,brackets:array[2,char]):seq[int] =
  let (f,l) = (str.find(brackets[0]),str.find(brackets[1]))
  if -1 in [f,l]: @[] else: str[f+1..l-1].split(',').mapIt it.parseInt

func parseCardKindFrom(kind:string):CardKind =
  try: CardKind(CardKind.mapIt(($it).toLower).find kind[0..kind.high-1].toLower) 
  except: raise newException(CatchableError,"Error, parsing CardKind: "&kind)

func buildPlanFrom(protoCard:sink ProtoCard,kind:CardKind):BlueCard =
  result = BlueCard(title:protoCard[1],cardKind:kind)
  result.squares = (
    parseCardSquares(protoCard[2],['{','}']),
    parseCardSquares(protoCard[2],['[',']']),)
  result.cash = protoCard[3].parseInt

func buildEventFrom(protoCard:sink ProtoCard):BlueCard =
  result = BlueCard(title:protoCard[1],cardKind:Event)
  result.moveSquares = parseCardSquares(protoCard[2],['{','}'])
  result.bgPath = protoCard[3]

func buildNewsFrom(protoCard:sink ProtoCard):BlueCard =
  result = BlueCard(title:protoCard[1],cardKind:News)
  result.moveSquares = parseCardSquares(protoCard[2],['{','}'])
  result.bgPath = protoCard[3]

func newBlueCards(protoCards:seq[ProtoCard]): seq[BlueCard] =
  for count,protoCard in protoCards:
    let kind = parseCardKindFrom protoCard[0]
    case kind
    of Plan,Mission,Job,Deed: result.add buildPlanFrom(protoCard,kind)
    of Event: result.add buildEventFrom(protoCard)
    of News: result.add buildNewsFrom(protoCard)

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

proc buildBlues(path:string):tuple[blues:seq[BlueCard],imgs:seq[Image]] =
  result.blues = path.lines.toSeq.parseProtoCards.newBlueCards
  result.imgs = result.blues.mapIt it.paintBlue squares
  # for blue in result.blues:
  #   result.imgs.add blue.paintBlue squares

proc initCardSlots*(deck:var Deck,discardRect = discardPile,
  popUpRect = popUpCard,drawRect = drawPile) =
  deck.discardSlot.rect = discardRect
  deck.discardSlot.area = discardRect.toArea
  deck.popUpSlot.rect = popUpRect
  deck.popUpSlot.area = popUpRect.toArea
  deck.drawSlot.rect = drawRect
  deck.drawSlot.area = drawRect.toArea

proc newDeck*(path:string):Deck =
  let (blues,imgs) = buildBlues path
  result = Deck(fullDeck:blues)
  result.drawPile = result.fullDeck
  result.drawPile.shuffle
  result.initCardSlots
  addImage("blueback",blueBack)
  for (blue,img) in zipem(blues,imgs):
    addImage(blue.title,img)

proc resetDeck*(deck:var Deck) =
  deck.discardPile.setLen 0
  deck.drawPile = deck.fullDeck
  deck.drawPile.shuffle
  deck.lastDrawn = ""

proc shufflePiles*(deck:var Deck) =
  deck.drawPile.add deck.discardPile
  deck.discardPile.setLen 0
  deck.drawPile.shuffle

proc drawFrom*(hand:var seq[BlueCard],deck:var Deck) =
  if deck.drawPile.len == 0:
    deck.shufflePiles
  hand.add deck.drawPile.pop
  deck.lastDrawn = hand[^1].title

proc drawFromDiscardPile*(hand:var seq[BlueCard],deck:var Deck) =
  if deck.discardPile.len > 0:
    hand.add deck.discardPile.pop
    deck.lastDrawn = hand[^1].title

proc playTo*(hand:var seq[BlueCard],deck:var Deck,card:int) =
  deck.discardPile.add hand[card]
  hand.del card

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
  if show == Front and deck.lastDrawn.len > 0 and mouseOn deck.drawSlot.area:
    b.drawImage(deck.lastDrawn,deck.popUpSlot.rect)
    if (let cardNr = deck.fullDeck.mapIt(it.title).find(deck.lastDrawn); cardNr != -1):
      b.drawCardSquares deck.fullDeck[cardNr]
  if deck.discardPile.len > 0:
    b.drawImage(deck.discardPile[^1].title,deck.discardSlot.rect)
    if mouseOn deck.discardSlot.area:
      b.drawImage(deck.discardPile[^1].title,deck.popUpSlot.rect)
      b.drawCardSquares deck.discardPile[^1]
  for (card,slot) in cards.cardSlots:
    if show == Back:
      b.drawImage("blueback",slot.rect)
    else: 
      b.drawImage(card.title,slot.rect)
    if show == Front and mouseOn slot.area:
      b.drawImage(card.title,deck.popUpSlot.rect)
      b.drawCardSquares card

# proc paintCards*(b:var Boxy,deck:Deck,cards:seq[BlueCard],show:Reveal = Front) =
#   if deck.reveal == Front and deck.lastDrawn.len > 0 and mouseOn deck.drawSlot.area:
#     b.drawImage(deck.lastDrawn,deck.popUpSlot.rect)
#     if (let cardNr = deck.fullDeck.mapIt(it.title).find(deck.lastDrawn); cardNr != -1):
#       b.drawCardSquares deck.fullDeck[cardNr]
#   if deck.discardPile.len > 0:
#     b.drawImage(deck.discardPile[^1].title,deck.discardSlot.rect)
#     if mouseOn deck.discardSlot.area:
#       b.drawImage(deck.discardPile[^1].title,deck.popUpSlot.rect)
#       b.drawCardSquares deck.discardPile[^1]
#   for (card,slot) in (if deck.show == Hand: cards else: deck.discardPile).cardSlots:
#     if deck.reveal == Back and deck.show != Discard:
#       b.drawImage("blueback",slot.rect)
#     else: 
#       b.drawImage(card.title,slot.rect)
#     if (deck.reveal == Front or deck.show == Discard) and mouseOn slot.area:
#       b.drawImage(card.title,deck.popUpSlot.rect)
#       b.drawCardSquares card

randomize()
