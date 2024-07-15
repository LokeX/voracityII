import game
import board
import deck
import sequtils
from math import pow,sum
from algorithm import sort,sortedByIt
import sugar
import taskpools,cpuinfo
from misc import flatMap,reduce

const
  highwayVal* = 2000
  valBar = 5000
  posPercent = [1.0,0.3,0.3,0.3,0.3,0.3,0.3,0.15,0.14,0.12,0.10,0.08,0.05]

type
  Cover = tuple[pieceNr,square:int]
  Move* = tuple[pieceNr,die,fromSquare,toSquare,eval:int]
  EvalBoard* = array[61,int]
  Hypothetic* = tuple
    board:array[61,int]
    pieces:array[5,int]
    cards:seq[BlueCard]
    cash:int

template taskPoolsAs(pool,codeBlock:untyped) =
  var pool = Taskpool.new(num_threads = countProcessors())
  codeBlock
  pool.syncAll
  pool.shutdown

func countBars*(hypothetical:Hypothetic): int = hypothetical.pieces.countIt(it in bars)

func cardVal(hypothetical:Hypothetic): int =
  if (let val = 3 - hypothetical.cards.len; val > 0): val*10000 else: 0

func barVal*(hypothetical:Hypothetic): int = 
  let 
    barCount = hypothetical.countBars
  valBar-(500*barCount)+cardVal(hypothetical)

func piecesOn(hypothetical:Hypothetic,square:int): int =
  hypothetical.pieces.count(square)

func requiredPiecesOn*(hypothetical:Hypothetic,square:int): int =
  if hypothetical.cards.len == 0: 0 else:
    hypothetical.cards.mapIt(it.squares.required.count(square)).max

func freePiecesOn(hypothetical:Hypothetic,square:int): int =
  hypothetical.piecesOn(square) - hypothetical.requiredPiecesOn(square)

func covers(pieceSquare,coverSquare:int): bool =
  for die in 1..6:
    if coverSquare in moveToSquares(pieceSquare,die):
      return true

func isCovered(hypothetical:Hypothetic, square:int):bool =
  hypothetical.pieces.anyIt(it.covers(square))

func blueCovers(hypothetical:Hypothetic,card:BlueCard):seq[Cover] =
  let requiredDistinct = card.squares.required.deduplicate
  for pieceNr,pieceSquare in hypothetical.pieces:
    if pieceSquare in requiredDistinct:
      result.add (pieceNr,pieceSquare)
    else:
      for blueSquare in requiredDistinct:
        if pieceSquare.covers blueSquare:
          result.add (pieceNr,blueSquare)

func enoughPiecesIn(card:BlueCard,covers:seq[Cover]):bool =
  let availablePieces = covers.mapIt(it.pieceNr).deduplicate
  availablePieces.len >= card.squares.required.len

func requiredSquaresIn(card:BlueCard,covers:seq[Cover]):bool =
  let 
    required = card.squares.required
    requiredDistinct = required.deduplicate
    requiredCounts = requiredDistinct.mapIt required.count it
    coverSquares = covers.mapIt it.square
    coversCount = requiredDistinct.mapIt coverSquares.count it
  toSeq(0..requiredCounts.high).allIt coversCount[it] >= requiredCounts[it]

func isCovered(hypothetical:Hypothetic,card:BlueCard):bool =
  let covers = hypothetical.blueCovers(card)
  card.requiredSquaresIn(covers) and card.enoughPiecesIn(covers)

func oneInMoreBonus(hypothetical:Hypothetic,card:BlueCard,square:int):int =
  let 
    requiredSquare = card.squares.required[0]
    piecesOnRequiredSquare = hypothetical.piecesOn(requiredSquare) > 0
  if square == requiredSquare:
    if piecesOnRequiredSquare:
      result = card.cash
    elif hypothetical.isCovered(square) and card.squares.oneInMany.anyIt hypothetical.isCovered it:
      result = card.cash div 2
  elif piecesOnRequiredSquare and square in card.squares.oneInMany:
    result = card.cash

func oneRequiredBonus(hypothetical:Hypothetic,card:BlueCard,square:int): int =
  if card.squares.oneInMany.len > 0:
    hypothetical.oneInMoreBonus(card,square)
  elif hypothetical.isCovered square: 
    card.cash
  else: 0

