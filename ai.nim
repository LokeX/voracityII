from win import KeyEvent
import board
import play
import game
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
  playCashPlansTo blueDeck
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

proc aiMove(hypothetical:Hypothetic,dice:openArray[int]):(bool,Move) =
  if(
    let winMove = hypothetical.winningMove dice; 
    winMove.pieceNr != -1
  ):(true,winMove) else: (false,hypothetical.move dice)

func betterThan(move:Move,hypothetical:Hypothetic):bool =
  move.eval.toFloat >= hypothetical.evalPos().toFloat*0.75

proc moveAi =
  let (isWinningMove,move) = hypo.aiMove([diceRoll[1].ord,diceRoll[2].ord])
  if isWinningMove or move.betterThan hypo:
    moveSelection.fromSquare = move.fromSquare
    move move.toSquare
  else:
    echo "ai skips move:"
    # echo "currentPosEval: ",currentPosEval
    # echo "moveEval: ",move.eval
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
  moveSelection.fromSquare = -1
  drawCards()
  # recordTurnReport()
  phase = EndTurn

proc endTurn = 
  # showMenu = false
  phase = Await
  nextGameState()

proc endTurnPhase =
  if autoEndTurn and turnPlayer.cash < cashToWin:
    endTurn()
  else: showMenu = true

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
      # showMenu = not showMenu
 
