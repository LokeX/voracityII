from algorithm import sort,sorted,sortedByIt
from math import pow,sum
import game
import sequtils
import sugar
# import taskpools
# import cpuInfo
import misc except reversed
# import malebolgia

const
  highwayVal* = 12000
  valBar = 15000
  # posPercent = [1.0,0.5,0.5,0.5,0.5,0.5,0.5,0.25,0.24,0.22,0.20,0.18,0.15]
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
  hypothetical.pieces.countIt(it.isBar)
  # hypothetical.pieces.countIt(it in bars)

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

func remove(pieces:seq[int],removePiece:int):seq[int] =
  for idx,piece in pieces:
    if piece == removePiece:
      if idx < pieces.high:
        result.add pieces[idx+1..pieces.high]
      return
    else: result.add piece

  # result = pieces
  # result.del pieces.find removePiece

# func remove(pieces:seq[int],removePiece:int):seq[int] =
#   result = pieces
#   result.del pieces.find removePiece

func nrOfcovers(pieces,squares:seq[int],maxDepth:int,count:int):int = 
  var 
    coverPieces:seq[int]
    idx:int
  for i,square in squares:  
    coverPieces = pieces.filterIt it.covers square
    if coverPieces.len > 0: idx = i+1; break
  if coverPieces.len == 0: 
    count
  elif idx == squares.len:
    count+1
  else: 
    var coverDepth:int
    for coverPiece in coverPieces:
      coverDepth = max(
        coverDepth,
        pieces
          .remove(coverPiece)
          .nrOfcovers(squares[idx..squares.high],maxDepth,count+1)
      )
      if coverDepth == maxDepth: 
        break
    coverDepth

template nrOfcovers*(pieces,squares:untyped):untyped = 
  pieces.nrOfcovers(squares,squares.len,0)

func covers(pieces,squares:seq[int]):bool = 
  let coverPieces = pieces.filterIt it.covers squares[0]
  if coverPieces.len == 0: 
    false
  elif squares.len == 1: 
    true
  else: coverPieces.anyIt(
    pieces.remove(it)
      .covers(squares[1..squares.high])
  )

# None recursive alternative to covers - DO NOT REMOVE

# func covers(pieces,squares:seq[int]):int = 
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
#             cover.pieces.exclude(usedPiece),
#             cover.squares[cover.idx+1..cover.squares.high]
#           )
#   count

func coversOneInMany(coverPieces,squares:seq[int],requiredSquare:int):bool = 
  var pieces = coverPieces
  if (let idx = pieces.find requiredSquare; idx > -1): pieces.del idx
  else:
    let requiredCovers = pieces.filterIt it.covers requiredSquare
    case requiredCovers.len:
      of 0: return false
      of 1: pieces.del pieces.find requiredCovers[0]
      else:discard
  pieces.any piece => squares.anyIt piece.covers it

func legalPieces(hypothetical:Hypothetic):seq[int] =
  let nrAllowed = hypothetical.cash div piecePrice
  var count = 0
  for piece in hypothetical.pieces:
    if piece == 0:
      if count == nrAllowed:
        continue
      inc count
    result.add piece

func covers*(pieces:seq[int],card:BlueCard):bool =
  (card.squares.oneInMany.len == 0 and 
    pieces.covers(card.squares.required)) or 
  (card.squares.oneInMany.len > 0 and 
    pieces.coversOneInMany(card.squares.oneInMany,card.squares.required[0]))

func cardVal(hypothetical:Hypothetic): int =
  let legalPieces = hypothetical.legalPieces
  (3-hypothetical.cards.countIt(legalPieces.covers it))*30000

func barVal*(hypothetical:Hypothetic):int = 
  valBar-(3000*hypothetical.countBars)+hypothetical.cardVal

func rewardValue(hypothetical:Hypothetic,card:BlueCard):int =
  let 
    deed = card.squares.required.len == 1
    fd = hypothetical.cash < 10000
    close = hypothetical.cash+card.cash > cashToWin
    # adjust = if (fd or close) and deed: 10 else: 1
  card.cash*(if (fd or close) and deed: 10 else: 1)

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
  elif hypothetical.piecesOn(requiredSquare) > 0: 
    result = reward
  else: result = reward div 2

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
        result[idx] += hypothetical.rewardValue(card)
    else:
      for idx,square in squares:
        if (square == card.squares.required[0] or square in card.squares.oneInMany):
          result[idx] += hypothetical.oneInMoreBonus(card,square)