func blueBonus(hypothetical:Hypothetic,card:BlueCard,square:int):int =
  let
    requiredSquares = card.squares.required.deduplicate
    squareIndex = requiredSquares.find square
  if squareIndex >= 0 or square in card.squares.oneInMany:
    let nrOfPiecesRequired = card.squares.required.len
    if nrOfPiecesRequired == 1: 
      result = hypothetical.oneRequiredBonus(card,square)
    elif squareIndex < 0 and square in card.squares.oneInMany:
        result = card.cash
    else:
      let
        piecesOn = requiredSquares.mapIt hypothetical.pieces.count it
        requiredPiecesOn = requiredSquares.mapIt card.squares.required.count it
        freePieces = piecesOn[squareIndex] - requiredPiecesOn[squareIndex]
        hasCover = hypothetical.isCovered card
      if freePieces < 1 and hasCover:
        var nrOfPieces = 1
        for square in 0..requiredSquares.high:
          nrOfPieces += min(piecesOn[square],requiredPiecesOn[square])
        result = (card.cash div nrOfPiecesRequired)*nrOfPieces

func blueVals*(hypothetical:Hypothetic,squares:seq[int]):seq[int] =
  result.setLen(squares.len)
  if hypothetical.cards.len > 0:
    for i,square in squares:
      for card in hypothetical.cards:
        result[i] += hypothetical.blueBonus(card,square)

func posPercentages(hypothetical:Hypothetic,squares:seq[int]):seq[float] =
  var freePieces:int
  for i,square in squares:
    let freePiecesOnSquare = hypothetical.freePiecesOn square
    if freePiecesOnSquare > 0:
      freePieces += freePiecesOnSquare
    if freePieces == 0:
      result.add posPercent[i]
    else:
      result.add posPercent[i].pow freePieces.toFloat

func evalSquare(hypothetical:Hypothetic,square:int):int =
  let 
    squares = toSeq(square..square+posPercent.len-1).mapIt adjustToSquareNr it
    blueSquareValues = hypothetical.blueVals squares
    baseSquareVals = squares.mapIt(hypothetical.board[it].toFloat)
    squarePercent = hypothetical.posPercentages squares
  toSeq(0..posPercent.len-1)
  .mapIt(((baseSquareVals[it]+blueSquareValues[it].toFloat)*squarePercent[it]).toInt)
  .sum

func evalPos*(hypothetical:Hypothetic):int = 
  hypothetical.pieces.mapIt(hypothetical.evalSquare it).sum

func baseEvalBoard*(hypothetical:Hypothetic): EvalBoard =
  result[0] = 4000
  for highway in highways: 
    result[highway] = highwayVal
  for bar in bars: 
    result[bar] = barVal(hypothetical)
    if hypothetical.piecesOn(bar) == 1: result[bar] *= 2

func evalBlue(hypothetical:Hypothetic,card:BlueCard): int =
  evalPos (
    baseEvalBoard(hypothetical),
    hypothetical.pieces,
    @[card],
    hypothetical.cash
  )

func evalBlues*(hypothetical:Hypothetic):seq[BlueCard] =
  for card in hypothetical.cards:
    result.add card
    result[^1].eval = hypothetical.evalBlue card
  result.sort (a,b) => b.eval - a.eval

proc evalBluesThreaded*(hypothetical:Hypothetic):seq[BlueCard] =
  taskPoolsAs tp:
    let evals = hypothetical.cards.map(it => tp.spawn hypothetical.evalBlue it)
    for i,card in hypothetical.cards:
      result.add card
      result[^1].eval = sync evals[i] #hypothetical.evalBlue(card)
    result.sort (a,b) => b.eval - a.eval

func friendlyFireBest(hypothetical:Hypothetic,move:Move):bool =
  var hypoMove = hypothetical
  hypoMove.pieces[move.pieceNr] = move.toSquare
  let eval = hypoMove.evalPos
  hypoMove.pieces[move.pieceNr] = 0
  let killEval = hypoMove.evalPos
  killEval > eval
  
func friendlyFireAdviced*(hypothetical:Hypothetic,move:Move):bool =
  move.fromSquare != 0 and
  move.toSquare notIn highways and
  move.toSquare notIn gasStations and
  hypothetical.piecesOn(move.toSquare) == 1 and 
  hypothetical.requiredPiecesOn(move.toSquare) < 2 and
  hypothetical.friendlyFireBest(move)

func threeBest(cards:seq[BlueCard]):seq[BlueCard] =
  if cards.len > 3: cards[0..2] else: cards

