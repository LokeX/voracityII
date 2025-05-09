from algorithm import sort,sorted,sortedByIt
from math import pow,sum
import sequtils
import sugar
import strutils
import random

const
  highwayVal* = 2000
  valBar = 15000
  posPercent = [1.0,0.3,0.3,0.3,0.3,0.3,0.3,0.15,0.14,0.12,0.10,0.08,0.05]

type
  Board = array[61,tuple[nr:int,name:string]]
  PlayerColor = enum Red,Green,Blue,Yellow,Black,White
  PlayerKind = enum Human,Computer,None
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
      bgPath*:string
  Deck* = object 
    fullDeck*,drawPile*,discardPile*:seq[BlueCard]
    lastDrawn*:string
  Pieces* = array[5,int]
  Player* = object
    color*:PlayerColor
    kind*:PlayerKind
    turnNr*:int
    pieces*:Pieces
    hand*:seq[BlueCard]
    cash*:int
    agro*:int
    skipped*:int
    update*:bool
  EvalBoard* = array[61,int]
  Hypothetic* = tuple
    board:array[61,int]
    pieces:array[5,int]
    allPlayersPieces:seq[int]
    cards:seq[BlueCard]
    cash:int
    skipped:int

const 
  defaultPlayerKinds* = @[Human,Computer,None,None,None,None]
  cashToWin* = 1_000_000
  piecePrice* = 10_000
  startCash* = 50_000
  
  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]
  bars* = [1,16,18,20,28,35,40,46,51,54]

proc newBoard*(path:string):Board =
  var count = 0
  result[0] = (0,"Removed")
  for name in lines path:
    inc count
    result[count] = (count,name)

proc newDeck*(path:string):Deck

var 
  blueDeck* = newDeck "blues.txt"
  board* = newBoard "board.txt"
  playerKinds*:array[6,PlayerKind]
  players*:seq[Player]

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

func newBlueCards(protoCards:seq[ProtoCard]):seq[BlueCard] =
  var card:BlueCard
  for protoCard in protoCards:
    card = BlueCard(title:protoCard[1],cardKind:parseCardKindFrom protoCard[0])
    if card.cardKind in [Event,News]:
      card.moveSquares = parseCardSquares(protoCard[2],['{','}'])
      card.bgPath = protoCard[3]
    else:
      card.squares = (
        parseCardSquares(protoCard[2],['{','}']),
        parseCardSquares(protoCard[2],['[',']']),
      )
      card.cash = protoCard[3].parseInt
    result.add card

proc newDeck*(path:string):Deck =
  result = Deck(fullDeck:path.lines.toSeq.parseProtoCards.newBlueCards)
  result.drawPile = result.fullDeck
  result.drawPile.shuffle

proc shufflePiles(deck:var Deck) =
  deck.drawPile.add deck.discardPile
  deck.discardPile.setLen 0
  deck.drawPile.shuffle

proc drawFrom*(hand:var seq[BlueCard],deck:var Deck) =
  if deck.drawPile.len == 0:
    deck.shufflePiles
  hand.add deck.drawPile.pop
  deck.lastDrawn = hand[^1].title

proc playTo(hand:var seq[BlueCard],deck:var Deck,card:int) =
  deck.discardPile.add hand[card]
  hand.del card

proc discardCards(player:var Player,deck:var Deck):seq[BlueCard] =
  while player.hand.len > 3:
    result.add player.hand[player.hand.high]
    player.hand.playTo deck,player.hand.high

func adjustToSquareNr(adjustSquare:int):int =
  if adjustSquare > 60: adjustSquare - 60 else: adjustSquare

func moveToSquare(fromSquare:int,die:int):int = 
  adjustToSquareNr fromSquare+die

func moveToSquares(fromSquare,die:int):seq[int] =
  if fromsquare != 0: result.add moveToSquare(fromSquare,die)
  else: result.add highways.mapIt moveToSquare(it,die)
  if fromSquare in highways or fromsquare == 0:      
    result.add gasStations.mapIt moveToSquare(it,die)
  result = result.filterIt(it != fromSquare).deduplicate

func countBars(hypothetical:Hypothetic):int = 
  hypothetical.pieces.countIt(it in bars)

func cardVal(hypothetical:Hypothetic): int =
  if (let val = 3 - hypothetical.cards.len; val > 0): 
    val*30000 else: 0

func barVal*(hypothetical:Hypothetic):int = 
  valBar-(3000*hypothetical.countBars)+hypothetical.cardVal
  
func piecesOn(hypothetical:Hypothetic,square:int):int =
  hypothetical.pieces.count(square)

func requiredPiecesOn*(hypothetical:Hypothetic,square:int):int =
  if hypothetical.cards.len == 0: 0 else:
    hypothetical.cards.mapIt(it.squares.required.count(square)).max

func freePiecesOn(hypothetical:Hypothetic,square:int):int =
  hypothetical.piecesOn(square) - hypothetical.requiredPiecesOn(square)

