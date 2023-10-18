import win
import board
import play
import game
import deck
import eval
import sequtils
import times
import reports
import menu
import colors

type
  Phase* = enum Await,Draw,Reroll,AiMove,PostMove,EndTurn
  DiceReroll = tuple[isPausing:bool,pauseStartTime:float]

var
  autoEndTurn* = true
  hypo:Hypothetic
  phase:Phase
  diceReroll:DiceReroll

template phaseIs*:untyped = phase

func knownBluesIn(discardPile,hand:seq[BlueCard]):seq[BlueCard] =
  result.add discardPile
  result.add hand

func require(cards:seq[BlueCard],square:int): seq[BlueCard] =
  cards.filterIt(square in it.squares.required or square in it.squares.oneInMany)

func hasPlanChanceOn(player:Player,square:int,deck:Deck): float =
  let 
    knownCards = knownBluesIn(deck.discardPile,player.hand)
    unknownCards = deck.fullDeck
      .filterIt(
        it.cardKind in [Plan,Mission] and
        it.title notIn knownCards.mapIt(it.title)
      )
    chance = unknownCards.require(square).len.toFloat/unknownCards.len.toFloat
  chance*player.hand.len.toFloat

proc enemyKill(hypothetical:Hypothetic,move:Move): bool =
  if turnPlayer.hasPieceOn(move.toSquare): return false else:
    echo "checking enemy kill"
    let 
      playerNr = players.singlePieceOn(move.toSquare).playerNr
      planChance = players[playerNr].hasPlanChanceOn(move.toSquare,blueDeck)
      barKill = move.toSquare in bars and (
        hypothetical.countBars() > 1 or players.len < 3
      )
    echo "removePiece, planChance: ",planChance
    planChance > 0.05 or barKill

proc aiRemovePiece(hypothetical:Hypothetic,move:Move): bool =
  canKillPieceOn(move.toSquare) and 
  players.nrOfPiecesOn(move.toSquare) == 1 and 
  (hypothetical.friendlyFireAdviced(move) or 
  hypothetical.enemyKill(move))

proc aiTurn*(): bool =
  turn.nr != 0 and 
  turnPlayer.kind == Computer and 
  not isRollingDice()

proc drawCards =
  echo "draw cards"
  while turn.undrawnBlues > 0:
    drawCardFrom blueDeck
    playCashPlansTo blueDeck
  hypo.cards = turnPlayer.hand
  if hypo.cards.len > 3:
    hypo.cards = hypo.evalBluesThreaded
    turnPlayer.hand = hypo.cards
  phase = Reroll

proc reroll(hypothetical:Hypothetic): bool =
  let 
    bestDiceMoves = hypothetical.bestDiceMoves()
    bestDice = bestDiceMoves.mapIt(it.die)
  updateTurnReport diceRoll
  # turnReport.diceRolls.add diceRoll
  isDouble() and diceRoll[1].ord notIn bestDice[^2..^1]

proc moveAi =
  echo "move ai"
  for blue in turnPlayer.hand: echo blue.title
  for blue in hypo.cards: echo blue.title
  let 
    move = hypo.move([diceRoll[1].ord,diceRoll[2].ord])
    currentPosEval = hypo.evalPos()
  moveSelection.fromSquare = move.fromSquare
  moveSelection.toSquare = move.toSquare
  if move.eval.toFloat >= currentPosEval.toFloat*0.75:
    updateTurnReport move
    if hypo.aiRemovePiece(move):
      singlePiece = players.singlePieceOn(move.toSquare)
      killPieceAndMove("Yes")
    else: move move.toSquare
  else:
    echo "ai skips move:"
    echo "currentPosEval: ",currentPosEval
    echo "moveEval: ",move.eval
  phase = PostMove

proc startTurn = 
  hypo = hypotheticalInit(turnPlayer)
  phase = Draw

proc rerollPhase =
  if diceReroll.isPausing and cpuTime() - diceReroll.pauseStartTime >= 0.75:
    diceReroll.isPausing = false
    startDiceRoll()
  elif not diceReroll.isPausing and hypo.reroll: 
    diceReroll.isPausing = true
    diceReroll.pauseStartTime = cpuTime()
  elif not diceReroll.isPausing: 
    phase = AiMove

proc postMovePhase =
  echo "postMove"
  moveSelection.fromSquare = -1
  drawCards()
  phase = EndTurn

proc endTurn = 
  echo "endTurn" 
  recordTurnReport()
  showMenu = false
  phase = Await
  nextTurn()

proc endTurnPhase =
  if autoEndTurn and turnPlayer.cash < cashToWin:
    echo "auto end turn"
    endTurn()

proc aiTakeTurn*() =
  case phase
  of Await: startTurn()
  of Draw: drawCards()
  of Reroll: rerollPhase()
  of AiMove: moveAi()
  of PostMove: postMovePhase()
  of EndTurn: endTurnPhase()
  turn.player.updateBatch

proc aiKeyb*(k:KeyEvent) =
  if k.button == KeyE: autoEndTurn = not autoEndTurn

# please, for the love of God: don't even breethe on it!
proc aiRightMouse*(m:KeyEvent) =
  echo "aiRightMouse"
  echo "phase == ",phase
  if phase == EndTurn: 
    echo "phase == EndTurn"
    if showMenu: endTurn()
    else: showMenu = true
 
