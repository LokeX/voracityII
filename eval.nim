from algorithm import sort
from math import pow,sum
import random
import game
import sequtils
import sugar

const
  highwayVal = 12000
  valBar = 15000
  posPercent = [1.0,0.3,0.3,0.3,0.3,0.3,0.3,0.15,0.14,0.12,0.10,0.08,0.05]

type
  Eval* = tuple[hypothetical:Hypothetic,diceMoves:DiceMoves]
  DiceMoves* = array[DieFace,tuple[moves:seq[Move],bestMove:Move,isWinningMove:bool]]
  EvalBoard = array[61,int]
  Hypothetic* = tuple
    board:EvalBoard
    pieces:Pieces
    ownKillSquares:seq[int]
    cards:seq[BlueCard]
    cash:int

func legalPieces*(hypothetical:Hypothetic):seq[int] =
  for _,square in hypothetical.pieces.legalPiecesIter hypothetical.cash:
    if square > -1: 
      result.add square

func without(pieces:openArray[int],removePiece:int):seq[int] =
  for idx,piece in pieces:
    if piece == removePiece:
      if idx < pieces.high:
        result.add pieces[idx+1..pieces.high]
      return
    else: result.add piece
 
func covers(pieceSquare,coverSquare:int):bool =
  if pieceSquare == coverSquare:
    return true
  for die in 1..6:
    if coverSquare in moveToSquares(pieceSquare,die):
      return true

func nrOfcovers(pieces,squares:seq[int],maxDepth,depth:int):int = 
  var 
    coverPieces:seq[int]
    idx:int
  for i,square in squares:  
    coverPieces = pieces.filterIt it.covers square
    if coverPieces.len > 0: 
      idx = i+1
      break
  if coverPieces.len == 0: 
    depth
  elif idx == squares.len:
    depth+1
  else: 
    var coverDepth:int
    for coverPiece in coverPieces:
      coverDepth = max(
        coverDepth,
        pieces.without(coverPiece)
        .nrOfcovers(squares[idx..squares.high],maxDepth,depth+1)
      )
      if coverDepth == maxDepth: 
        break
    coverDepth

template nrOfcovers(pieces,squares:untyped):untyped = 
  pieces.nrOfcovers(squares,squares.len,0)

func coversAll(pieces,squares:seq[int]):bool = 
  let coverPieces = pieces.filterIt it.covers squares[0]
  if coverPieces.len == 0: 
    false
  elif squares.len == 1: 
    true
  else: coverPieces.anyIt(
    pieces.without(it).coversAll(squares[1..squares.high])
  )

template cover(pieces,squares:untyped):untyped = 
  if pieces.len < squares.len:
    false
  else: pieces.coversAll squares

func coverOneInMany(coverPieces,squares:seq[int],requiredSquare:int):bool = 
  var pieces = coverPieces
  if (let idx = pieces.find requiredSquare; idx > -1): 
    pieces.del idx
  else:
    let requiredCovers = pieces.filterIt it.covers requiredSquare
    case requiredCovers.len:
      of 0: return false
      of 1: pieces.del pieces.find requiredCovers[0]
      else:discard
  pieces.any piece => squares.anyIt piece.covers it

func cover(pieces:seq[int],card:BlueCard):bool =
  if card.squares.oneInMany.len == 0:
    pieces.cover(card.squares.required)
  else: pieces.coverOneInMany(card.squares.oneInMany,card.squares.required[0])

func oneInMoreBonus(hypothetical:Hypothetic,blueCard:BlueCard,square,reward:int):int =
  let requiredSquare = blueCard.squares.required[0]
  if square == requiredSquare:
    if blueCard.squares.oneInMany.anyIt hypothetical.pieces.count(it) > 0: 
      reward
    else: 
      case hypothetical.pieces.count requiredSquare:
        of 0:reward div 2
        of 1:reward
        else:0
  elif hypothetical.pieces.count(requiredSquare) > 0: 
    reward
  else: reward div 2

