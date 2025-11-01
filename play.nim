from math import sum
import misc
import game
import sequtils
import eval
import random
import strutils
import times
import sugar

type
  Phase* = enum Await,Draw,Reroll,AiMove,PostMove,EndTurn
  DiceReroll = tuple[isPausing:bool,pauseStartTime:float]
  ConfigState* = enum StartGame,SetupGame,GameWon
  SinglePiece = tuple[playerNr,pieceNr:int]
  EventMoveFmt* = tuple[fromSquare,toSquare:string]
  TurnReport* = object
    turnNr*:int
    playerBatch*:tuple[color:PlayerColor,kind:PlayerKind]
    diceRolls*:seq[Dice]
    moves*:seq[Move]
    cards*:tuple[drawn,played,cashed,discarded,hand:seq[BlueCard]]
    kills*:seq[PlayerColor]

var
  # Interface controls
  runMoveAnimation*:proc()
  resetReportsUpdate*:proc()
  updatePieces*:proc()
  menuControl*:proc(show:bool)
  updateKillMatrix*:proc()
  turnReportUpdate*:proc()
  updateUndrawnBlues*:proc()
  turnReportBatchesInit*:proc()
  rollTheDice*:proc()
  runSelectBar*:proc()
  killDialog*:proc(square:int)

  # Interface flags
  recordStats* = true
  updateKeybar*:bool
  gameWon*:bool
  statGame*:bool
  autoEndTurn* = true

  # Interface state
  configState*:proc(config:ConfigState)
  singlePiece*:SinglePiece
  dialogBarMoves*:seq[Move]
  soundToPlay*:seq[string]
  phase*:Phase
  turnReports*:seq[TurnReport]
  turnReport*:TurnReport

  # Internals
  hypo:Hypothetic
  diceReroll:DiceReroll
  bestDiceMoves:seq[Move]

template setConfigStateTo(config:ConfigState) =
  if configState != nil:
    configState config

template startKillDialog(square:int) =
  if killDialog != nil:
    killDialog square

template selectBar =
  if runSelectBar != nil:
    runSelectBar()

template startDiceRoll =
  if rollTheDice != nil:
    rollTheDice()

template showMenu(show:bool) =
  if menuControl != nil:
    menuControl show

template reportUpdateReset =
  if resetReportsUpdate != nil:
    resetReportsUpdate()

template updateTurnReport =
  if turnReportUpdate != nil:
    turnReportUpdate()

template moveAnimation =
  if runMoveAnimation != nil:
    runMoveAnimation()

template playSound(s:string) =
  if not statGame:
    soundToPlay.add s

template initTurnReportBatches =
  if turnReportBatchesInit != nil:
    turnReportBatchesInit()

template killMatrixUpdate =
  if updateKillMatrix != nil:
    updateKillMatrix()

template undrawnBluesUpdate =
  if updateUndrawnBlues != nil:
    updateUndrawnBlues()

template updatePiecesPainter =
  if updatePieces != nil:
    updatePieces()

proc initTurnReport* =
  turnReport = TurnReport()
  turnReport.turnNr = turnPlayer.turnNr+1
  initTurnReportBatches()

proc updateTurnReport*[T](item:T) =
  execIf recordStats:
    when typeOf(T) is Move: 
      turnReport.moves.add item
    # when typeof(T) is Dice: 
    #   turnReport.diceRolls.add item
    when typeof(T) is PlayerColor: 
      turnReport.kills.add item
      killMatrixUpdate()
    updateTurnReport()
  
proc updateTurnReportCards*(blues:seq[BlueCard],playedCard:PlayedCard) =
  execIf recordStats:
    case playedCard:
      of Drawn: turnReport.cards.drawn.add blues
      of Played: turnReport.cards.played.add blues
      of Cashed: turnReport.cards.cashed.add blues
      of Discarded: turnReport.cards.discarded.add blues
    updateTurnReport()

