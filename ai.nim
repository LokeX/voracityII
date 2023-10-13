import win
import board
import play
import game
import deck
import eval
import sequtils
import megasound
import times
import reports
import menu

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
    unknownCards = deck.fullDeck.filterIt(it.title notIn knownCards.mapIt(it.title))
    chance = unknownCards.require(square).len.toFloat/unknownCards.len.toFloat
  chance*player.hand.len.toFloat

proc enemyKill(hypothetical:Hypothetic,move:Move): bool =
  if turnPlayer.hasPieceOn(move.toSquare): return false else:
    let 
      playerNr = players.singlePieceOn(move.toSquare).playerNr
      planChance = players[playerNr].hasPlanChanceOn(move.toSquare,blueDeck)
      barKill = move.toSquare in bars and (
        hypothetical.countBars() > 1 or players.len < 3
      )
    turnReport.add "removePiece, planChance: "&($planChance)
    echo "removePiece, planChance: ",planChance
    planChance > 0.05 or barKill

proc aiRemovePiece(hypothetical:Hypothetic,move:Move): bool =
  canRemoveAPieceFrom(move.toSquare) and 
  players.nrOfPiecesOn(move.toSquare) == 1 and 
  (hypothetical.friendlyFireAdviced(move) or 
  hypothetical.enemyKill(move))

proc aiTurn*(): bool =
  turnPlayer.cash < cashToWin and
  turn.nr != 0 and 
  turnPlayer.kind == Computer and 
  not isRollingDice()

proc echoCards =
  for card in hypo.cards:
    echo "card: ",card.title
    echo "eval: ",card.eval

proc drawCard = #a menu problem HERE?
  turnPlayer.hand.drawFrom blueDeck
  dec turn.undrawnBlues
  turnReport.add $turnPlayer.color&" player draws a card"
  echo $turnPlayer.color&" player draws: ",turnPlayer.hand[^1].title
  playSound("page-flip-2")    

proc cashPlans =
  if (let cashedPlans = cashInPlansTo blueDeck; cashedPlans.len > 0): 
    playSound("coins-to-table-2")
    turnReport.add $turnPlayer.color&" player cashes plans:"
    echo $turnPlayer.color&" player cashes plans:"
    for plan in cashedPlans: 
      turnReport.add plan.title
      echo plan.title

proc drawCards =
  while turn.undrawnBlues > 0:
    drawCard()
    cashPlans()
  hypo.cards = turnPlayer.hand
  if hypo.cards.len > 3:
    hypo.cards = hypo.evalBluesThreaded
    turnPlayer.hand = hypo.cards

proc aiDraw =
  drawCards()
  echoCards()
  phase = Reroll

proc reroll(hypothetical:Hypothetic): bool =
  let 
    bestDiceMoves = hypothetical.bestDiceMoves()
    bestDice = bestDiceMoves.mapIt(it.die)
  turnReport.add "rolled dice: "&($diceRoll)
  turnReport.add "bestDice: "&($bestDice)
  echo "rolled dice: ",diceRoll
  echo "bestDice:"
  echo bestDice
  isDouble() and diceRoll[1].ord notIn bestDice[^2..^1]

proc moveAi =
  let 
    move = hypo.move([diceRoll[1].ord,diceRoll[2].ord])
    currentPosEval = hypo.evalPos()
  moveSelection.fromSquare = move.fromSquare
  moveSelection.toSquare = move.toSquare
  if move.eval.toFloat >= currentPosEval.toFloat*0.75:
    turnReport.add "ai move:"
    turnReport.add $move
    echo "ai move:"
    echo move
    if hypo.aiRemovePiece(move):
      singlePiece = players.singlePieceOn(move.toSquare)
      turnReport.add "ai kills piece: "&($singlePiece)
      echo "ai kills piece:"
      echo singlePiece
      removePieceAndMove("Yes")
    else: move move.toSquare
  else:
    turnReport.add "ai skips move:"
    turnReport.add "currentPosEval: "&($currentPosEval)
    turnReport.add "moveEval: "&($move.eval)
    echo "ai skips move:"
    echo "currentPosEval: ",currentPosEval
    echo "moveEval: ",move.eval
  phase = PostMove

proc startTurn = 
  turnReport.setLen 0
  turnReport.add "turn report:"
  turnReport.add $turnPlayer.color&" player takes turn nr: "&($(turnPlayer.turnNr+1))
  echo $turnPlayer.color&" player takes turn:"
  hypo = hypotheticalInit(turnPlayer)
  phase = Draw

proc drawPhase =
  aiDraw()
  phase = Reroll

proc rerollPhase =
  if diceReroll.isPausing and cpuTime() - diceReroll.pauseStartTime >= 0.75:
    diceReroll.isPausing = false
    startDiceRoll()
  elif not diceReroll.isPausing and hypo.reroll: 
    turnReport.add "reroll"
    echo "reroll"
    diceReroll.isPausing = true
    diceReroll.pauseStartTime = cpuTime()
  elif not diceReroll.isPausing: 
    phase = AiMove

proc postMovePhase =
  moveSelection.fromSquare = -1
  # singlePiece.playerNr = -1
  # hypo.pieces = turnPlayer.pieces
  aiDraw()
  recordPlayerReport()
  phase = EndTurn

proc endTurn =  
  if (let discardedCards = turnPlayer.discardCards blueDeck; discardedCards.len > 0):
    turnReport.add $turnPlayer.color&" player discards cards:"
    for card in discardedCards:
      turnReport.add card.title
  turnReport.add "ai end of turn"
  echo "ai end of turn"
  recordPlayerReport()
  nextPlayerTurn()
  playSound "carhorn-1"
  startDiceRoll()
  showMenu = false
  phase = Await

proc endTurnPhase =
  if autoEndTurn:
    turnReport.add "auto end turn"
    echo "auto end turn"
    endTurn()

proc aiTakeTurn*() =
  case phase
  of Await: startTurn()
  of Draw: drawPhase()
  of Reroll: rerollPhase()
  of AiMove: moveAi()
  of PostMove: postMovePhase()
  of EndTurn: endTurnPhase()
  turn.player.updateBatch

proc aiKeyb*(k:KeyEvent) =
  if k.button == KeyE: autoEndTurn = not autoEndTurn

# please, for the love of God: don't even breethe on it!
proc aiRightMouse*(m:KeyEvent) =
  if phase == EndTurn: 
    if showMenu: endTurn()
    else: showMenu = true
 