func rewardValue(hypothetical:Hypothetic,card:BlueCard):int =
  let 
    deed = card.squares.required.len == 1
    fd = hypothetical.cash < 10000
    close = hypothetical.cash+card.cash > cashToWin
  card.cash*(if (fd or close) and deed: 10 else: 1)

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
          requiredIndexes = toSeq 0..requiredSquares.high
          bonus = 
            (hypothetical.rewardValue(card) div card.squares.required.len)*
            (requiredIndexes.mapIt(min(piecesOn[it],requiredPiecesOn[it])).sum+1)
        for idx in requiredIndexes:
          if squareIndexes[idx] != -1 and piecesOn[idx]-requiredPiecesOn[idx] < 1:
            result[squareIndexes[idx]] += bonus
    elif card.squares.oneInMany.len == 0:
      if (let idx = squares.find(card.squares.required[0]); idx > -1):
        result[idx] += hypothetical.rewardValue card
    else:
      let rewardValue = hypothetical.rewardValue card
      for idx,square in squares:
        if square == card.squares.required[0] or square in card.squares.oneInMany:
          result[idx] += hypothetical.oneInMoreBonus(card,square,rewardValue)

func required(pieces:openArray[int],cards:seq[BlueCard],square:int):int =
  if cards.len == 0: 
    return
  elif (result = cards.mapIt(it.squares.required.count square).max; result > 0):
    return
  for card in cards:
    if card.squares.oneInMany.len > 0:
      if (let idx = card.squares.oneInMany.find(square); idx > -1):
        var squares = card.squares.oneInMany
        squares.del idx
        return if pieces.anyIt it in squares: 0 else: 1

template requiredPiecesOn(it,square:untyped):int =
  it.pieces.required(when typeof(it) is Hypothetic:it.cards else:it.hand,square)

func posPercentages(hypothetical:Hypothetic,squares:openArray[int]):array[12,float] =
  var freePieces,freePiecesOnSquare:int
  for i,square in squares:
    freePiecesOnSquare = hypothetical.pieces.count square
    if freePiecesOnSquare > 0:   
      freePiecesOnSquare -= hypothetical.requiredPiecesOn square
      freePieces += freePiecesOnSquare
    if freePieces < 2: 
      result[i] = posPercent[i]
    else: result[i] = posPercent[i].pow freePieces.toFloat

func squareNrs(square:int):array[12,int] =
  for idx in square..<square+posPercent.high:
    result[idx-square] = adjustToSquareNr idx

func evalSquare(hypothetical:Hypothetic,square:int):int =
  let 
    squares = square.squareNrs
    posPercent = hypothetical.posPercentages squares
    blueVals = hypothetical.blueVals squares
  for idx in 0..squares.high:
    result += toInt(
      posPercent[idx]*(hypothetical.board[squares[idx]]+blueVals[idx]).toFloat
    )

func evalPos(hypothetical:Hypothetic):int =
  var
    highwayEvals,gasstationEvals,evals:seq[int]
    hypo = hypothetical 
  let 
    legalPieces = hypothetical.legalPieces
    highwaySquares = hypothetical.pieces.filterIt it.isHighway
    ordSquares = hypothetical.pieces.filterIt it != 0 and it notin highwaySquares
    removedCount = legalPieces.count 0
  if hypo.cards.len > 1:
    hypo.cards = hypothetical.cards.filterIt legalPieces.cover it
  evals.add ordSquares.mapIt hypo.evalSquare it
  if ordSquares.len < legalPieces.len:
    gasstationEvals = gasStations.mapIt hypo.evalSquare it
    if removedCount > 0: 
      highwayEvals = highways.mapIt hypo.evalSquare it
  for highwaySquare in highwaySquares:
    let 
      highwayIdx = if highwayEvals.len > 0: highways.find highwaySquare else: -1
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

func ownKill(hypothetical:Hypothetic,pieceNr,toSquare:int):tuple[eval,killEval:int] =
  var hypoMove = hypothetical
  hypoMove.pieces[pieceNr] = toSquare
  result.eval = hypoMove.evalPos
  hypoMove.pieces[pieceNr] = 0
  result.killEval = hypoMove.evalPos

template ownkillBest*(hypothetical,move:untyped):untyped =
  let ownKill = hypothetical.ownKill(move.pieceNr,move.toSquare)
  ownKill.killEval > ownKill.eval