# proc echoTurn(report:TurnReport) =
#   for fn,item in turnReport.fieldPairs:
#     when typeOf(item) is tuple:
#       for n,i in item.fieldPairs: 
#         echo n,": ",$i
#     else: 
#       echo fn,": ",$item

proc recordTurnReport* =
  execIf recordStats:
    turnReport.cards.hand = turnPlayer.hand
    turnReports.add turnReport

proc setupNewGame* =
  turn = (0,0,false,0)
  blueDeck.resetDeck
  players = newDefaultPlayers()
  setConfigStateTo SetupGame

proc barToMassacre(player:Player,players:seq[Player]):int =
  if (let playerBars = turnPlayer.piecesOnBars; playerBars.len > 0):
    let 
      maxPieces = playerBars.mapIt(players.nrOfPiecesOn it).max
      barsWithMaxPieces = playerBars.filterIt(players.nrOfPiecesOn(it) == maxPieces)
      chosenBar = barsWithMaxPieces[rand 0..barsWithMaxPieces.high]
    chosenBar
  else: -1

proc playMassacre =
  if (let bar = turnPlayer.barToMassacre players; bar != -1):
    for (playerNr,pieceNr) in players.piecesOn bar:
      players[playerNr].pieces[pieceNr] = 0
    playSound "Deanscream-2"
    playSound "Gunshot"
    updatePiecesPainter()

proc playCashPlansTo*(deck:var Deck) =
  let
    initialCash = turnPlayer.cash
    cashedPlans = cashInPlansTo deck
  if cashedPlans.len > 0:
    updateTurnReportCards(cashedPlans,Cashed)
    turnPlayer.update = true
    playSound "coins-to-table-2"
    if initialCash < cashToWin and turnPlayer.cash >= cashToWin:
      setConfigStateTo GameWon
      echo "game won : ",turnPlayer.cash
      gameWon = true
    else:
      turn.undrawnBlues += cashedPlans.mapIt(
        if it.squares.required.len == 1: 2 else: 1
      ).sum
      undrawnBluesUpdate()

proc movePiece*(square:int)
proc eventMoveFmt*(move:Move):EventMoveFmt =
  ("from:"&board[move.fromSquare].name&" Nr. "&($board[move.fromSquare].nr)&"\n",
   "to:"&board[move.toSquare].name&" Nr. "&($board[move.toSquare].nr)&"\n")

proc dialogEntries*(moves:seq[Move],f:EventMoveFmt -> string):seq[string] =
  var ms = moves.mapIt(it.eventMoveFmt).mapIt(f it).deduplicate
  stripLineEnd ms[^1]
  ms

proc endBarMoveSelection*(selection:string) =
  if (let toSquare = selection.splitWhitespace[^1].parseInt; toSquare != -1):
    moveSelection.toSquare = toSquare
    moveSelection.event = true
    movePiece moveSelection.toSquare

proc barMove(moveEvent:BlueCard):bool =
  dialogBarMoves = turnPlayer.eventMovesEval moveEvent
  if dialogBarMoves.len > 0:
    if dialogBarMoves.len == 1 or turnPlayer.kind == Computer:
      moveSelection.event = true
      moveSelection.fromSquare = dialogBarMoves[0].fromSquare
      moveSelection.toSquare = dialogBarMoves[0].toSquare
      return true
    else: selectBar()

proc playNews =
  updatePiecesPainter()
  let news = turnPlayer.hand[^1]
  turnPlayer.hand.playTo blueDeck,turnPlayer.hand.high
  for (playerNr,pieceNr) in players.piecesOn news.moveSquares[0]:
    players[playerNr].pieces[pieceNr] = news.moveSquares[1]
  if news.moveSquares[1] == 0: playSound "electricity"
  else: playSound "driveBy"
  playCashPlansTo blueDeck

