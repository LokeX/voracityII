from algorithm import sort,sorted,sortedByIt
from math import pow,sum
from strutils import join
import game
import sequtils
import sugar
import taskpools
import misc except reversed

const
  highwayVal* = 2000
  valBar = 15000
  posPercent = [1.0,0.3,0.3,0.3,0.3,0.3,0.3,0.15,0.14,0.12,0.10,0.08,0.05]

type
  EvalBoard* = array[61,int]
  Hypothetic* = tuple
    board:array[61,int]
    pieces:array[5,int]
    allPlayersPieces:seq[int]
    cards:seq[BlueCard]
    cash:int
    skipped:int

func countBars*(hypothetical:Hypothetic):int = 
  hypothetical.pieces.countIt(it in bars)

func covers*(pieces:openArray[int],card:BlueCard):bool
func cardVal(hypothetical:Hypothetic): int =
  if (let val = 3 - hypothetical.cards.filterIt(hypothetical.pieces.covers it).len; val > 0): 
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
  pieceSquare == coverSquare or
  toSeq(1..6).anyIt coverSquare in moveToSquares(pieceSquare,it)

func covers(pieces,squares:openArray[int]):int =
  let coverPieces = pieces.filterIt it.covers squares[0]
  if coverPieces.len == 0:
    5-pieces.len
  elif squares.len == 1:
    6-pieces.len
  else:
    coverPieces
    .mapIt(pieces.exclude(it).covers squares[1..squares.high])
    .max

func coversOneIn(pieces,squares:openArray[int]):bool =
  for piece in pieces:
    for square in squares:
      if piece.covers square:
        return true

# template coveredBy(squares,pieces:untyped):untyped =
#   pieces.covers(squares) == squares.len

func covers*(pieces:openArray[int],card:BlueCard):bool =
  let nrOfCovers = pieces.covers card.squares.required
  # debugEcho "covers:"
  # debugEcho card.title
  # debugEcho "nrOfCovers: ",nrOfCovers
  # debugEcho "required: ",card.squares.required.len
  (card.squares.required.len == 0 or card.squares.required.len == nrOfCovers) and
  (card.squares.oneInMany.len == 0 or pieces.coversOneIn(card.squares.oneInMany))

func rewardValue(hypothetical:Hypothetic,card:BlueCard):int =
  let 
    cashNeeded = cashToWin-card.cash
    # lockedPosModifier = 
    #   if card.cardKind == Mission: 
    #     hypothetical.skipped+1
    #   else: 1
  if cashNeeded < card.cash: 
    cashNeeded #div lockedPosModifier
  else: 
    card.cash #div lockedPosModifier

func oneInMoreBonus(hypothetical:Hypothetic,blueCard:BlueCard,square:int):int =
  if hypothetical.pieces.covers blueCard:
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
 
func blueBonus(hypothetical:Hypothetic,card:BlueCard,covered:bool,square:int):int =
  let
    requiredSquares = card.squares.required.deduplicate
    squareIndex = requiredSquares.find square
  if squareIndex >= 0 or square in card.squares.oneInMany:
    let nrOfPiecesRequired = card.squares.required.len
    if nrOfPiecesRequired == 1: 
      result = if card.squares.oneInMany.len > 0:
        hypothetical.oneInMoreBonus(card,square)
      else: hypothetical.rewardValue(card)*2 #+(hypothetical.distract*2)
    else:
      let
        piecesOn = requiredSquares.mapIt hypothetical.pieces.count it
        requiredPiecesOn = requiredSquares.mapIt card.squares.required.count it
        piecesVsRequired = 
          toSeq(0..requiredSquares.high)
          .mapIt piecesOn[it] - requiredPiecesOn[it]
        missingPiece = 
          piecesVsRequired[squareIndex] == -1 and
          piecesVsRequired.countIt(it >= 0) == requiredSquares.len-1
      if piecesVsRequired[squareIndex] < 1 and (missingPiece or covered):
        result = 
          (hypothetical.rewardValue(card) div nrOfPiecesRequired)*
          (toSeq(0..requiredSquares.high)
          .mapIt(min(piecesOn[it],requiredPiecesOn[it])).sum+1)

func blueVals(hypothetical:Hypothetic,squares:seq[int]):seq[int] =
  result.setLen(squares.len)
  if hypothetical.cards.len > 0:
    let covers = hypothetical.cards.mapIt hypothetical.pieces.covers it
    for si,square in squares:
      for ci,card in hypothetical.cards:
        result[si] += hypothetical.blueBonus(card,covers[ci],square)

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
    squares = toSeq(square..square+posPercent.high).mapIt adjustToSquareNr it
    blueSquareValues = hypothetical.blueVals squares
    baseSquareVals = squares.mapIt(hypothetical.board[it].toFloat)
    squarePercent = hypothetical.posPercentages squares

  toSeq(0..posPercent.high)
  .mapIt(((baseSquareVals[it]+blueSquareValues[it].toFloat)*squarePercent[it]).toInt)
  .sum