func evalMove*(hypothetical:Hypothetic,pieceNr,toSquare:int):int =
  var pieces = hypothetical.pieces
  if hypothetical.friendlyFireAdviced (pieceNr,0,pieces[pieceNr],toSquare,0):
    pieces[pieceNr] = 0 else: pieces[pieceNr] = toSquare
  (hypothetical.board,pieces,hypothetical.cards.threeBest,hypothetical.cash).evalPos

func bestMoveFrom(hypothetical:Hypothetic,generic:Move):Move =
  let
    squares = moveToSquares(generic.fromSquare,generic.die)
    evals = squares.mapIt(hypothetical.evalMove(generic.pieceNr,it))
    bestEval = evals.maxIndex
    bestSquare = squares[bestEval]
    eval = evals[bestEval]
  (generic.pieceNr,generic.die,generic.fromSquare,bestSquare,eval)

func movesSeededWith(hypothetical:Hypothetic,dice:openArray[int]):seq[Move] =
  for die in dice.deduplicate:
    for pieceNr,fromSquare in hypothetical.pieces:
      result.add (pieceNr,die,fromSquare,0,0)

func resolveSeedMoves(hypothetical:Hypothetic,moves:seq[Move]):seq[Move] =
  for move in moves:
    if move.fromSquare != 0 or hypothetical.cash >= piecePrice:
      for toSquare in moveToSquares(move.fromSquare,move.die):
        result.add (move.pieceNr,move.die,move.fromSquare,toSquare,0)

func movesResolvedWith(hypothetical:Hypothetic,dice:openArray[int]):seq[Move] =
  hypothetical.resolveSeedMoves(hypothetical.movesSeededWith dice)

func player(hypothetical:Hypothetic,move:Move):Player =
  var pieces = hypothetical.pieces
  pieces[move.pieceNr] = move.toSquare
  Player(
    pieces:pieces,
    hand:hypothetical.cards
  )

func winningMove*(hypothetical:Hypothetic,dice:openArray[int]):Move =
  for move in hypothetical.movesResolvedWith dice:
    let 
      cashReward = hypothetical.player(move).plans.cashable.mapIt(it.cash).sum
      cashTotal = cashReward+hypothetical.cash-(
        if move.fromSquare == 0: piecePrice else: 0
      )
    if cashTotal >= cashToWin: 
      return move
  result.pieceNr = -1

proc move*(hypothetical:Hypothetic,dice:openArray[int]):Move = 
  taskPoolsAs tp:
    result = hypothetical.movesSeededWith(dice)
      .map(genericMove => tp.spawn hypothetical.bestMoveFrom genericMove)
      .map(bestMove => sync bestMove)
      .reduce (a,b) => (if a.eval >= b.eval: a else: b)

proc diceMoves(hypothetical:Hypothetic):seq[Move] =
  taskPoolsAs tp:
    result = toSeq(1..6)
      .map(die => hypothetical.movesSeededWith([die,die]))
      .flatMap
      .map(genericMove => tp.spawn hypothetical.bestMoveFrom genericMove)
      .map(move => sync move)

proc bestDiceMoves*(hypothetical:Hypothetic):seq[Move] =
  let moves = hypothetical.diceMoves
  for die in 1..6:
    let dieMoves = moves.filterIt it.die == die
    result.add dieMoves[dieMoves.mapIt(it.eval).maxIndex]
  result.sortedByIt it.eval

func hypotheticalInit*(player:Player):Hypothetic =
  var board:EvalBoard
  (baseEvalBoard(
    (board,
    player.pieces,
    player.hand,
    player.cash)
  ),
  player.pieces,
  player.hand,
  player.cash)

proc sortBlues*(player:Player):seq[BlueCard] =
  player.hypotheticalInit.evalBluesThreaded

func pieceNrsOnBars(player:Player):seq[int] =
  for nr,square in player.pieces.deduplicate:
    if square in bars: result.add nr

func eventMovesEval*(player:Player,event:BlueCard):seq[Move] =
  let hypothetical = player.hypotheticalInit
  for pieceNr in player.pieceNrsOnBars:
    for toSquare in event.moveSquares:
      result.add (
        pieceNr,
        -1,
        hypothetical.pieces[pieceNr],
        toSquare,
        hypothetical.evalMove(pieceNr,toSquare)
      )
  result.sort (a,b) => b.eval-a.eval

