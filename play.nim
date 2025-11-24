from math import sum
import misc
import game
import sequtils
import eval
import random
import times

type
  Phase* = enum Await,Draw,Reroll,AiMove,PostMove,EndTurn
  DiceReroll = tuple[isPausing:bool,pauseStartTime:float]
  ConfigState* = enum StartGame,SetupGame,GameWon
  SinglePiece = tuple[playerNr,pieceNr:int]
  TurnReport* = object
    turnNr*:int
    player*:tuple[color:PlayerColor,kind:PlayerKind]
    diceRolls*:seq[Dice]
    moves*:seq[Move]
    cards*:tuple[drawn,played,cashed,discarded,hand:seq[BlueCard]]
    kills*:seq[PlayerColor]
    cash*:int
    agro*:int

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
  runSelectBar*:proc(dialogMoves:seq[Move])
  killDialog*:proc(square:int)

  # Interface flags
  recordStats* = true
  updateKeybar*:bool
  gameWon*:bool
  statGame*:bool
  autoEndTurn* = true

  # Interface state
  configState*:proc(config:ConfigState)
  soundToPlay*:seq[string]
  phase*:Phase
  turnReports*:seq[TurnReport]
  turnReport*:TurnReport

  # Internals
  killPiece:SinglePiece
  hypo:Hypothetic
  diceReroll:DiceReroll
  bestDiceMoves:seq[Move]

template setConfigStateTo(config:ConfigState) =
  if configState != nil:
    configState config

template startKillDialog(square:int) =
  if killDialog != nil:
    killDialog square

template selectBar(dialogMoves:seq[Move]) =
  if runSelectBar != nil:
    runSelectBar dialogMoves

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
  turnReport.player.color = turnPlayer.color
  turnReport.player.kind = turnPlayer.kind
  initTurnReportBatches()

proc updateTurnReport*[T](item:T) =
  execIf recordStats:
    when typeOf(T) is Move: 
      turnReport.moves.add item
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

proc recordTurnReport* =
  if recordStats:
    turnReport.cards.hand = turnPlayer.hand
    turnReport.cash = turnPlayer.cash
    turnReport.agro = turnPlayer.agro
    turnReports.add turnReport

proc barToMassacre(player:Player,allPlayers:seq[Player]):int =
  if (let playerBars = turnPlayer.piecesOnBars; playerBars.len > 0):
    let 
      maxPieces = playerBars.mapIt(allPlayers.nrOfPiecesOn it).max
      barsWithMaxPieces = playerBars.filterIt(allPlayers.nrOfPiecesOn(it) == maxPieces)
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
    cashedPlans = turnPlayer.cashInPlansTo deck
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

proc barMove(moveEvent:BlueCard):bool =
  let dialogBarMoves = turnPlayer.eventMovesEval moveEvent
  if dialogBarMoves.len > 0:
    if dialogBarMoves.len == 1 or turnPlayer.kind == Computer:
      moveSelection.event = true
      moveSelection.fromSquare = dialogBarMoves[0].fromSquare
      moveSelection.toSquare = dialogBarMoves[0].toSquare
      return true
    else: selectBar dialogBarMoves

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

proc movePiece*(square:int)
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
  moveAnimation()
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

proc decideKillAndMove*(confirmedKill:string) =
  if confirmedKill == "Yes":
    players[killPiece.playerNr].pieces[killPiece.pieceNr] = 0
    updateTurnReport players[killPiece.playerNr].color
    playSound "Gunshot"
    playSound "Deanscream-2"
  move()

proc wantsNoProtectionAfter(player:Player,move:Move):bool =
  var hypoPlayer = player
  hypoPlayer.pieces[move.pieceNr] = move.toSquare
  hypoPlayer.hand = hypoPlayer.plans.notCashable
  var hypo = hypoPlayer.hypotheticalInit
  let noKillEval = hypo.evalPos
  hypo.pieces[move.pieceNr] = 0
  let killEval = hypo.evalPos
  killEval > noKillEval

proc shouldKillEnemyOn(player:Player,move:Move):bool =
  player.cash-(player.nrOfRemovedPieces*piecePrice) >= startCash div 2 and 
  not player.hasPieceOn(move.toSquare) and (
    (move.toSquare.isBar and (player.nrOfPiecesOnBars > 0 or players.len < 3)) or
    rand(0..99) <= player.agro or
    player.wantsNoProtectionAfter move
  )