func bestIndex(hypothetical:sink Hypothetic,pieceNr:int,squares:openArray[int]):int =
  if hypothetical.pieces[pieceNr] in squares:
    hypothetical.pieces[pieceNr] = 0
  maxIndex squares.mapIt hypothetical.evalSquare it

func indexIt(hypothetical:Hypothetic,pieceNr:int,squares:sink seq[int]):int =
  squares.add gasStations
  squares[hypothetical.bestIndex(pieceNr,squares)]

func pieceNrToSquare(hypothetical:Hypothetic,pieceNr:int):int =
  case hypothetical.pieces[pieceNr]
  of 0: hypothetical.indexIt(pieceNr,@highways)
  of highways: hypothetical.indexIt(pieceNr,@[hypothetical.pieces[pieceNr]])
  else: hypothetical.pieces[pieceNr]

func evalPos*(hypothetical:Hypothetic):int = 
  toSeq(0..hypothetical.pieces.high)
  .mapIt(hypothetical.evalSquare hypothetical.pieceNrToSquare it)
  .sum

func baseEvalBoard*(hypothetical:Hypothetic):EvalBoard =
  result[0] = 4000
  for highway in highways: 
    result[highway] = highwayVal
  for bar in bars: 
    result[bar] = barVal(hypothetical)
    if hypothetical.piecesOn(bar) == 1: result[bar] *= 2

func evalBlue(hypothetical:Hypothetic,card:BlueCard):int =
  evalPos (
    baseEvalBoard(hypothetical),
    hypothetical.pieces,
    hypothetical.allPlayersPieces,
    @[card],
    hypothetical.cash,
    hypothetical.skipped
  )

# func evalBlues(hypothetical:Hypothetic):seq[BlueCard] =
#   for card in hypothetical.cards:
#     result.add card
#     result[^1].eval = hypothetical.evalBlue card
#   result.sort (a,b) => b.eval - a.eval

proc evalBluesThreaded*(hypothetical:Hypothetic):seq[BlueCard] =
  taskPoolsAs tp:
    let evals = hypothetical.cards.map(it => tp.spawn hypothetical.evalBlue it)
    for i,card in hypothetical.cards:
      result.add card
      result[^1].eval = sync evals[i] #hypothetical.evalBlue(card)
    result.sort (a,b) => b.eval - a.eval

# proc evalBluesThreaded*(hypothetical:Hypothetic):seq[BlueCard] =
#   let evals = hypothetical.cards.map(it => hypothetical.evalBlue it)
#   for i,card in hypothetical.cards:
#     result.add card
#     result[^1].eval = evals[i] #hypothetical.evalBlue(card)
#   result.sort (a,b) => b.eval - a.eval

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
  hypothetical.allPlayersPieces.countIt(it == move.toSquare) == 1 and
  hypothetical.piecesOn(move.toSquare) == 1 and 
  hypothetical.requiredPiecesOn(move.toSquare) < 2 and
  hypothetical.friendlyFireBest(move)

template requiredCardSquares(cards:untyped):untyped =
  cards.mapIt(it.squares.required.deduplicate).flatMap

func countSquaresIn(cardSquares,requiredSquares:seq[int]):int =
  cardSquares.mapIt(requiredSquares.count it).sum

template squareCountsIn(cards,requiredSquares:untyped):untyped =
  cards.mapIt it.squares.required.deduplicate.countSquaresIn requiredSquares

template printSelectionReport =
  debugEcho ""
  debugEcho "selecting cards by square:"
  debugEcho ""
  debugEcho "selected cards: "
  debugEcho selected.mapIt(it.title).join "\n"
  debugEcho "unselected cards:"
  debugEcho unselected.mapIt(it.title).join "\n"
  if selected.len == 0:
    debugEcho "unselected required: "
  else:
    debugEcho "selected required: "
  debugEcho requiredSquares
  debugEcho "squareCounts: "
  debugEcho squareCounts
  debugEcho "max index: ",index
  debugEcho "max index contains = ",squareCounts[index]
  debugEcho "passing new sequences:"
    # debugEcho "covers: "
    # debugEcho covers
    # debugEcho "values: "
    # debugEcho values

