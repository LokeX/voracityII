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
  Phase = enum Await,Draw,Reroll,AiMove,PostMove,EndTurn

func knownBlues(player:Player,deck:Deck): seq[BlueCard] =
  result.add deck.discardPile
  result.add player.hand

func require(cards:seq[BlueCard],square:int): seq[BlueCard] =
  cards.filterIt(square in it.squares.required or square in it.squares.oneInMany)

func hasPlanChanceOn(player:Player,square:int,deck:Deck): float =
  let 
    knownCards = player.knownBlues deck
    unknownCards = deck.fullDeck.filterIt(it.title notIn knownCards.mapIt(it.title))
    chance = unknownCards.require(square).len.toFloat/unknownCards.len.toFloat
  chance*player.hand.len.toFloat

# proc hasPlanChanceOn(player:Player,square:int): float =
#   planChanceOn(square)*player.hand.len.toFloat

proc enemyKill(hypothetical:Hypothetic,move:Move): bool =
  if turnPlayer.hasPieceOn(move.toSquare): return false else:
    let 
      pieceNr = players.singlePieceOn(move.toSquare).playerNr
      planChance = players[pieceNr].hasPlanChanceOn(move.toSquare,blueDeck)
      barKill = move.toSquare in bars and (
        hypothetical.countBars() > 1 or players.len < 3
      )
    echo "removePiece, planChance: ",planChance
    planChance > 0.05 or barKill

proc aiRemovePiece(hypothetical:Hypothetic,move:Move): bool =
  players.nrOfPiecesOn(move.toSquare) == 1 and (hypothetical.friendlyFireAdviced(move) or 
  hypothetical.enemyKill(move))

var
  autoEndTurn* = true
  hypo:Hypothetic
  phase:Phase = Await

proc aiTurn*(): bool =
  turn.nr != 0 and 
  turnPlayer.kind == Computer and 
  not isRollingDice()

proc echoCards =
  for card in hypo.cards:
    echo "card: ",card.title
    echo "eval: ",card.eval

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
  echo "dice: ",diceRoll
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
    echo "ai move:"
    echo move
    if hypo.aiRemovePiece(move):
      singlePiece = players.singlePieceOn(move.toSquare)
      echo "ai kills piece:"
      echo singlePiece
      removePieceAndMove("Yes")
    else: move move.toSquare
    hypo.pieces = turnPlayer.pieces
  else:
    echo "ai skips move:"
    echo "currentPosEval: ",currentPosEval
    echo "moveEval: ",move.eval
  phase = PostMove

proc startTurn = 
  echo $turnPlayer.color&" player takes turn:"
  hypo = hypotheticalInit(turnPlayer)
  phase = Draw

proc drawPhase =
  aiDraw()
  phase = Reroll

proc rerollPhase =
  if hypo.reroll: 
    echo "reroll"
    sleep(1000)
    startDiceRoll()
  else: phase = AiMove

proc postMovePhase =
  aiDraw()
  phase = EndTurn

proc endTurn =
  echo "ai end of turn"
  if autoEndTurn and turnPlayer.cash < cashToWin: 
    echo "auto end turn"
    turnPlayer.discardCards blueDeck
    nextPlayerTurn()
    playSound "carhorn-1"
    startDiceRoll()
    phase = Await

proc aiTakeTurn*() =
  case phase
  of Await: startTurn()
  of Draw: drawPhase()
  of Reroll: rerollPhase()
  of AiMove: moveAi()
  of PostMove: postMovePhase()
  of EndTurn: endTurn()
  turn.player.updateBatch

proc aiKeyb*(k:KeyEvent) =
  if k.button == KeyE: autoEndTurn = not autoEndTurn

proc aiRightMouse*(m:KeyEvent) =
  if phase == EndTurn:
    phase = Await
 
