import game
import board
import deck
import sequtils
import math
import algorithm
import sugar

const
  highwayVal* = 1000
  valBar = 2500
  posPercent = [1.0,0.3,0.3,0.3,0.3,0.3,0.3,0.15,0.14,0.12,0.10,0.08,0.05]

type
  Cover = tuple[pieceNr,square:int]
  Move* = tuple[pieceNr,die,fromSquare,toSquare,eval:int]
  EvalBoard* = array[61,int]
  Hypothetic* = tuple
    board:array[61,int]
    pieces:array[5,int]
    cards:seq[BlueCard]

func countBars*(hypothetical:Hypothetic): int = hypothetical.pieces.countIt(it in bars)

func cardVal(hypothetical:Hypothetic): int =
  let val = 3 - hypothetical.cards.len
  if val > 0: return val*5000

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

func isCovered(hypothetical:Hypothetic, square:int): bool =
  hypothetical.pieces.anyIt(it.covers(square))

func blueCovers(hypothetical:Hypothetic,card:BlueCard): seq[Cover] =
  let requiredDistinct = card.squares.required.deduplicate
  for pieceNr,pieceSquare in hypothetical.pieces:
    if pieceSquare in requiredDistinct:
      result.add (pieceNr,pieceSquare)
    else:
      for blueSquare in requiredDistinct:
        if pieceSquare.covers(blueSquare): 
          result.add (pieceNr,blueSquare)

func enoughPiecesIn(card:BlueCard,covers:seq[Cover]): bool =
  let availablePieces = covers.mapIt(it.pieceNr).deduplicate
  availablePieces.len >= card.squares.required.len

func requiredSquaresIn(card:BlueCard,covers:seq[Cover]): bool =
  let 
    required = card.squares.required
    requiredDistinct = required.deduplicate
    requiredCounts = requiredDistinct.mapIt(required.count(it))
    coverSquares = covers.mapIt(it.square)
    coversCount = requiredDistinct.mapIt(coverSquares.count(it))
  toSeq(0..requiredCounts.len-1).allIt(coversCount[it] >= requiredCounts[it])

func isCovered(hypothetical:Hypothetic,card:BlueCard): bool =
  let covers = hypothetical.blueCovers(card)
  card.requiredSquaresIn(covers) and card.enoughPiecesIn(covers)

func oneInMoreBonus(hypothetical:Hypothetic,card:BlueCard,square:int):int =
  let 
    requiredSquare = card.squares.required[0]
    piecesOnRequiredSquare = hypothetical.piecesOn(requiredSquare) > 0
  if square == requiredSquare:
    if piecesOnRequiredSquare:
      result = 40_000
    elif card.squares.oneInMany.anyIt(hypothetical.isCovered(it)):
      result = 20_000
  elif piecesOnRequiredSquare and square in card.squares.oneInMany:
    if hypothetical.piecesOn(square) > 0: 
      result = 40_000
    else: 
      result = 20_000

func oneRequiredBonus(hypothetical:Hypothetic,card:BlueCard,square:int): int =
  if card.squares.oneInMany.len > 0:
    result = hypothetical.oneInMoreBonus(card,square)
  else: result = 20_000 

func blueBonus(hypothetical:Hypothetic,card:BlueCard,square:int): int =
  let
    requiredSquares = card.squares.required.deduplicate
    squareIndex = requiredSquares.find(square)
  if squareIndex >= 0 or square in card.squares.oneInMany:
    let nrOfPiecesRequired = card.squares.required.len
    if nrOfPiecesRequired == 1: 
      result = hypothetical.oneRequiredBonus(card,square)
    elif squareIndex < 0 and square in card.squares.oneInMany:
        result = card.cash
    else:
      let
        piecesOn = requiredSquares.mapIt(hypothetical.pieces.count(it))
        requiredPiecesOn = requiredSquares.mapIt(card.squares.required.count(it))
        freePieces = piecesOn[squareIndex] - requiredPiecesOn[squareIndex]
        hasCover = hypothetical.isCovered(card)
      if freePieces < 1 and hasCover:
        var nrOfPieces = 1
        for square in 0..requiredSquares.len-1:
          if piecesOn[square] > requiredPiecesOn[square]:
            nrOfPieces += requiredPiecesOn[square]
          else:
            nrOfPieces += piecesOn[square]
        result = (card.cash div nrOfPiecesRequired)*nrOfPieces

