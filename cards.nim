import graphics
import win
import batch
import game
import play
import board
import reports
import sequtils
import strutils
import misc

type
  Reveal* = enum Front,Back
  CardSlot = tuple[area:Area,rect:Rect]
  Pinned* = enum None,Discard,AllDeck

func buildCardSlots(r:Rect,cardsInRow:range[2..8]):seq[CardSlot] =
  const
    slotRanges:array[2..8,HSlice[int,int]] = 
      [0..7,0..17,0..31,0..49,0..71,0..97,0..128]
    padding:array[2..8,float] = [20,10,5,3,2,1,1]
  let
    sizeFactor = 1.0/cardsInRow.toFloat
    rect = Rect(x:r.x,y:r.y,w:r.w*sizeFactor,h:r.h*sizeFactor)
  var slot:Rect
  for i in slotRanges[cardsInRow]:
    slot = Rect(w: rect.w, h: rect.h,
      x: rect.x+((rect.w+padding[cardsInRow])*(i mod cardsInRow).toFloat),
      y: rect.y+((rect.h+padding[cardsInRow])*(i div cardsInRow).toFloat)
    )
    result.add (slot.toArea,slot)

func buildCardSlots(initPosDim:Rect):seq[seq[CardSlot]] =
  for cardsInRow in 2..8: result.add buildCardSlots(initPosDim,cardsInRow)

const
  (cardWidth*, cardHeight*) = (255.0,410.0)
  popUpCardRect = Rect(x:500,y:290,w:cardWidth,h:cardHeight)
  drawPileRect = Rect(x:855,y:495,w:110,h:180)
  discardPileRect = Rect(x:1025,y:495,w:cardWidth*0.441,h:cardHeight*0.441)
  drawPileArea* = drawPileRect.toArea
  discardPileArea* = discardPileRect.toArea
  slotCapacities = [8,18,32,50,72,98,128]
  initPosDim = Rect(x:1580.0,y:50.0,w:cardWidth,h:cardHeight)
  cardSlotsX = initPosDim.buildCardSlots

let
  headerInit = BatchInit(
    kind:TextBatch,
    name:"header",
    pos:(1560,5),
    entries: @[""],
    font:("fonts\\IBMPlexSansCondensed-SemiBold.ttf",18.0,color(1,1,1)),
    hAlign:CenterAlign,
    fixedBounds:(300,25),
    bgColor:color(0,0,0),
    opacity:25,
    border:(5,10,color(1,1,1)),
  )
  footerInit = BatchInit(
    kind:TextBatch,
    name:"footer",
    pos:(1560,930),
    entries: @[""],
    font:("fonts\\IBMPlexSansCondensed-SemiBold.ttf",18.0,color(1,1,1)),
    hAlign:CenterAlign,
    fixedBounds:(300,25),
    bgColor:color(0,0,0),
    opacity:25,
    border:(5,10,color(1,1,1)),
  )

  deedbg = readImage "pics\\deedbg.jpg"
  planbg = readImage "pics\\bronze_plates.jpg"
  jobbg = readImage "pics\\silverback.jpg"
  missionbg = readImage "pics\\mission.jpg"
  blueBack = readImage "pics\\blueback.jpg"

  roboto = readTypeface "fonts\\Roboto-Regular_1.ttf"
  point = readTypeface "fonts\\StintUltraCondensed-Regular.ttf"
  ibmplex = readTypeFace "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  asap = readTypeface "fonts\\AsapCondensed-Bold.ttf"

  whiteAsap16 = setNewFont(asap,size = 20,color = color(1,1,0))
  blackAsap16 = setNewFont(asap,size = 20,color = color(0,0,0))


proc paintUndrawnBlues:Image =
  var ctx = newImage(110,180).newContext
  ctx.font = fjallaOneRegular
  ctx.fontSize = 160
  ctx.fillStyle = color(1,1,0)
  let width = ctx.measureText($turn.undrawnBlues).width
  ctx.fillText($turn.undrawnBlues,(110-width)/2,160)
  ctx.image

var
  cardsHeader = newBatch headerInit
  cardsFooter = newBatch footerInit
  altPressed*:bool
  pinnedCards*:Pinned
  reveal*:bool
  nrOfUndrawnBluesPainter* = DynamicImage[void](
    name: "undrawBlues",
    rect: Rect(x:855,y:495),
    updateImage: paintUndrawnBlues,
    update: true
  )

proc undrawnPainterUpdate* =
  nrOfUndrawnBluesPainter.update = true