func covers(pieceSquare,coverSquare:int):bool =
  if pieceSquare == coverSquare:
    return true
  for die in 1..6:
    if coverSquare in moveToSquares(pieceSquare,die):
      return true

func covers(pieces,squares:openArray[int],count:int):int = 
  var 
    coverPieces:seq[int]
    idx:int
  for i,square in squares:  
    coverPieces = pieces.filterIt it.covers square
    if coverPieces.len > 0: idx = i; break
  if coverPieces.len == 0: 
    count
  elif idx == squares.high: 
    count+1
  else: 
    var maxCovers:int
    for coverPiece in coverPieces:
      maxCovers = max(maxCovers,pieces.filterIt(it != coverPiece)
        .covers(squares[idx+1..squares.high],count+1))
    maxCovers

func covers(pieces,squares:openArray[int]):int = 
  pieces.covers(squares,0)

# None recursive alternative to covers - DO NOT REMOVE

# func covers(pieces,squares:openArray[int]):int = 
#   var 
#     covers,nextCovers:seq[tuple[pieces,squares,usedPieces:seq[int],idx:int]]
#     count:int
#     usedPieces:seq[int]
  
#   template computeNextCovers(nextPieces,nextSquares:untyped) = 
#     for i in 0..nextSquares.high:  
#       usedPieces = nextPieces.filterIt it.covers nextSquares[i]
#       if usedPieces.len > 0:
#         nextCovers.add (@nextPieces,@nextSquares,usedPieces,i)
#         break

#   covers.setLen 1
#   computeNextCovers(pieces,squares)
#   while covers.len > 0:
#     covers = nextCovers.filterIt it.usedPieces.len > 0
#     if covers.len > 0: 
#       inc count
#       covers = covers.filterIt it.idx < it.squares.high
#       nextCovers.setLen 0
#       for cover in covers:
#         for usedPiece in cover.usedPieces:
#           computeNextCovers(
#             cover.pieces.filterIt(it != usedPiece),
#             cover.squares[cover.idx+1..cover.squares.high]
#           )
#   count

func coversOneIn(pieces,squares:openArray[int]):bool =  
  for piece in pieces:
    for square in squares:
      if piece.covers square:
        return true

func covers*(pieces:openArray[int],card:BlueCard):bool =
  let nrOfCovers = pieces.covers card.squares.required
  (card.squares.required.len == 0 or card.squares.required.len == nrOfCovers) and
  (card.squares.oneInMany.len == 0 or pieces.coversOneIn(card.squares.oneInMany))

func rewardValue(hypothetical:Hypothetic,card:BlueCard):int =
  let 
    cashNeeded = cashToWin-card.cash
  if cashNeeded < card.cash: 
    cashNeeded #div lockedPosModifier
  else: 
    card.cash #div lockedPosModifier

func oneInMoreBonus(hypothetical:Hypothetic,blueCard:BlueCard,square:int):int =
  let 
    reward = hypothetical.rewardValue blueCard
    requiredSquare = blueCard.squares.required[0]
  if square == requiredSquare:
    if blueCard.squares.oneInMany.anyIt hypothetical.piecesOn(it) > 0: 
      result = reward
    else: result = 
      case hypothetical.piecesOn(requiredSquare)
      of 0:reward div 2
      of 1:reward
      else:0
  elif hypothetical.piecesOn(requiredSquare) > 0: result = reward
 
func blueVals(hypothetical:Hypothetic,squares:openArray[int]):array[12,int] =
  for card in hypothetical.cards:
    if hypothetical.pieces.covers card:
      if card.squares.required.len > 1:
        let
          requiredSquares = card.squares.required.deduplicate
          piecesOn = requiredSquares.mapIt hypothetical.pieces.count it
          requiredPiecesOn = requiredSquares.mapIt card.squares.required.count it
          piecesVsRequired = 
            toSeq(0..requiredSquares.high)
            .mapIt piecesOn[it] - requiredPiecesOn[it]
          bonus = 
            (hypothetical.rewardValue(card) div card.squares.required.len)*
            (toSeq(0..requiredSquares.high)
            .mapIt(min(piecesOn[it],requiredPiecesOn[it])).sum+1)
        for si,square in squares:
          if (let squareIndex = requiredSquares.find square; squareIndex > -1):
            if piecesVsRequired[squareIndex] < 1:
              result[si] += bonus
      else:
        for si,square in squares:
          if card.squares.oneInMany.len == 0 and square == card.squares.required[0]:
            result[si] += hypothetical.rewardValue(card)*2 #+(hypothetical.distract*2)
          elif (square == card.squares.required[0] or square in card.squares.oneInMany):
            if card.squares.oneInMany.len > 0:
              result[si] += hypothetical.oneInMoreBonus(card,square)