proc playEvent()
proc playDejaVue =
  playSound "SCARYBEL-1"
  turnPlayer.hand.add blueDeck.discardPile[^2]
  delete(blueDeck.discardPile,blueDeck.discardPile.high - 1)
  blueDeck.lastDrawn = turnPlayer.hand[^1].title
  if turnPlayer.hand.len > 0: 
    case turnPlayer.hand[^1].cardKind:
      of Event: playEvent()
      of News: playNews()
      else:discard

proc playEvent =
  let event = turnPlayer.hand[^1]
  turnPlayer.hand.playTo blueDeck,turnPlayer.hand.high
  case event.title:
    of "Sour piss":
      playSound "can-open-1"
      blueDeck.shufflePiles
      turn.undrawnBlues += 1
    of "Happy hour": 
      playSound "aplauze-1"
      turn.undrawnBlues += 3
    of "Massacre": playMassacre()
    of "Deja vue": 
      if blueDeck.discardPile.len > 1: playDejaVue()
    elif barMove event: movePiece moveSelection.toSquare
  playCashPlansTo blueDeck

proc drawCardFrom*(deck:var Deck) =
  turnPlayer.hand.drawFrom deck
  var action:PlayedCard = Played
  let blue = turnPlayer.hand[^1]
  case blue.cardKind:
    of Event: playEvent()
    of News: playNews()
    else: action = Drawn
  updateTurnReportCards(@[blue],action)
  dec turn.undrawnBlues
  undrawnBluesUpdate()
  turnPlayer.update = true
  playSound "page-flip-2"

func singlePieceOn(players:seq[Player],square:int):SinglePiece =
  if players.nrOfPiecesOn(square) == 1:
    for playerNr,player in players:
      for pieceNr,piece in player.pieces:
        if piece == square: return (playerNr,pieceNr)
  result = (-1,-1)

proc getMove:Move =
  result.die = -1
  result.eval = -1
  result.fromSquare = moveSelection.fromSquare
  result.toSquare = moveSelection.toSquare
  result.pieceNr = turnPlayer.pieceOnSquare moveSelection.fromSquare

proc move* =
  var move = getMove()
  if not turn.diceMoved and not moveSelection.event:
    turn.diceMoved = diceMoved(
      moveSelection.fromSquare,moveSelection.toSquare
    )
    if turn.diceMoved:
      move.die = dieUsed(moveSelection.fromSquare,moveSelection.toSquare,diceRoll)
  elif moveSelection.event: moveSelection.event = false
  updateTurnReport move
  turnPlayer.pieces[move.pieceNr] = moveSelection.toSquare
  if moveSelection.fromSquare == 0: 
    turnPlayer.cash -= piecePrice
    turnPlayer.update = true
  playCashPlansTo blueDeck
  turnPlayer.hand = turnPlayer.sortBlues
  turnPlayer.update = true
  moveSelection.fromSquare = -1
  updatePiecesPainter()
  updateKeybar = true
  playSound "driveBy"
  if moveSelection.toSquare.isBar:
    inc turn.undrawnBlues
    undrawnBluesUpdate()
    playSound "can-open-1"

proc killPieceAndMove*(confirmedKill:string) =
  if confirmedKill == "Yes":
    players[singlePiece.playerNr].pieces[singlePiece.pieceNr] = 0
    updateTurnReport players[singlePiece.playerNr].color
    playSound "Gunshot"
    playSound "Deanscream-2"
  if statGame: move()
  else: moveAnimation

proc hostileFireEval(player:Player,pieceNr,toSquare:int):int =
  var hypoPlayer = player
  hypoPlayer.pieces[pieceNr] = toSquare
  hypoPlayer.hand = hypoPlayer.plans.notCashable
  hypoPlayer.hypotheticalInit.evalPos

proc hostileFireAdviced(player:Player,fromSquare,toSquare:int):bool =
  let pieceNr = player.pieces.find(fromSquare)
  pieceNr != -1 and 
  player.hostileFireEval(pieceNr,toSquare) < player.hostileFireEval(pieceNr,0)

