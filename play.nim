from math import sum
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
  runMoveAnimation*:proc(move:Move)
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
  diceMoves:DiceMoves

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

template moveAnimation(move:Move) =
  if runMoveAnimation != nil:
    move.runMoveAnimation()

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
  turnReport.turnNr = turnPlayer.turnNr
  turnReport.player.color = turnPlayer.color
  turnReport.player.kind = turnPlayer.kind
  initTurnReportBatches()

proc updateTurnReport*[T](item:T) =
  if recordStats:
    when typeOf(T) is Move: 
      turnReport.moves.add item
    when typeof(T) is PlayerColor: 
      turnReport.kills.add item
      killMatrixUpdate()
    updateTurnReport()

proc updateTurnReportCards*(blues:seq[BlueCard],playedCard:PlayedCard) =
  if recordStats:
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

proc playMassacre =
  if (let playerBars = turnPlayer.piecesOnBars.deduplicate; playerBars.len > 0):
    let
      allPlayerPiecesOnBars = playerBars.mapIt players.nrOfPiecesOn it
      maxPieces = allPlayerPiecesOnBars.max
      playerBarsAndPieces = zip(playerBars,allPlayerPiecesOnBars)
      barsWithMaxPieces = playerBarsAndPieces.filterIt(it[1] == maxPieces).mapIt(it[0])
      chosenBar = barsWithMaxPieces[rand 0..barsWithMaxPieces.high]
    for (playerNr,pieceNr) in players.piecesOn chosenBar:
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

proc movePiece*()
proc barMove(moveEvent:BlueCard) =
  let barMoves = turnPlayer.eventMovesEval moveEvent
  if barMoves.len > 0:
    if barMoves.len == 1 or turnPlayer.kind == Computer:
      selectedMove = barMoves[0]
      movePiece()
    else: selectBar barMoves

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
    else: event.barMove
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

proc move =
  selectedMove.moveAnimation()
  updateTurnReport selectedMove
  turnPlayer.pieces[selectedMove.pieceNr] = selectedMove.toSquare
  if selectedMove.fromSquare == 0: 
    turnPlayer.cash -= piecePrice
  playCashPlansTo blueDeck
  if not statGame:
    turnPlayer.hand = turnPlayer.sortBlues
  turnPlayer.update = true
  moveSelection.fromSquare = -1
  updatePiecesPainter()
  updateKeybar = true
  playSound "driveBy"
  if selectedMove.toSquare.isBar:
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
  hypoPlayer.hand = hypoPlayer.pieces.plans(hypoPlayer.hand).notCashable
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

proc aiShouldRemovePiece(player:Player,move:Move):bool =
  player.shouldKillEnemyOn(move) or
  player.hypotheticalInit.friendlyFireAdviced(move)

proc movePiece =
  killPiece = players.singlePieceOn selectedMove.toSquare
  if killPiece.playerNr != -1 and canKillPieceOn selectedMove.toSquare:
    if turnPlayer.kind == Human: 
      startKillDialog selectedMove.toSquare
    else: 
      decideKillAndMove(
        if turnPlayer.aiShouldRemovePiece selectedMove: "Yes" else: "No"
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
  inc turn.nr
  players = newPlayers()
  players[0].turnNr = 1
  turnReports.setLen 0
  initTurnReport()
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
  if diceMoves.hasMoves:
    diceMoves.resetMoves
  if hypo.legalPieces.len == 0:
  # if hypo.legalPieces.allIt it == -1:
    echo $turnPlayer.color&" has no legal pieces and has left the game in shame"
    phase = EndTurn
  else:phase = Draw

proc aiDrawCards =
  playCashPlansTo blueDeck
  while turn.undrawnBlues > 0:
    drawCardFrom blueDeck
    playCashPlansTo blueDeck
  hypo = turnPlayer.hypotheticalInit
  phase = Reroll

proc reroll(hypothetical:Hypothetic):bool =
  if isDouble():
    if diceMoves.hasMoves: 
      diceMoves = hypothetical.allDiceMoves()
    not diceRoll[^1].isBestIn diceMoves
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

proc moveAi =
  if hypo.legalPieces.len > 0:
    let (isWinningMove,move) = hypo.bestMove(diceRoll,diceMoves)
    if isWinningMove or move.eval > hypo.evalPos:
      # moveSelection.fromSquare = move.fromSquare
      selectedMove = move
      movePiece()
    phase = PostMove
  else:
    echo $turnPlayer.color&" has no pieces to move"
    phase = EndTurn

proc postMovePhase =
  moveSelection.fromSquare = -1
  aiDrawCards()
  turnPlayer.hand = turnPlayer.sortBlues
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