func posPercentages(hypothetical:Hypothetic,squares:openArray[int]):array[12,float] =
  var freePieces:int
  for i,square in squares:
    let freePiecesOnSquare = hypothetical.freePiecesOn square
    if freePiecesOnSquare > 0:
      freePieces += freePiecesOnSquare
    if freePieces == 0:
      result[i] = posPercent[i]
    else:
      result[i] = posPercent[i].pow freePieces.toFloat

func squareNrs(square:int):array[12,int] =
  var i:int
  for idx in square..<square+posPercent.high:
    result[i] = adjustToSquareNr idx
    inc i

func evalSquare(hypothetical:Hypothetic,square:int):int =
  var squares = square.squareNrs
  let 
    posPercent = hypothetical.posPercentages squares
    blueVals = hypothetical.blueVals squares
  for idx in 0..squares.high:
    squares[idx] = (
      posPercent[idx]*
      (hypothetical.board[squares[idx]]+blueVals[idx]).toFloat
    ).toInt
  squares.sum

func evalPos*(hypothetical:Hypothetic):int =
  var 
    bestHighway,bestGasstation,bestOfBoth = -1
    highwayEvals,evals:seq[int]
  let squares = hypothetical.pieces#.deduplicate
  for square in squares:
    if square == 0:
      if bestHighway == -1:
        highwayEvals = highways.mapIt hypothetical.evalSquare it
        bestHighway = max highwayEvals
      if bestGasstation == -1:
        bestGasstation = max gasStations.mapIt hypothetical.evalSquare it
      if bestOfBoth == -1:
        bestOfBoth = max(bestGasstation,bestHighway)
      evals.add bestOfBoth
  for square in squares:
    if (let idx = highways.find square; idx > -1):
      if bestGasstation == -1:
        bestGasstation = max gasStations.mapIt hypothetical.evalSquare it      
      let thisSquare = 
        if highwayEvals.len > 0: highwayEvals[idx]
        else: hypothetical.evalSquare square
      evals.add max(thisSquare,bestGasstation)
    elif square != 0: evals.add hypothetical.evalSquare square
  evals.sum

func evalBlue(hypothetical:Hypothetic,card:BlueCard):int =
  evalPos (
    hypothetical.board,
    hypothetical.pieces,
    hypothetical.allPlayersPieces,
    @[card],
    hypothetical.cash,
    hypothetical.skipped
  )

proc evalBlues*(hypothetical:Hypothetic):seq[BlueCard] =
  let evals = hypothetical.cards.mapIt hypothetical.evalBlue it
  result = hypothetical.cards
  for i,_ in evals:
    # result.add card
    result[i].eval = evals[i] #hypothetical.evalBlue(card)
  result.sort (a,b) => b.eval - a.eval

func allPlayersPieces(players:seq[Player]):seq[int] =
  for player in players:
    result.add player.pieces

func baseEvalBoard(hypothetical:Hypothetic):EvalBoard =
  result[0] = 4000
  for highway in highways: 
    result[highway] = highwayVal
  for bar in bars: 
    result[bar] = barVal(hypothetical)
    if hypothetical.piecesOn(bar) == 1: result[bar] *= 2

proc boardInit(player:Player):EvalBoard =
  baseEvalBoard (
    result,
    player.pieces,
    @[],
    player.hand,
    player.cash,
    0
  )
 
proc hypotheticalInit*(player:Player):Hypothetic = (
  player.boardInit,
  player.pieces,
  players.allPlayersPieces,
  player.hand,
  player.cash,
  player.skipped
)

proc newDefaultPlayers*:seq[Player] =
  for i,kind in playerKinds:
    result.add Player(
      kind:kind,
      color:PlayerColor(i),
      pieces:highways
    )

proc initPlayers* =
  players = newDefaultPlayers()

#-------------------------------------------------------------------
# Test run from here
#-------------------------------------------------------------------

initPlayers()
var
  player = players[0]
  hypo = player.hypotheticalInit
  count:int

while true:
  inc count
  echo count

  #------------------------------------
  # Draw some cards to evaluate
  #------------------------------------
  for _ in 1..6:
    player.hand.drawFrom blueDeck
    if player.hand[^1].cardKind in [News,Event]:  # Drop cards that cannot be evaluated
      player.hand.playTo(blueDeck,player.hand.high)
  player.hand.playTo(blueDeck,0) # Ensure some variation

  #----------------------------------------------------
  # Evaluate the cards and reproduce our problem
  #----------------------------------------------------
  hypo = player.hypotheticalInit
  discard hypo.evalBlues # Without this call the program maintains steady state

  #------------------------------------------------------------------
  # Reduce the player hand to 3 cards - or we will run out
  #------------------------------------------------------------------
  let discs = player.discardCards blueDeck

  echo "discard:"
  echo discs.mapIt(it.title).join "\n"

  # echo "hand:"
  # echo player.hand.mapIt(it.title).join "\n"
      