func posPercentages(hypothetical:Hypothetic,squares:openArray[int]):array[12,float] =
  var freePieces,freePiecesOnSquare:int
  for i,square in squares:
    freePiecesOnSquare = hypothetical.freePiecesOn square
    if freePiecesOnSquare > 0: 
      freePieces += freePiecesOnSquare
    if freePieces == 0: 
      result[i] = posPercent[i]
    else: result[i] = posPercent[i].pow freePieces.toFloat

func squareNrs(square:int):array[12,int] =
  for idx in square..<square+posPercent.high:
    result[idx-square] = adjustToSquareNr idx

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
    highwayEvals,gasstationEvals,evals:seq[int]
    hypo = hypothetical 
  let 
    legalPieces = hypothetical.legalPieces
    highwaySquares = hypothetical.pieces.filterIt it.isHighway
    ordSquares = hypothetical.pieces.filterIt it != 0 and it notin highwaySquares
    removedCount = legalPieces.count 0
  if hypo.cards.len > 1:
    hypo.cards = hypothetical.cards.filterIt legalPieces.covers it
  evals.add ordSquares.mapIt hypo.evalSquare it
  if ordSquares.len < legalPieces.len:
    gasstationEvals = 
      gasStations.mapIt hypo.evalSquare it
    if removedCount > 0: highwayEvals = highways.mapIt hypo.evalSquare it
  for highwaySquare in highwaySquares:
    let 
      highwayIdx = highways.find highwaySquare
      highwayEval = 
        if highwayEvals.len > 0: highwayEvals[highwayIdx]
        else: hypo.evalSquare highwaySquare
      maxGasIdx = gasstationEvals.maxIndex
    if gasstationEvals[maxGasIdx] > highwayEval:
      evals.add gasstationEvals[maxGasIdx]
      gasStationEvals[maxGasIdx] = -1
    else:
      evals.add highwayEval
      if highwayEvals.len > 0: highwayEvals[highwayIdx] = -1
  if removedCount > 0:
    highwayEvals.add gasstationEvals
    for _ in 1..removedCount:
      let maxIdx = highwayEvals.maxIndex
      evals.add highwayEvals[maxIdx]
      highwayEvals[maxIdx] = -1
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
    result[i].eval = evals[i]
  result.sort (a,b) => b.eval - a.eval

# proc evalBlues*(hypothetical:Hypothetic):seq[BlueCard] =
#   var 
#     m = createMaster()
#     evals = newSeq[int](hypothetical.cards.len)
#   m.awaitAll:
#     for i,card in hypothetical.cards:
#       m.spawn hypothetical.evalBlue(card) -> evals[i]
#   var cardEvals:seq[tuple[card:BlueCard,eval:int]]
#   for i,eval in evals:
#     cardEvals.add (hypothetical.cards[i],evals[i])
#   cardEvals.sort (a,b) => b.eval - a.eval
#   cardEvals.mapIt it.card
  

func friendlyFireBest(hypothetical:Hypothetic,move:Move):bool =
  var hypoMove = hypothetical
  hypoMove.pieces[move.pieceNr] = move.toSquare
  let eval = hypoMove.evalPos
  hypoMove.pieces[move.pieceNr] = 0
  let killEval = hypoMove.evalPos
  killEval > eval
  
func friendlyFireAdviced*(hypothetical:Hypothetic,move:Move):bool =
  move.fromSquare != 0 and
  canKillPieceOn(move.toSquare) and
  hypothetical.piecesOn(move.toSquare) == 1 and 
  hypothetical.allPlayersPieces.countIt(it == move.toSquare) == 1 and
  hypothetical.requiredPiecesOn(move.toSquare) < 2 and
  hypothetical.friendlyFireBest(move)

func evalMove*(hypothetical:Hypothetic,pieceNr,toSquare:int):int =
  var hypo = hypothetical 
  if hypo.friendlyFireAdviced (pieceNr,0,hypo.pieces[pieceNr],toSquare,0):
    hypo.pieces[pieceNr] = 0 
  else: hypo.pieces[pieceNr] = toSquare
  evalPos (
    hypo.board,
    hypo.pieces,
    hypo.allPlayersPieces,
    hypo.cards,
    hypo.cash,
    hypo.skipped
  )

func bestMoveFrom(hypothetical:Hypothetic,generic:Move):Move =
  let squares = moveToSquares(generic.fromSquare,generic.die)
  if squares.len > 0:
    result = generic
    result.toSquare = squares[0]
    result.eval = hypothetical.evalMove(result.pieceNr,squares[0])
    for i in 1..squares.high:
      if (let eval = hypothetical.evalMove(result.pieceNr,squares[i]); eval > result.eval):
        (result.toSquare,result.eval) = (squares[i],eval)

