import win
import board
import play
import game
import deck
import eval
import sequtils
import megasound
import os

var
  aiDone*,aiWorking*:bool
  autoEndTurn* = true

proc aiTurn*(): bool =
  not aiWorking and 
  turn.nr != 0 and 
  turnPlayer.kind == Computer and 
  not isRollingDice()

proc drawCards() =
  while turn.undrawnBlues > 0:
    turnPlayer.drawFrom blueDeck
    dec turn.undrawnBlues
    echo $turnPlayer.color&" player draws: ",turnPlayer.hand[^1].title
    playSound("page-flip-2")
    let cashedPlans = cashInPlansTo blueDeck
    if cashedPlans.len > 0: 
      playSound("coins-to-table-2")
      echo $turnPlayer.color&" player cashes plans:"
      for plan in cashedPlans: echo plan.title

proc reroll(hypothetical:Hypothetic): bool =
  let 
    bestDiceMoves = hypothetical.bestDiceMoves()
    bestDice = bestDiceMoves.mapIt(it.die)
  echo "dice: ",diceRoll
  echo "bestDice:"
  echo bestDice
  isDouble() and diceRoll[1].ord notIn bestDice[^2..^1]

proc echoCards(hypothetical:Hypothetic) =
  for card in hypothetical.cards:
    echo "card: ",card.title
    echo "eval: ",card.eval

proc knownBlues(): seq[BlueCard] =
  result.add blueDeck.discardPile
  result.add turnPlayer.hand

func cardsThatRequire(cards:seq[BlueCard],square:int): seq[BlueCard] =
  cards.filterIt(square in it.squares.required or square in it.squares.oneInMany)

proc planChanceOn(square:int): float =
  let 
    knownCards = knownBlues()
    unknownCards = blueDeck.fullDeck.filterIt(it.title notIn knownCards.mapIt(it.title))
  unknownCards.cardsThatRequire(square).len.toFloat/unknownCards.len.toFloat

proc hasPlanChanceOn(player:Player,square:int): float =
  planChanceOn(square)*player.hand.len.toFloat

proc enemyKill(hypothetical:Hypothetic,move:Move): bool =
  if turnPlayer.hasPieceOn(move.toSquare): return false else:
    let 
      planChance = players[players.singlePieceOn(move.toSquare)
        .playerNr].hasPlanChanceOn(move.toSquare)
      barKill = move.toSquare in bars and (
        hypothetical.countBars() > 1 or players.len < 3
      )
    echo "removePiece, planChance: ",planChance
    planChance > 0.05 or barKill

proc aiRemovePiece(hypothetical:Hypothetic,move:Move): bool =
  players.nrOfPiecesOn(move.toSquare) == 1 and (hypothetical.friendlyFireAdviced(move) or 
  hypothetical.enemyKill(move))

proc moveAi(hypothetical:Hypothetic): Hypothetic =
  let 
    move = hypothetical.move([diceRoll[1].ord,diceRoll[2].ord])
    currentPosEval = hypothetical.evalPos()
  if move.eval.toFloat >= currentPosEval.toFloat*0.75:
    # let removePiece = hypothetical.aiRemovePiece(move)
    if hypothetical.aiRemovePiece(move):
      singlePiece = players.singlePieceOn(move.toSquare)
      moveSelection.fromSquare = move.fromSquare
      moveSelection.toSquare = move.toSquare
      removePieceAndMove("Yes")
    else: move move.toSquare
    result = hypothetical
    result.pieces = turnPlayer.pieces
  else:
    echo "ai skips move:"
    echo "currentPosEval: ",currentPosEval
    echo "moveEval: ",move.eval
    return hypothetical

proc aiReroll() =
  echo "reroll"
  sleep(1000)
  startDiceRoll()
  aiWorking = false

proc aiDraw(hypothetical:Hypothetic): Hypothetic =
  drawCards()
  result = hypothetical
  result.cards = turnPlayer.hand
  result.cards = result.comboSortBlues
  turnPlayer.hand = result.cards
  hypothetical.echoCards

proc aiTakeTurn*() =
  aiWorking = true
  echo $turnPlayer.color&" player takes turn:"
  turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars
  var hypothetical = hypotheticalInit(turnPlayer).aiDraw
  if not hypothetical.reroll:
    hypothetical = hypothetical.moveAi
    hypothetical = hypothetical.aiDraw
    if autoEndTurn and not turnPlayer.cash >= cashToWin: 
      nextPlayerTurn()
      aiWorking = false
  else: aiReroll()
  aiDone = true

proc aiKeyb*(k:KeyEvent) =
  if k.button == KeyE: autoEndTurn = not autoEndTurn
  # if k.button == KeyN:
  #   echo "n key: new game"
  #   aiWorking = false
  #   aiDone = true
  #   endDiceRoll()
  #   playSound("carhorn-1")
  #   newGameSetup()

proc aiRightMouse*(m:KeyEvent) =
  if aiDone:
    aiDone = false
    aiWorking = false