proc shouldKillEnemyOn(killer:Player,toSquare:int): bool =
  if killer.hasPieceOn(toSquare) or 
    killer.cash-(killer.removedPieces*piecePrice) <= startCash div 2: false 
  else:
    let 
      hostileFireAdviced = killer.hostileFireAdviced(moveSelection.fromSquare,toSquare)
      agroKill = rand(1..100) <= killer.agro div 5
      planChance = players[singlePiece.playerNr].cashChanceOn(toSquare,blueDeck)
      barKill = toSquare.isBar and (
        killer.nrOfPiecesOnBars > 0 or players.len < 3
      )
    (planChance > 0.1*(players.len.toFloat/2)) or 
    agroKill or barKill or hostileFireAdviced

proc aiRemovePiece(move:Move):bool =
  turnPlayer.hypotheticalInit.friendlyFireAdviced(move) or 
  turnPlayer.shouldKillEnemyOn move.toSquare

proc aiKillDecision =
  killPieceAndMove(
    if aiRemovePiece getMove(): 
      "Yes" 
    else: 
      "No"
  )

proc hasKillablePiece(square:int):bool =
  singlePiece = players.singlePieceOn square
  singlePiece.playerNr != -1 and canKillPieceOn square

proc movePiece(square:int) =
  moveSelection.toSquare = square
  if square.hasKillablePiece:
    if turnPlayer.kind == Human:
      startKillDialog square
    else: aiKillDecision()
  elif statGame: 
    move()
  else: moveAnimation

proc endGame =
  if turnPlayer.kind == Human:
    recordTurnReport()
  setupNewGame()
  soundToPlay.setLen 0

proc startNewGame* =
  initTurnReport()
  turnReports.setLen 0
  inc turn.nr
  players = newPlayers()
  setConfigStateTo StartGame
  reportUpdateReset()
  gameWon = false

proc nextTurn =
  playSound "page-flip-2"
  updateTurnReportCards(turnPlayer.discardCards blueDeck, Discarded)
  recordTurnReport()
  nextPlayerTurn()
  initTurnReport()
  if anyHuman players: 
    showMenu false
  playCashPlansTo blueDeck

proc nextGameState* =
  if turnPlayer.cash >= cashToWin: 
    endGame()
  else:
    if turn.nr == 0: 
      startNewGame()
    else: 
      nextTurn()
    if statGame: rollDice()
    else: startDiceRoll()
  playSound "carhorn-1"

template phaseIs*:untyped = phase

proc drawCards =
  playCashPlansTo blueDeck
  while turn.undrawnBlues > 0:
    drawCardFrom blueDeck
    playCashPlansTo blueDeck
  hypo.pieces = turnPlayer.pieces
  hypo.cards = turnPlayer.sortBlues
  phase = Reroll

proc reroll(hypothetical:Hypothetic):bool =
  if isDouble():
    if bestDiceMoves.len == 0: 
      bestDiceMoves = hypothetical.bestDiceMoves()
    bestDiceMoves[0..4].anyIt diceRoll[1].ord == it.die
  else: false

proc bestDieMove(dice:openArray[int]):Move =
  var dieIndex:array[2,int]
  let bestDice = bestDiceMoves.mapIt(it.die)
  for i in 0..dice.high:
    dieIndex[i] = bestDice.find dice[i]
  bestDiceMoves[max dieIndex]

func cashTotal(hypothetical:Hypothetic,move:Move):int =
  let cashReward = hypothetical.player(move).plans.cashable.mapIt(it.cash).sum
  cashReward+hypothetical.cash-(if move.fromSquare == 0: piecePrice else: 0)

proc dieIndex(die:int):int =
  for i,move in bestDiceMoves:
    if die == move.die:
      return i
  -1

