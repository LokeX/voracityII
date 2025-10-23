from algorithm import sort,sorted,sortedByIt
from math import pow,sum
import game
import sequtils
import sugar
# import taskpools
# import cpuInfo
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

# var tp = Taskpool.new(num_threads = countProcessors() div 2)

# template syncem:untyped =
#   tp.syncAll

func countBars*(hypothetical:Hypothetic):int = 
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
      maxCovers = max(
        maxCovers,
        pieces.filterIt(it != coverPiece)
        .covers(squares[idx+1..squares.high],count+1)
      )
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
    if card.squares.required.len > 1:
      let
        requiredSquares = card.squares.required.deduplicate
        squareIndexes = requiredSquares.mapIt squares.find it
      if squareIndexes.anyIt it != -1:
        let
          piecesOn = requiredSquares.mapIt hypothetical.pieces.count it
          requiredPiecesOn = requiredSquares.mapIt card.squares.required.count it
          requiredIndexes = toSeq(0..requiredSquares.high)
          piecesVsRequired = requiredIndexes.mapIt piecesOn[it] - requiredPiecesOn[it]
          bonus = 
            (hypothetical.rewardValue(card) div card.squares.required.len)*
            (requiredIndexes.mapIt(min(piecesOn[it],requiredPiecesOn[it])).sum+1)
        for idx in requiredIndexes:
          if squareIndexes[idx] != -1 and piecesVsRequired[idx] < 1:
            result[squareIndexes[idx]] += bonus
    elif card.squares.oneInMany.len == 0:
      if (let idx = squares.find(card.squares.required[0]); idx > -1):
        result[idx] += hypothetical.rewardValue(card)*2
    else:
      for idx,square in squares:
        if (square == card.squares.required[0] or square in card.squares.oneInMany):
          result[idx] += hypothetical.oneInMoreBonus(card,square)

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
    hypo = hypothetical 
    bestGasstation = -1
    highwayEvals,evals:seq[int]
  hypo.cards = hypothetical.cards.filterIt hypothetical.pieces.covers it
  let squares = hypothetical.pieces.filterIt it != 0
  if squares.len < hypothetical.pieces.len:
    highwayEvals = highways.mapIt hypo.evalSquare it
    bestGasstation = max gasStations.mapIt hypo.evalSquare it
    evals.add max(bestGasstation,max highwayEvals)
  for square in squares:
    if (let idx = highways.find square; idx > -1):
      if bestGasstation == -1:
        bestGasstation = max gasStations.mapIt hypo.evalSquare it      
      let thisHighway = 
        if highwayEvals.len > 0: highwayEvals[idx]
        else: hypo.evalSquare square
      evals.add max(thisHighway,bestGasstation)
    else: evals.add hypo.evalSquare square
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

# proc evalBlues*(hypothetical:Hypothetic):seq[BlueCard] =
#   let evals = hypothetical.cards.map it => tp.spawn hypothetical.evalBlue it
#   for i,card in hypothetical.cards:
#     result.add card
#     result[^1].eval = sync evals[i] #hypothetical.evalBlue(card)
#   result.sort (a,b) => b.eval - a.eval
#   syncem

proc evalBlues*(hypothetical:Hypothetic):seq[BlueCard] =
  let evals = hypothetical.cards.mapIt hypothetical.evalBlue it
  result = hypothetical.cards
  for i,_ in evals:
    # result.add card
    result[i].eval = evals[i] #hypothetical.evalBlue(card)
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
  hypothetical.allPlayersPieces.countIt(it == move.toSquare) == 1 and
  hypothetical.requiredPiecesOn(move.toSquare) < 2 and
  hypothetical.friendlyFireBest(move)

func evalMove*(hypothetical:Hypothetic,pieceNr,toSquare:int):int =
  var 
    # pieces = hypothetical.pieces
    hypo = hypothetical 
  if hypo.friendlyFireAdviced (pieceNr,0,hypo.pieces[pieceNr],toSquare,0):
    hypo.pieces[pieceNr] = 0 
  else: hypo.pieces[pieceNr] = toSquare
  # hypo.cards = hypothetical.cards.filterIt hypo.pieces.covers it
  (hypo.board,hypo.pieces,
  hypo.allPlayersPieces,
  hypo.cards,
  hypo.cash,
  hypo.skipped).evalPos