func genericMoves(hypothetical:Hypothetic,dice:openArray[int]):seq[Move] =
  for die in dice.deduplicate:
    for pieceNr,fromSquare in hypothetical.legalPieces:
      result.add (pieceNr,die,fromSquare,0,0)

func moves*(hypothetical:Hypothetic,dice:openArray[int]):seq[Move] =
  for move in hypothetical.genericMoves dice:
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
#   result = hypothetical.genericMoves(dice)
#     .map(genericMove => tp.spawn hypothetical.bestMoveFrom genericMove)
#     .map(bestMove => sync bestMove)
#     .reduce (a,b) => (if a.eval >= b.eval: a else: b)
#   syncem

proc move*(hypothetical:Hypothetic,dice:openArray[int]):Move = 
  result = hypothetical.genericMoves(dice)
    .map(genericMove => hypothetical.bestMoveFrom genericMove)
    .reduce (a,b) => (if a.eval >= b.eval: a else: b)

# proc move*(hypothetical:Hypothetic,dice:openArray[int]):Move = 
#   var 
#     m = createMaster()
#     genericMoves = hypothetical.genericMoves(dice)
#     evals = newSeq[Move](genericMoves.len)
#   m.awaitAll:
#     for i,genericMove in genericMoves:
#       m.spawn hypothetical.bestMoveFrom(genericMove) -> evals[i]
#   evals.reduce (a,b) => (if a.eval >= b.eval: a else: b) 

proc bestDiceMoves*(hypothetical:Hypothetic):seq[Move] =
  for die in 1..6:
    result.add hypothetical.move [die,die]
  result.sort (a,b) => a.eval-b.eval

func allPlayersPieces(players:seq[Player]):seq[int] =
  for player in players:
    result.add player.pieces

func baseEvalBoard(hypothetical:Hypothetic):EvalBoard =
  result[0] = 24000
  for highway in highways: 
    result[highway] = highwayVal
  var value = hypothetical.barVal
  for bar in bars: 
    result[bar] = value

proc boardInit(player:Player):EvalBoard =
  baseEvalBoard (
    result,
    player.pieces,
    @[],
    player.hand,
    player.cash,
    turn.nr
  )
 
proc hypotheticalInit*(player:Player,hand:seq[BlueCard]):Hypothetic = (
  player.boardInit,
  player.pieces,
  players.allPlayersPieces,
  hand,
  player.cash,
  player.skipped
)

template hypotheticalInit*(player:untyped):untyped =
  player.hypotheticalInit player.hand

func coversDif(pieces:seq[int],card:BlueCard):int =
  var 
    coversRequired = card.squares.required.len
    covers = pieces.nrOfcovers card.squares.required
  if card.squares.oneInMany.len > 0: 
    inc coversRequired
    if pieces.coversOneInMany(card.squares.oneInMany,card.squares.required[0]):
      inc covers
  covers-coversRequired

func squareBase(cards:seq[BlueCard]):seq[int] =
  for card in cards:
    result.add card.squares.required.deduplicate
    if card.squares.oneInMany.len > 0:
      result.add card.squares.oneInMany[0]

proc sortBlues*(player:Player):seq[BlueCard] =
  if player.hand.len <= 3: result = player.hand
  else:
    var 
      covered:seq[BlueCard]
      uncovered:seq[tuple[card:BlueCard,value:int]]
      hypo = player.hypotheticalInit
      coversDif:int
    let legalPieces = hypo.legalPieces
    for card in player.hand:
      coversDif = legalPieces.coversDif card
      if coversDif > -1: covered.add card
      else: uncovered.add (card,coversDif)
    if covered.len > 3: 
      hypo.cards = covered
      covered = hypo.evalBlues
    result.add covered
    if covered.len < 3 and uncovered.len > 1:
      let squareBase = 
        if covered.len == 0: uncovered.mapIt(it.card).squareBase
        else: covered.squareBase
      for (card,value) in uncovered.mItems:
        value += card.squares.required.deduplicate.mapIt(squareBase.count it).sum
        if card.squares.oneInMany.len > 0:
          value += squareBase.count card.squares.oneInMany[0]
      uncovered.sort (a,b) => b.value-a.value
    result.add uncovered.mapIt it.card
 
func pieceNrsOnBars(player:Player):seq[int] =
  for nr,square in player.pieces:
    if square.isBar: result.add nr

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