func evalMove(hypothetical:Hypothetic,pieceNr,toSquare:int):int =
  var hypo = hypothetical 
  if toSquare in hypothetical.ownKillSquares:
    let (eval,killEval) = hypothetical.ownkill(pieceNr,toSquare)
    if eval >= killEval: eval else: killEval
  else: 
    hypo.pieces[pieceNr] = toSquare
    hypo.evalPos

func moves(hypothetical:Hypothetic,dice:openArray[int]):seq[Move] =
  for die in dice.deduplicate:
    for pieceNr,fromSquare in hypothetical.pieces.legalPiecesIter hypothetical.cash:
      if fromSquare > -1:
        for toSquare in moveToSquares(fromSquare,die):
          result.add (pieceNr,die,fromSquare,toSquare,0)

func bestMoveIn(hypothetical:Hypothetic,moves:seq[Move]):Move = 
  var bestEval,eval,bestIndex:int
  for idx,move in moves:
    eval = hypothetical.evalMove(move.pieceNr,move.toSquare)
    if eval > bestEval:
      bestEval = eval
      bestIndex = idx
  result = moves[bestIndex]
  result.eval = bestEval

func winningMoveIn(hypothetical:Hypothetic,moves:seq[Move]):Move =
  var 
    pieces = hypothetical.pieces
    cashReward = 0
  for move in moves:
    pieces[move.pieceNr] = move.toSquare
    cashReward = pieces.cashesIn(hypothetical.cards).cashable.mapIt(it.cash).sum
    cashReward -= (if move.fromSquare == 0: piecePrice else: 0)
    if cashReward+hypothetical.cash >= cashToWin: 
      return move
    else: pieces[move.pieceNr] = move.fromSquare
  result.pieceNr = -1

func allDiceMoves*(hypothetical:Hypothetic):DiceMoves =
  for die in DieFace:
    result[die].moves = hypothetical.moves [die.ord,die.ord]
    result[die].bestMove = hypothetical.winningMoveIn result[die].moves
    if result[die].bestMove.pieceNr > -1:
      result[die].isWinningMove = true
    else:result[die].bestMove = hypothetical.bestMoveIn result[die].moves

func isBestDieIn*(dieQuery:DieFace,diceMoves:DiceMoves):bool =
  if diceMoves[dieQuery].isWinningMove: 
    true
  elif diceMoves.anyIt it.isWinningMove: 
    false
  else: 
    var bestDie = DieFace1
    for die in DieFace2..DieFace6:
      if diceMoves[die].bestMove.eval > diceMoves[bestDie].bestMove.eval:
        bestDie = die
    dieQuery == bestDie

func bestMove*(hypothetical:Hypothetic,diceMoves:DiceMoves,dice:Dice):Move =
  var isWinningMove:bool
  (isWinningMove,result) = 
    if diceMoves[^1].moves.len > 0: 
      let bestDie = 
        if diceMoves[dice[1]].bestMove.eval >= diceMoves[dice[2]].bestMove.eval or 
        diceMoves[dice[1]].isWinningMove: 1 else: 2
      (diceMoves[dice[bestDie]].isWinningMove,diceMoves[dice[bestDie]].bestMove)
    else: 
      let
        moves = hypothetical.moves [dice[1].ord,dice[2].ord]
        winningMove = hypothetical.winningMoveIn moves
      if winningMove.pieceNr > -1: (true,winningMove)
      else: (false,hypothetical.bestMoveIn moves)
  if not isWinningMove and hypothetical.evalPos >= result.eval:
    result.pieceNr = -1

proc aiShouldReroll*(hypothetical:Hypothetic,diceMoves:var DiceMoves,dice:Dice):bool =
  if dice[1] == dice[2]:
    if diceMoves[^1].moves.len == 0: 
      diceMoves = hypothetical.allDiceMoves()
    not dice[^1].isBestDieIn diceMoves
  else: false

func barVal(hypothetical:Hypothetic):int = 
  let 
    legalPieces = hypothetical.legalPieces
    cardVal = (4-hypothetical.cards.countIt(legalPieces.cover it))*15000
  valBar-(3000*hypothetical.pieces.countIt(it.isBar))+cardVal