func bestMoveFrom(hypothetical:Hypothetic,generic:Move):Move =
  let squares = moveToSquares(generic.fromSquare,generic.die)
  if squares.len > 0:
    result = generic
    result.toSquare = squares[0]
    result.eval = hypothetical.evalMove(result.pieceNr,squares[0])
    for i in 1..squares.high:  
      if (let eval = hypothetical.evalMove(result.pieceNr,squares[i]); eval > result.eval):
        (result.toSquare,result.eval) = (squares[i],eval)
  
func movesSeededWith(hypothetical:Hypothetic,dice:openArray[int]):seq[Move] =
  for die in dice.deduplicate:
    for pieceNr,fromSquare in hypothetical.pieces.deduplicate:
      if fromSquare != 0 or hypothetical.cash >= piecePrice:
        result.add (pieceNr,die,fromSquare,0,0)

func movesResolvedWith*(hypothetical:Hypothetic,dice:openArray[int]):seq[Move] =
  for move in hypothetical.movesSeededWith dice:
    for toSquare in moveToSquares(move.fromSquare,move.die):
      result.add move
      result[^1].toSquare = toSquare

func player*(hypothetical:Hypothetic,move:Move):Player =
  var pieces = hypothetical.pieces
  pieces[move.pieceNr] = move.toSquare
  Player(
    pieces:pieces,
    hand:hypothetical.cards
  )

# proc move*(hypothetical:Hypothetic,dice:openArray[int]):Move = 
#   result = hypothetical.movesSeededWith(dice)
#     .map(genericMove => tp.spawn hypothetical.bestMoveFrom genericMove)
#     .map(bestMove => sync bestMove)
#     .reduce (a,b) => (if a.eval >= b.eval: a else: b)
#   syncem

proc move*(hypothetical:Hypothetic,dice:openArray[int]):Move = 
  result = hypothetical.movesSeededWith(dice)
    .map(genericMove => hypothetical.bestMoveFrom genericMove)
    # .map(bestMove => bestMove)
    .reduce (a,b) => (if a.eval >= b.eval: a else: b)

proc bestDiceMoves*(hypothetical:Hypothetic):seq[Move] =
  for die in 1..6:
    result.add hypothetical.move [die,die]
  result.sort (a,b) => a.eval-b.eval

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

# proc sortBlues*(player:Player):seq[BlueCard] =
#   var hypo = player.hypotheticalInit #.evalBlues
#   hypo.cards = hypo.evalBlues
#   if hypo.cards.len > 3: 
#     hypo.sortUncoveredBlues
#   else: hypo.cards

func covers(player:Player,card:BlueCard):int =
  var 
    coversRequired = card.squares.required.len
    covers = player.pieces.covers(card.squares.required)
  if card.squares.oneInMany.len > 0: 
    inc coversRequired
    if player.pieces.covers(card.squares.oneInMany) > 0:
      inc covers
  covers-coversRequired

func squareBase(cards:seq[BlueCard]):seq[int] =
  for card in cards:
    result.add card.squares.required
    if card.squares.oneInMany.len > 0:
      result.add card.squares.oneInMany[0]

proc sortBlues*(player:Player):seq[BlueCard] =
  if player.hand.len <= 3: result = player.hand
  else:
    var 
      covered:seq[BlueCard]
      uncovered:seq[tuple[card:BlueCard,value:int]]
    # echo player.pieces
    for card in player.hand:
      let covers = player.covers card
      # echo card.title,": ",covers
      if covers > -1: covered.add card
      else: uncovered.add (card,covers)
    if covered.len > 3:
      var hypo = player.hypotheticalInit
      hypo.cards = covered
      covered = hypo.evalBlues
    result.add covered
    if uncovered.len < 2:
      if uncovered.len > 0: result.add uncovered[0].card
    elif covered.len >= 3: result.add uncovered.mapIt it.card
    else:
      var squareBase = 
        if covered.len == 0: uncovered.mapIt(it.card).squareBase
        else: covered.squareBase
      for (card,value) in uncovered.mitems:
        value += card.squares.required.deduplicate.mapIt(squareBase.count it).sum
        if card.squares.oneInMany.len > 0:
          value += squareBase.count card.squares.oneInMany[0]
      uncovered.sort (a,b) => b.value-a.value
      result.add uncovered.mapIt it.card

func pieceNrsOnBars(player:Player):seq[int] =
  for nr,square in player.pieces:
    if square in bars: result.add nr

proc eventMovesEval*(player:Player,event:BlueCard):seq[Move] =
  var hypothetical = player.hypotheticalInit
  hypothetical.cards = player.sortBlues
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