func blueVals*(hypothetical:Hypothetic,squares:seq[int]): seq[int] =
  result.setLen(squares.len)
  if hypothetical.cards.len > 0:
    for i,square in squares:
      for card in hypothetical.cards:
        result[i] += hypothetical.blueBonus(card,square)

func posPercentages(hypothetical:Hypothetic,squares:seq[int]): seq[float] =
  var freePieces:int
  for i,square in squares:
    let freePiecesOnSquare = hypothetical.freePiecesOn(square)
    if freePiecesOnSquare > 0:
      freePieces += freePiecesOnSquare
    if freePieces == 0:
      result.add posPercent[i]
    else:
      result.add posPercent[i].pow(freePieces.toFloat)

func evalSquare(hypothetical:Hypothetic,square:int): int =
  let 
    squares = toSeq(square..square+posPercent.len-1).mapIt(adjustToSquareNr(it))
    blueSquareValues = hypothetical.blueVals(squares)
    baseSquareVals = squares.mapIt(hypothetical.board[it].toFloat)
    squarePercent = hypothetical.posPercentages(squares)
  toSeq(0..posPercent.len-1)
  .mapIt(((baseSquareVals[it]+blueSquareValues[it].toFloat)*squarePercent[it]).toInt)
  .sum

func evalPos*(hypothetical:Hypothetic): int = 
  hypothetical.pieces.mapIt(hypothetical.evalSquare(it)).sum

func baseEvalBoard*(hypothetical:Hypothetic): EvalBoard =
  result[0] = 4000
  for highway in highways: 
    result[highway] = highwayVal
  for bar in bars: 
    result[bar] = barVal(hypothetical)
    if hypothetical.piecesOn(bar) == 1: result[bar] *= 2
  # for square in 1..60:
  #   if players.nrOfPiecesOn(square) == 1:
  #     result[square] += 2000

func evalBlue(hypothetical:Hypothetic,card:BlueCard): int =
  evalPos (
    baseEvalBoard(hypothetical),
    hypothetical.pieces,
    @[card]
  )

func evalBlues(hypothetical:Hypothetic): seq[BlueCard] =
  for card in hypothetical.cards:
    result.add card
    result[^1].eval = hypothetical.evalBlue(card)
  result.sort((a,b) => b.eval - a.eval)

func comboMatch(comboA,comboB:seq[BlueCard]): bool =
  comboA.mapIt(it.title).allIt(it in comboB.mapIt it.title)

proc blueCombos(sortCards,combo:seq[BlueCard],combos:var seq[seq[BlueCard]]) =
  if combo.len < 3:
    let cardsNotInCombo = 
      if combo.len > 0: 
        sortCards.filterIt(it.title notIn combo.mapIt(it.title))
      else: sortCards
    for card in cardsNotInCombo:
      var newCombo = combo
      newCombo.add card    
      blueCombos(cardsNotInCombo,newCombo,combos)
  elif not combos.anyIt(it.comboMatch(combo)): combos.add combo

func bestBlueCombo(hypothetical:Hypothetic,combos:seq[seq[BlueCard]]): seq[BlueCard] =
  var evals:seq[tuple[eval:int,combo:seq[BlueCard]]]
  for combo in combos:
    let eval = evalPos(
      (baseEvalBoard(hypothetical),
      hypothetical.pieces,combo)
    )
    evals.add (eval,combo)
  evals.sortedByIt(it.eval)[^1].combo