proc aiRemovesPiece(move:Move):bool =
  turnPlayer.shouldKillEnemyOn(move) or
  turnPlayer.hypotheticalInit.friendlyFireAdviced(move)

proc movePiece(square:int) =
  moveSelection.toSquare = square
  killPiece = players.singlePieceOn square
  if killPiece.playerNr != -1 and canKillPieceOn square:
    if turnPlayer.kind == Human: 
      startKillDialog square
    else: decideKillAndMove(
      if aiRemovesPiece(getMove()): "Yes" 
      else: "No"
    )
  else: move()

proc setupNewGame* =
  turn = (0,0,false,0)
  blueDeck.resetDeck
  players = newDefaultPlayers()
  setConfigStateTo SetupGame

proc endGame* =
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

proc aiStartTurn = 
  hypo = hypotheticalInit(turnPlayer)
  bestDiceMoves.setLen 0
  if hypo.legalPieces.len == 0:
    echo $turnPlayer.color&" has no legal pieces and has left the game in shame"
    phase = EndTurn
  else: phase = Draw

proc aiDrawCards =
  playCashPlansTo blueDeck
  while turn.undrawnBlues > 0:
    drawCardFrom blueDeck
    playCashPlansTo blueDeck
  hypo = turnPlayer.hypotheticalInit
  phase = Reroll

proc reroll(hypothetical:Hypothetic):bool =
  if isDouble():
    if bestDiceMoves.len == 0: 
      bestDiceMoves = hypothetical.bestDiceMoves()
    bestDiceMoves[0..4].anyIt diceRoll[1].ord == it.die
  else: false

proc aiRerollPhase =
  if statGame:
    if not diceReroll.isPausing or hypo.reroll:
      rollDice()
      diceReroll.isPausing = true # appropriating an existing flag - don't EVER do that ;-)
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

proc bestDieMove(dice:openArray[int]):Move =
  var dieIndex:array[2,int]
  let bestDice = bestDiceMoves.mapIt(it.die)
  for i in 0..dice.high:
    dieIndex[i] = bestDice.find dice[i]
  bestDiceMoves[max dieIndex]

func winsOn(player:Player,move:Move):bool =
  var hypoPlayer = player
  hypoPlayer.pieces[move.pieceNr] = move.toSquare
  let cashReward = hypoPlayer.plans.cashable.mapIt(it.cash).sum
  cashReward+player.cash-(if move.fromSquare == 0: piecePrice else: 0) >= cashToWin

proc winningMove(hypothetical:Hypothetic,dice:openArray[int]):Move =
  for move in hypothetical.moves dice:
    if turnPlayer.winsOn(move): 
      return move
  result.pieceNr = -1

proc bestMove(hypothetical:Hypothetic,dice:openArray[int]):(bool,Move) =
  if (let winMove = hypothetical.winningMove dice; winMove.pieceNr != -1):
    (true,winMove) 
  else: (
    false,
    if bestDiceMoves.len > 0: 
      bestDieMove dice 
    else: hypothetical.move dice
  )

proc moveAi =
  let (isWinningMove,move) = hypo.bestMove([diceRoll[1].ord,diceRoll[2].ord])
  if isWinningMove or move.eval > hypo.evalPos:
    moveSelection.fromSquare = move.fromSquare
    movePiece move.toSquare
  else:
    echo $turnPlayer.color," skips move"
    # echo "turn nr: ",turnPlayer.turnNr
    # echo "dice: ",diceRoll
    # echo "pieces: ",turnPlayer.pieces
    # echo "cards: ",turnPlayer.hand.mapIt it.title&"/"&($it.squares.required)
  phase = PostMove

proc postMovePhase =
  moveSelection.fromSquare = -1
  aiDrawCards()
  phase = EndTurn

proc endTurn* = 
  phase = Await
  nextGameState()

proc endTurnPhase =
  if autoEndTurn and turnPlayer.cash < cashToWin:
    endTurn()
  else: showMenu true

proc aiTakeTurn*() =
  case phase
  of Await: aiStartTurn()
  of Draw: aiDrawCards()
  of Reroll: aiRerollPhase()
  of AiMove: moveAi()
  of PostMove: postMovePhase()
  of EndTurn: endTurnPhase()
  turnPlayer.update = true