func selectCards(selected,unselected:sink seq[BlueCard],covers:sink seq[int]):seq[BlueCard] =
  if unselected.len < 2 or selected.len > 2: selected & unselected
  else:
    let 
      requiredSquares = 
        if selected.len == 0: unselected.requiredCardSquares
        else: selected.requiredCardSquares
      squareCounts = 
        if selected.len == 0:
          let counts = unselected.squareCountsIn requiredSquares
          toseq(0..counts.high).mapIt counts[it]-unselected[it].squares.required.len
        else: unselected.squareCountsIn requiredSquares
      values = toSeq(0..covers.high).mapIt squareCounts[it]+covers[it]
      index = values.maxIndex
      # index = squareCounts.maxIndex
    # printSelectionReport
    selected.add unselected[index]
    unselected.del index
    covers.del index
    selectCards(selected,unselected,covers)

template printCoveredReport =
  debugEcho "sort uncovered blues: "
  debugEcho "covered cards: "
  debugEcho coveredCards.mapIt(it.title).join "\n"
  debugEcho "uncovered cards: "
  debugEcho uncoveredCards.mapIt(it.title).join "\n"

func sortUncoveredBlues(hypothetical:Hypothetic):seq[BlueCard] =
  let coveredCards = hypothetical.cards.filterIt hypothetical.pieces.covers it
  if coveredCards.len < 3: 
    let 
      uncoveredCards = hypothetical.cards.filterIt(not hypothetical.pieces.covers it)
      covers = uncoveredCards.mapIt hypothetical.pieces.covers it.squares.required
    # printCoveredReport
    selectCards(coveredCards,uncoveredCards,covers)
  else: hypothetical.cards

func threeBest(cards:seq[BlueCard]):seq[BlueCard] =
  if cards.len > 3: 
    cards[0..2]
  else: 
    cards
 
func evalMove*(hypothetical:Hypothetic,pieceNr,toSquare:int):int =
  var pieces = hypothetical.pieces
  if hypothetical.friendlyFireAdviced (pieceNr,0,pieces[pieceNr],toSquare,0):
    pieces[pieceNr] = 0 
  else: pieces[pieceNr] = toSquare
  (hypothetical.board,pieces,
  hypothetical.allPlayersPieces,
  hypothetical.cards.threeBest,
  hypothetical.cash,
  hypothetical.skipped).evalPos

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
      if fromSquare != 0 or hypothetical.cash >= piecePrice:
        result.add (pieceNr,die,fromSquare,0,0)

func resolveSeedMoves(hypothetical:Hypothetic,moves:seq[Move]):seq[Move] =
  for move in moves:
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

# proc move*(hypothetical:Hypothetic,dice:openArray[int]):Move = 
#   result = hypothetical.movesSeededWith(dice)
#     .map(genericMove => hypothetical.bestMoveFrom genericMove)
#     # .map(bestMove => bestMove)
#     .reduce (a,b) => (if a.eval >= b.eval: a else: b)

proc diceMoves(hypothetical:Hypothetic):seq[Move] =
  taskPoolsAs tp:
    result = toSeq(1..6)
      .map(die => hypothetical.movesSeededWith([die,die]))
      .flatMap
      .map(genericMove => tp.spawn hypothetical.bestMoveFrom genericMove)
      .map(move => sync move)

# proc diceMoves(hypothetical:Hypothetic):seq[Move] =
#   result = toSeq(1..6)
#     .map(die => hypothetical.movesSeededWith([die,die]))
#     .flatMap
#     .map(genericMove => hypothetical.bestMoveFrom genericMove)
#     # .map(move => move)

proc bestDiceMoves*(hypothetical:Hypothetic):seq[Move] =
  let moves = hypothetical.diceMoves
  # echo moves
  for die in 1..6:
    let dieMoves = moves.filterIt it.die == die
    result.add dieMoves[dieMoves.mapIt(it.eval).maxIndex]
  result.sortedByIt it.eval

func allPlayersPieces(players:seq[Player]):seq[int] =
  for player in players:
    result.add player.pieces

proc boardInit(player:Player):EvalBoard =
  baseEvalBoard (
    result,
    player.pieces,
    @[],
    player.hand,
    player.cash,
    turn.nr
  )

proc hypotheticalInit*(player:Player):Hypothetic = (
  player.boardInit,
  player.pieces,
  players.allPlayersPieces,
  player.hand,
  player.cash,
  player.skipped
)

proc sortBlues*(player:Player):seq[BlueCard] =
  var hypo = player.hypotheticalInit#.evalBluesThreaded
  hypo.cards = hypo.evalBluesThreaded
  if hypo.cards.len > 3: 
    hypo.sortUncoveredBlues
  else: hypo.cards

func pieceNrsOnBars(player:Player):seq[int] =
  for nr,square in player.pieces:
    if square in bars: result.add nr

proc eventMovesEval*(player:Player,event:BlueCard):seq[Move] =
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