proc winningMove(hypothetical:Hypothetic,dice:openArray[int]):Move =
  if bestDiceMoves.len > 0: 
    for die in dice.deduplicate:
      if (let idx = dieIndex die; idx != -1):
        if hypothetical.cashTotal(bestDiceMoves[idx]) >= cashToWin:
          return bestDiceMoves[idx]
  else: 
    for move in hypothetical.moves dice:
      if hypothetical.cashTotal(move) >= cashToWin: 
        return move
  result.pieceNr = -1

# proc winningMove(hypothetical:Hypothetic,dice:openArray[int]):Move =
#   if bestDiceMoves.len > 0: 
#     for i,move in bestDiceMoves:
#       if move.die == dice[0] and hypothetical.cashTotal(move) >= cashToWin:
#         return bestDiceMoves[i]
#   else: 
#     for move in hypothetical.movesResolvedWith dice:
#       if hypothetical.cashTotal(move) >= cashToWin: 
#         return move
#   result.pieceNr = -1

proc aiMove(hypothetical:Hypothetic,dice:openArray[int]):(bool,Move) =
  if(let winMove = hypothetical.winningMove dice; winMove.pieceNr != -1):
    (true,winMove) 
  else: (
    false,
    if bestDiceMoves.len > 0: 
      bestDieMove dice 
    else: hypothetical.move dice
  )

func betterThan(move:Move,hypothetical:Hypothetic):bool =
  move.eval.toFloat >= hypothetical.evalPos().toFloat*0.85

proc moveAi =
  let (isWinningMove,move) = hypo.aiMove([diceRoll[1].ord,diceRoll[2].ord])
  if isWinningMove or move.betterThan hypo:
    if turnPlayer.skipped > 0: 
      turnPlayer.skipped = 0
    moveSelection.fromSquare = move.fromSquare
    movePiece move.toSquare
  else:
    inc turnPlayer.skipped
    echo $turnPlayer.color," skips move"
    echo "turn nr: ",turnPlayer.turnNr
    echo "dice: ",diceRoll
    echo "pieces: ",turnPlayer.pieces
    echo "cards: ",turnPlayer.hand.mapIt it.title&"/"&($it.squares.required)
    echo "covered: ",turnPlayer.hand.filterIt(turnPlayer.pieces.toSeq.covers it).mapIt it.title
    # echo "covers: ",turnPlayer.hand.mapIt(turnPlayer.pieces.covers it.squares.required)
  phase = PostMove

proc startTurn = 
  # if statGame:
  #   echo ""
  #   echo "game nr: ",gameStats.len
  #   echo $turnPlayer.color," start turn: ",turn.nr
  hypo = hypotheticalInit(turnPlayer)
  bestDiceMoves.setLen 0
  phase = Draw

proc rerollPhase =
  if statGame:
    if not diceReroll.isPausing or hypo.reroll:
      rollDice()
      diceReroll.isPausing = true
    else:
      diceReroll.isPausing = false
      phase = AiMove
  elif diceReroll.isPausing and cpuTime() - diceReroll.pauseStartTime >= 0.25:
    diceReroll.isPausing = false
    startDiceRoll()
  elif not diceReroll.isPausing:
    if hypo.reroll: 
      diceReroll.isPausing = true
      diceReroll.pauseStartTime = cpuTime()
    else: phase = AiMove

proc postMovePhase =
  moveSelection.fromSquare = -1
  drawCards()
  phase = EndTurn

proc endTurn* = 
  phase = Await
  nextGameState()

proc endTurnPhase =
  if autoEndTurn and turnPlayer.cash < cashToWin:
    endTurn()
  else: showMenu true

proc aiTakeTurnPhase*() =
  case phase
  of Await: startTurn()
  of Draw: drawCards()
  of Reroll: rerollPhase()
  of AiMove: moveAi()
  of PostMove: postMovePhase()
  of EndTurn: endTurnPhase()
  turnPlayer.update = true