proc comboSortBlues*(hypothetical:Hypothetic): seq[BlueCard] =
  if hypothetical.cards.len > 3:
    var 
      combo:seq[BlueCard]
      combos:seq[seq[BlueCard]]
    hypothetical.cards.blueCombos(combo,combos)
    let bestCombo = hypothetical.bestBlueCombo(combos)
    result.add bestCombo
    result.add evalBlues((
      hypothetical.board,
      hypothetical.pieces,
      hypothetical.cards.filterIt(it.title notIn bestCombo.mapIt(it.title)))
    )
  else: return hypothetical.evalBlues

proc comboSortBlues(hypothetical:Hypothetic,cards:seq[BlueCard]): seq[BlueCard] =
  var hypo = hypothetical
  hypo.cards = cards
  hypo.comboSortBlues

func player(hypothetical:Hypothetic): Player =
  Player(pieces:hypothetical.pieces,hand:hypothetical.cards)

func friendlyFireBest(hypothetical:Hypothetic,move:Move): bool =
  var hypoMove = hypothetical
  hypoMove.pieces[move.pieceNr] = move.toSquare
  let eval = hypoMove.evalPos
  hypoMove.pieces[move.pieceNr] = 0
  let killEval = hypoMove.evalPos
  killEval > eval
  
func friendlyFireAdviced*(hypothetical:Hypothetic,move:Move): bool =
  move.fromSquare != 0 and
  hypothetical.piecesOn(move.toSquare) > 0 and 
  hypothetical.requiredPiecesOn(move.toSquare) < 2 and
  hypothetical.friendlyFireBest(move)

func threeBest(cards:seq[BlueCard]): seq[BlueCard] =
  if cards.len > 3: 
    var bestCards = cards
    bestCards.setLen(3) 
    return bestCards
  return cards

proc evalMove(hypothetical:Hypothetic,pieceNr,toSquare:int): int =
  var pieces = hypothetical.pieces
  if hypothetical.friendlyFireAdviced (pieceNr,0,pieces[pieceNr],toSquare,0):
    pieces[pieceNr] = 0 else: pieces[pieceNr] = toSquare
  let
    cards = hypothetical.cards.filterIt(it.title notIn hypothetical.player.cashablePlans.cashable.mapIt(it.title))
    before = (hypothetical.board,pieces,hypothetical.cards.threeBest).evalPos
    after = (hypothetical.board,pieces,hypothetical.comboSortBlues(cards).threeBest).evalPos
  before+(before-after)

proc bestMove(hypothetical:Hypothetic,pieceNr,fromSquare,die:int): Move =
  let
    squares = moveToSquares(fromSquare,die)
    evals = squares.mapIt(hypothetical.evalMove(pieceNr,it))
    bestEval = evals.maxIndex
    bestSquare = squares[bestEval]
    eval = evals[bestEval]
  (pieceNr,die,fromSquare,bestSquare,eval)

proc move*(hypothetical:Hypothetic,dice:openArray[int]): Move = 
  var moves:seq[Move]
  for pieceNr,fromSquare in hypothetical.pieces:
    for die in dice:
      moves.add hypothetical.bestMove(pieceNr,fromSquare,die)
  moves.sortedByIt(it.eval)[^1]

proc diceMoves(hypothetical:Hypothetic): seq[Move] =
  for pieceNr,fromSquare in hypothetical.pieces:
    for die in 1..6: result.add hypothetical.bestMove(pieceNr,fromSquare,die)

proc bestDiceMoves*(hypothetical:Hypothetic): seq[Move] =
  let moves = hypothetical.diceMoves()
  for die in 1..6:
    let dieMoves = moves.filterIt(it.die == die)
    result.add dieMoves[dieMoves.mapIt(it.eval).maxIndex()]
  result.sortedByIt(it.eval)

func hypotheticalInit*(player:Player): Hypothetic =
  var board:EvalBoard
  (baseEvalBoard(
    (board,
    player.pieces,
    player.hand)
  ),
  player.pieces,
  player.hand)

proc sortBlues*(player:Player):seq[BlueCard] =
  player.hypotheticalInit.comboSortBlues

