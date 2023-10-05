import win
import board
import play
import game
import deck
import eval
import sequtils
import megasound
import os

type
  Mode = enum Start,Draw,Reroll,Move,PostMove,EndTurn,Await

var
  aiDone*,aiWorking*:bool
  autoEndTurn* = true

proc aiTurn*(): bool =
  not aiWorking and 
  turn.nr != 0 and 
  turnPlayer.kind == Computer and 
  not isRollingDice()

proc drawCard =
  turnPlayer.drawFrom blueDeck
  dec turn.undrawnBlues
  echo $turnPlayer.color&" player draws: ",turnPlayer.hand[^1].title
  playSound("page-flip-2")    

proc cashPlans =
  if (let cashedPlans = cashInPlansTo blueDeck; cashedPlans.len > 0): 
    playSound("coins-to-table-2")
    echo $turnPlayer.color&" player cashes plans:"
    for plan in cashedPlans: echo plan.title

proc drawCards() =
  while turn.undrawnBlues > 0:
    drawCard()
    cashPlans()

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
      planChance = 
        players[players.singlePieceOn(move.toSquare).playerNr]
        .hasPlanChanceOn(move.toSquare)
      barKill = move.toSquare in bars and (
        hypothetical.countBars() > 1 or players.len < 3
      )
    echo "removePiece, planChance: ",planChance
    planChance > 0.05 or barKill

proc aiRemovePiece(hypothetical:Hypothetic,move:Move): bool =
  players.nrOfPiecesOn(move.toSquare) == 1 and (hypothetical.friendlyFireAdviced(move) or 
  hypothetical.enemyKill(move))

proc aiDraw(hypothetical:Hypothetic): Hypothetic =
  drawCards()
  result = hypothetical
  result.cards = turnPlayer.hand
  if result.cards.len > 3:
    result.cards = result.evalBluesThreaded
    turnPlayer.hand = result.cards
  hypothetical.echoCards

proc moveAi(hypothetical:Hypothetic): Hypothetic =
  let 
    move = hypothetical.move([diceRoll[1].ord,diceRoll[2].ord])
    currentPosEval = hypothetical.evalPos()
  moveSelection.fromSquare = move.fromSquare
  moveSelection.toSquare = move.toSquare
  if move.eval.toFloat >= currentPosEval.toFloat*0.75:
    echo "ai move:"
    echo move
    if hypothetical.aiRemovePiece(move):
      singlePiece = players.singlePieceOn(move.toSquare)
      echo "ai kills piece:"
      echo singlePiece
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

proc aiTakeTurn*() =
  aiWorking = true
  echo $turnPlayer.color&" player takes turn:"
  # turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars
  var hypothetical = hypotheticalInit(turnPlayer).aiDraw
  if not hypothetical.reroll:
    hypothetical = hypothetical.moveAi
    hypothetical = hypothetical.aiDraw
    if autoEndTurn and not turnPlayer.cash >= cashToWin: 
      nextPlayerTurn()
      aiWorking = false
  else: aiReroll()
  turn.player.updateBatch
  aiDone = true

# proc aiTakeTurn*() =
#   aiWorking = true
#   echo $turnPlayer.color&" player takes turn:"
#   # turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars
#   var hypothetical = hypotheticalInit(turnPlayer).aiDraw
#   if not hypothetical.reroll:
#     hypothetical = hypothetical.moveAi
#     hypothetical = hypothetical.aiDraw
#     if autoEndTurn and not turnPlayer.cash >= cashToWin: 
#       nextPlayerTurn()
#       aiWorking = false
#   else: aiReroll()
#   turn.player.updateBatch
#   aiDone = true

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