func iconPath(square:Square):string =
  let squareName = square.name.toLower
  "pics\\board_icons\\"&(
    case squareName:
    of "villa", "condo", "slum": "livingspaces"
    of "bank", "shop", "bar", "highway": squareName
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
    ctx = newContext newImage(
      icon.width+shadowSize.toInt,
      icon.height+shadowSize.toInt
    )
  ctx.fillStyle = color(0,0,0,150)
  ctx.fillrect(
    Rect(
      x:shadowSize,
      y:shadowSize,
      w:icon.width.toFloat,
      h:icon.height.toFloat
    )
  )
  ctx.drawImage(icon,0,0)
  result = ctx.image

func required(plan:BlueCard,squares:BoardSquares):seq[string] =
  let
    planSquares = plan.squares.required.deduplicate
    squareAdresses = planSquares.mapIt squares[it].name&" Nr. " & $squares[it].nr
    nrOfPieces = planSquares.mapit plan.squares.required.count it
    piecesTxt = nrOfPieces.mapIt(
      if it > 1: " pieces on the " else: " piece on the "
    )
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
  result.add "All pieces on: " &
    squares[blue.moveSquares[0]].name&" Nr."&($squares[blue.moveSquares[0]].nr)
  if blue.moveSquares[1] == 0:
    result.add "Are removed from the board"
  else: result.add "Moves to: " &
    squares[blue.moveSquares[1]].name&" Nr."&($squares[blue.moveSquares[1]].nr)

proc typesetBoxedText(blue:BlueCard,squares:BoardSquares):(Arrangement,float32) =
  var txt:seq[string]
  case blue.cardKind
  of Plan,Mission,Job,Deed:
    txt = blue.required squares
    txt.insert "Requires: ", 0
    txt.add "Rewards:\n" & ($blue.cash).insertSep('.')&" in cash"
  of Event: txt.add blue.eventText squares
  of News: txt.add blue.newsText squares
  let
    font = setNewFont(roboto,13.0,color(0,0,0))
    boxText = font.typeset txt.join "\n"
  (boxText, boxText.layoutBounds.y)

proc paintTextBoxOn(card:BlueCard,img:var Image,squares:BoardSquares) =
  let
    (textPadX,textPadY,borderSize,shadowSize,angle) = (15.0,15.0,0.0,3.0,0.0)
    (boxText, textHeight) = card.typesetBoxedText squares
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
  var img = 
    case card.cardKind:
    of Deed:deedbg
    of Plan:planbg
    of Mission:missionbg
    of Job:jobbg
    of Event,News:readImage(card.bgPath)
  result.draw(img,translate vec2(borderSize, borderSize))

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
  card.paintBackgroundImage(ctx, borderSize)

proc paintCardKindOn(card:BlueCard,img:var Image,borderSize:float) =
  let
    kindFont = setNewFont(ibmplex,16.0,color(0,0,0))
    cardKind = kindFont.typeset $card.cardKind
  img.fillText(cardKind,translate vec2(10+borderSize,60))

proc paintIconsOn(card:BlueCard,img:var Image,squares:BoardSquares) =
  var cardSquares: seq[int]
  case card.cardKind
  of Mission,Plan,Job,Deed:
    cardSquares = card.squares.required
    if card.squares.oneInMany.len > 0:
      cardSquares.add card.squares.oneInMany[0]
  of Event,News: cardSquares.add card.moveSquares
  let x_offset = if cardSquares.len == 1: 100.0 else: 55.0
  var (x,y) = (x_offset, 120.0)
  for idx,squareNr in cardSquares:
    let icon = squares[squareNr].paintIcon
    img.draw(icon,translate vec2(x,y))
    # x += icon.width.toFloat*1.5
    if idx == 1:
      x = x_offset+(if cardSquares.len == 3: 45 else: 0)
      y += icon.height.toFloat*1.5
    else: x += icon.width.toFloat*1.5
 
proc paintBlue(card:BlueCard,squares:BoardSquares):Image =
  let borderSize = 1.0
  result = card.paintBackground borderSize
  card.paintTitleOn(result,borderSize)
  card.paintCardKindOn(result,borderSize)
  if (card.cardKind notin [Event,News]) or card.moveSquares[^1] notin [0, -1]:
    card.paintIconsOn(result,squares)
  card.paintTextBoxOn(result,squares)

func nrOfslots(nrOfCards: int):int =
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

proc mouseOnCardSlot*(player:Player):int =
  for (_,slot) in player.hand.cardSlots:
    if mouseOn slot.area: return
    inc result
  result = -1

proc paintCardSquares*(blue:BlueCard):Image =
  result = newImage(boardImg.width,boardImg.height)
  result.paintSquares(blue.squares.required.deduplicate,color(0,0,0,100))
  if blue.squares.oneInMany.len > 0:
    result.paintSquares(blue.squares.oneInMany,color(100,0,0,100))

var
  cardSquaresPainter* = DynamicImage[BlueCard](
    name:"cardSquares",
    rect:Rect(x:bx,y:by),
    updateImage:paintCardSquares,
    update:true
  )

proc drawCardSquares(b:var Boxy,blue:BlueCard) =
  if blue.cardKind in [Mission,Plan,Job,Deed]:
    if cardSquaresPainter.context.title != blue.title:
      cardSquaresPainter.update = true
      cardSquaresPainter.context = blue
    b.drawDynamicImage cardSquaresPainter

func lastDrawnCardNr(deck:Deck):int =
  for i,card in deck.fullDeck:
    if card.title == deck.lastDrawn: 
      return i
  -1

var
  zoomImg,rotateImg:proc:float32
  popUpCardName,lastName:string
  center = popUpCardRect.rectCenter()

proc paintCards*(b:var Boxy,deck:Deck,cards:seq[BlueCard],show:Reveal = Front) =
  popUpCardName.setLen 0
  if show == Front and deck.lastDrawn.len > 0 and mouseOn drawPileArea:
    popUpCardName = deck.lastDrawn
    if (let cardNr = deck.lastDrawnCardNr; cardNr != -1):
      b.drawCardSquares deck.fullDeck[cardNr]
  if deck.discardPile.len > 0:
    b.drawImage(deck.discardPile[^1].title, discardPileRect)
    if mouseOn discardPileArea:
      popUpCardName = deck.discardPile[^1].title
      b.drawCardSquares deck.discardPile[^1]
  for (card,slot) in cards.cardSlots:
    if show == Back:
      b.drawImage("blueback",slot.rect)
    else:
      b.drawImage(card.title,slot.rect)
    if show == Front and mouseOn slot.area:
      popUpCardName = card.title
      b.drawCardSquares card
  if popUpCardName.len > 0:
    if lastName != popUpCardName:
      zoomImg = zoomImage(frames = 20)
      rotateImg = rotateImage(frames = 20)
    b.drawImage(popUpCardName,center,rotateImg(),scale = zoomImg())
  lastName = popUpCardName

proc cashedCards:seq[BlueCard] =
  result.add selectedBatchColor.reports.mapIt(it.cards.cashed).flatMap
  if selectedBatchColor == turnPlayer.color:
    result.add turnReport.cards.cashed

template drawSelectedPlayersHand:untyped =
  altPressed and pinnedBatchNr == -1 and turnPlayer.cash >= cashToWin

proc paintCardsHeader(b:var Boxy,color:PlayerColor,header:string) =
  if header != cardsHeader.getSpanText 0:
    cardsHeader.commands:
      cardsHeader.border.color = playerColors[color]
    cardsHeader.setSpanText header,0
    cardsHeader.update = true
  b.drawDynamicImage cardsHeader

proc showCards*(b:var Boxy) =
  var
    cards:seq[BlueCard]
    show:Reveal = Front
    header = ""
    color = Black
  if turn.nr == 0:
    if pinnedCards == AllDeck or mouseOn drawPileArea:
      cards = blueDeck.fullDeck
      header = "Full deck"
  elif pinnedCards == Discard or mouseOn discardPileArea:
    cards = blueDeck.discardPile
    header = "Discard pile"
  elif batchSelected and selectedBatchColor.reports.len > 0:
    if drawSelectedPlayersHand:
      cards = players[mouseOnBatchPlayerNr].hand
      color = players[mouseOnBatchPlayerNr].color
      header = $color&" player's hand"
    else: 
      cards = cashedCards()
      color = players[max(mouseOnBatchPlayerNr,pinnedBatchNr)].color
      header = $color&" player's cashed cards"
  else: 
    cards = turnPlayer.hand
    show = if turnPlayer.kind == Human or reveal: Front else: Back
    color = turnPlayer.color
    header = $color&" player's hand"
  b.paintCards(blueDeck,cards,show)
  if header.len > 0:
    b.paintCardsHeader(color,header)

template showFooter:untyped =
  mouseOnBatchPlayerNr != -1 or 
  pinnedBatchNr != -1 or 
  pinnedCards == Discard or 
  mouseOn(discardPileArea) or
  pinnedCards == AllDeck or
  (mouseOn(drawPileArea) and turn.nr == 0)

template clickToPin:untyped =
  (mouseOnBatchPlayerNr != -1 or 
  mouseOn(discardPileArea) or 
  mouseOn(drawPileArea)) and 
  (pinnedBatchNr == -1 and pinnedCards == None)

proc drawCardsFooter*(b:var Boxy) =
  if showFooter:
    let txt = if clickToPin: "Click to pin" else: "Click to unpin"
    if txt != cardsFooter.getSpanText 0:
      let (fColor,bColor) = if txt.endsWith "unpin": 
        (contrastColors[Red],playerColors[Red])
      else: (contrastColors[Green],playerColors[Green]) 
      cardsFooter.commands:
        cardsFooter.text.bgColor = bColor
        cardsFooter.border.color = bColor
        cardsFooter.text.spans[0].font.paint = fColor
      cardsFooter.setSpanText txt,0
      cardsFooter.update = true
    b.drawDynamicImage cardsFooter

template initCards* =
  addImage("blueback",blueBack)
  for idx,img in blueDeck.fullDeck.mapIt it.paintBlue squares:
    addImage(blueDeck.fullDeck[idx].title,img)