func baseEvalBoard(hypothetical:Hypothetic):EvalBoard =
  result[0] = 24000
  for highway in highways: 
    result[highway] = highwayVal
  let barVal = hypothetical.barVal
  for bar in bars: 
    result[bar] = barVal

func boardInit(player:Player):EvalBoard =
  baseEvalBoard (
    result,
    player.pieces,
    @[],
    player.hand,
    player.cash,
  )

proc ownKillSquares(player:Player):seq[int] =
  result = player.pieces.filterIt(
    canKillPieceOn(it) and
    player.pieces.count(it) == 1 and
    not player.requiredPiecesOn(it) > 1
  )
  if result.len > 0:
    let otherPieces = toSeq(players.piecesInColorsOtherThan player.color)
    result.keepItIf it notin otherPieces

proc hypotheticalInit*(player:Player):Hypothetic = (
  player.boardInit,
  player.pieces,
  player.ownKillSquares,
  player.hand,
  player.cash,
)

func evalBlues(hypothetical:Hypothetic):seq[BlueCard] =
  for card in hypothetical.cards:
    result.add card
    result[^1].eval = evalPos (
      hypothetical.board,
      hypothetical.pieces,
      hypothetical.ownKillSquares,
      @[card],
      hypothetical.cash,
    )
  result.sort (a,b) => b.eval - a.eval

func coversDif(pieces:seq[int],card:BlueCard):int =
  var 
    coversRequired = card.squares.required.len
    covers = pieces.nrOfcovers card.squares.required
  if card.squares.oneInMany.len > 0: 
    inc coversRequired
    if pieces.coverOneInMany(card.squares.oneInMany,card.squares.required[0]):
      inc covers
  covers-coversRequired

func squareBase(cards:seq[BlueCard]):seq[int] =
  for card in cards:
    result.add card.squares.required.deduplicate
    if card.squares.oneInMany.len > 0:
      result.add card.squares.oneInMany[0]

proc sortBlues*(player:Player):seq[BlueCard] =
  if player.hand.len <= 3: return player.hand
  var 
    uncovered:seq[tuple[card:BlueCard,value:int]]
    hypo:Hypothetic
    coversDif:int
  hypo.pieces = player.pieces
  hypo.cash = player.cash
  let legalPieces = hypo.legalPieces
  for card in player.hand:
    coversDif = legalPieces.coversDif card
    if coversDif > -1: 
      hypo.cards.add card
    else: uncovered.add (card,coversDif)
  if hypo.cards.len > 3: 
    hypo.board = hypo.baseEvalBoard
    result.add hypo.evalBlues
  elif hypo.cards.len > 0: result.add hypo.cards
  if hypo.cards.len < 3 and uncovered.len > 1:
    let squareBase = 
      if hypo.cards.len == 0: uncovered.mapIt(it.card).squareBase
      else: hypo.cards.squareBase
    for (card,value) in uncovered.mItems:
      value += card.squares.required.deduplicate.mapIt(squareBase.count it).sum
      if card.squares.oneInMany.len > 0:
        value += squareBase.count card.squares.oneInMany[0]
    uncovered.sort (a,b) => b.value-a.value
  result.add uncovered.mapIt it.card

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

proc wantsNoProtectionAfter(player:Player,move:Move):bool =
  var hypo = player.hypotheticalInit
  hypo.pieces[move.pieceNr] = move.toSquare
  hypo.cards = hypo.pieces.cashesIn(hypo.cards).notCashable
  let noKillEval = hypo.evalPos
  hypo.pieces[move.pieceNr] = 0
  let killEval = hypo.evalPos
  killEval > noKillEval

proc shouldKillEnemyOn*(player:Player,move:Move):bool =
  if player.cash-(player.nrOfRemovedPieces*piecePrice) <= startCash div 2:
    return
  (move.toSquare.isBar and (players.len < 3 or player.nrOfPiecesOnBars > 0)) or 
  rand(0..99) <= player.agro or player.wantsNoProtectionAfter move
