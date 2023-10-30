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
  hypo.pieces = turnPlayer.pieces
  if hypo.cards.len > 3:
    hypo.cards = hypo.evalBluesThreaded
    turnPlayer.hand = hypo.cards
  phase = Reroll

proc reroll(hypothetical:Hypothetic): bool =
  let 
    bestDiceMoves = hypothetical.bestDiceMoves()
    bestDice = bestDiceMoves.mapIt(it.die)
  updateTurnReport diceRoll
  isDouble() and diceRoll[1].ord notIn bestDice[^2..^1]

proc moveAi =
  echo "move ai"
  # for blue in turnPlayer.hand: echo blue.title
  # for blue in hypo.cards: echo blue.title
  let 
    move = hypo.move([diceRoll[1].ord,diceRoll[2].ord])
    currentPosEval = hypo.evalPos()
  if move.eval.toFloat >= currentPosEval.toFloat*0.75:
    updateTurnReport move
    moveSelection.fromSquare = move.fromSquare
    echo "move: ",move
    echo "ai pieces: ",turnPlayer.pieces
    move move.toSquare
  else:
    echo "ai skips move:"
    echo "currentPosEval: ",currentPosEval
    echo "moveEval: ",move.eval
  phase = PostMove

proc startTurn = 
  hypo = hypotheticalInit(turnPlayer)
  phase = Draw

proc rerollPhase =
  if diceReroll.isPausing and cpuTime() - diceReroll.pauseStartTime >= 0.25:
    diceReroll.isPausing = false
    startDiceRoll(computerRoll)
  elif not diceReroll.isPausing and hypo.reroll: 
    diceReroll.isPausing = true
    diceReroll.pauseStartTime = cpuTime()
  elif not diceReroll.isPausing: 
    phase = AiMove

proc postMovePhase =
  echo "postMove"
  moveSelection.fromSquare = -1
  drawCards()
  recordTurnReport()
  phase = EndTurn

proc endTurn = 
  echo "endTurn" 
  showMenu = false
  phase = Await
  nextGameState()

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

# please, for the love of God: don't even breethe on it!
proc aiRightMouse*(m:KeyEvent) =
  if phase == EndTurn: 
    if showMenu: 
      endTurn()
    else: showMenu = true
 
