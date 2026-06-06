from math import sum
import game
import stat
import eval
import sequtils
import random
import times
import macros

macro injectTemplates*(params:varargs[untyped]): untyped =
  proc templ(param:string):NimNode =
    let node = ident(param)
    case param:
      of "turnPlayer": 
        quote do:
          template `node`: untyped = localGame.players[localGame.turn.playerNr]
      of "turn": 
        quote do:
          template `node`: untyped = localGame.turn
      of "players": 
        quote do: 
          template `node`: untyped = localGame.players
      of "diceRoll": 
        quote do: 
          template `node`: untyped = localGame.diceRoll
      of "blueDeck": 
        quote do: 
          template `node`: untyped = localGame.blueDeck
      of "playerKinds": 
        quote do: 
          template `node`: untyped = localGame.playerKinds
      of "turnReports": 
        quote do: 
          template `node`: untyped = localPlay.report.turns
      of "report": 
        quote do: 
          template `node`: untyped = localPlay.report
      of "eval": 
        quote do: 
          template `node`: untyped = localPlay.eval
      of "diceMoves": 
        quote do: 
          template `node`: untyped = localPlay.eval.diceMoves
      of "hypo": 
        quote do: 
          template `node`: untyped = localPlay.eval.hypothetical
      of "killPiece": 
        quote do: 
          template `node`: untyped = localPlay.killPiece
      of "diceReroll": 
        quote do: 
          template `node`: untyped = localPlay.diceReroll
      of "selectedMove": 
        quote do: 
          template `node`: untyped = localPlay.selectedMove
      of "turnReport": 
        quote do:
          template `node`: untyped = localPlay.report.turn
      else:nil
  var body = newTree(nnkStmtList)
  for param in params:
    let node = param.strVal.templ
    if node != nil: body.add(node)
    else: echo "no such template: ",param.strVal
  result = body
  echo result.repr

type
  Phase* = enum Await,Draw,Reroll,AiMove,PostMove,EndTurn
  DiceReroll = tuple[isPausing:bool,pauseStartTime:float]
  ConfigState* = enum StartGame,SetupGame,GameWon
  Play* = object
    playId:string
    diceReroll:DiceReroll
    selectedMove:Move
    killPiece:KillablePiece
    eval:Eval
    report*:Report

var
  mainPlay*:Play
  # killPiece:KillablePiece
  # hypo:Hypothetic
  # diceReroll:DiceReroll
  # diceMoves:DiceMoves
  # selectedMove*:Move

  # Interface controls
  updatePieces*:proc()
  updateUndrawnBlues*:proc()
  updateKillMatrix*:proc()
  menuControl*:proc(show:bool)
  rollTheDice*:proc()
  
  runMoveAnimation*:proc(move:Move)
  runSelectBar*:proc(dialogMoves:seq[Move])
  killDialog*:proc(square:int)
  configState*:proc(config:ConfigState)

  # Interface flags
  updateKeybar*:bool
  gameWon*:bool
  statGame*:bool
  autoEndTurn* = true

  # Interface state
  soundToPlay*:seq[string]
  phase*:Phase

template diceReroll:untyped = mainPlay.diceReroll
template killPiece:untyped = mainPlay.killPiece
template hypo:untyped = mainPlay.eval.hypothetical
template diceMoves:untyped = mainPlay.eval.diceMoves
template eval:untyped = mainPlay.eval
template selectedMove*:untyped = mainPlay.selectedMove
template report*:untyped = mainPlay.report
template turnReport*:untyped = mainPlay.report.turn
template turnReports*:untyped = mainPlay.report.turns

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

template moveAnimation(move:Move) =
  if runMoveAnimation != nil:
    move.runMoveAnimation()

template playSound(s:string) =
  if not statGame:
    soundToPlay.add s

template killMatrixUpdate =
  if updateKillMatrix != nil:
    updateKillMatrix()

template undrawnBluesUpdate =
  if updateUndrawnBlues != nil:
    updateUndrawnBlues()

template updatePiecesPainter =
  if updatePieces != nil:
    updatePieces()

proc playCashPlans* =
  # injectTemplates(turnPlayer,turn)
  let
    initialCash = turnPlayer.cash
    cashedPlans = turnPlayer.cashInPlansTo blueDeck
  if cashedPlans.len > 0:
    turnReport.update(cashedPlans,Cashed)
    turnPlayer.update = true
    playSound "coins-to-table-2"
    if initialCash < cashToWin and turnPlayer.cash >= cashToWin:
      setConfigStateTo GameWon
      if not verbose:
        echo "game won : ",turnPlayer.cash," cash, in ",turnPlayer.turnNr," turns"
      gameWon = true
    else:
      undrawnBluesUpdate()
      turn.undrawnBlues += cashedPlans.mapIt(
        if it.squares.required.len == 1: 2
        elif it.squares.required.len < 4: 1
        else: 1
      ).sum

proc playNews =
  let news = turnPlayer.hand[^1]
  turnPlayer.hand.playTo(blueDeck,turnPlayer.hand.high)
  for (playerNr,pieceNr) in players.piecesOn news.moveSquares[0]:
    players[playerNr].pieces[pieceNr] = news.moveSquares[1]
  if news.moveSquares[1] == 0: playSound "electricity"
  else: playSound "driveBy"
  updatePiecesPainter()
  playCashPlans()

proc playEvent()
proc playDejaVue =
  playSound "SCARYBEL-1"
  turnPlayer.hand.add blueDeck.discardPile[^2]
  delete(blueDeck.discardPile,blueDeck.discardPile.high - 1)
  let blue = turnPlayer.hand[^1]
  blueDeck.lastDrawn = blue.title
  turnReport.update(blue,Drawn)
  var action = Played
  if turnPlayer.hand.len > 0:
    case blue.cardKind:
      of Event: playEvent()
      of News: playNews()
      else: action = Drawn
  if action == Played:
    turnReport.update(blue,Played)

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
  turnPlayer.hand.playTo(blueDeck,turnPlayer.hand.high)
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
      if blueDeck.discardPile.len > 1:
        playDejaVue()
    else: event.barMove
  playCashPlans()

proc drawCard* =
  turnPlayer.hand.drawFrom blueDeck
  var action = Played
  let blue = turnPlayer.hand[^1]
  turnReport.update(blue,Drawn)
  case blue.cardKind:
    of Event: playEvent()
    of News: playNews()
    else: action = Drawn
  if action == Played:
    turnReport.update(blue,Played)
  dec turn.undrawnBlues
  undrawnBluesUpdate()
  turnPlayer.update = true
  playSound "page-flip-2"
  playCashPlans()

proc move(localGame:var Game = mainGame,localPlay:var Play = mainPlay) =
# proc move =
  injectTemplates(turnPlayer,selectedMove,turn,turnReport)
  selectedMove.moveAnimation()
  turnReport.update selectedMove
  turnPlayer.pieces[selectedMove.pieceNr] = selectedMove.toSquare
  if selectedMove.fromSquare == 0:
    turnPlayer.cash -= piecePrice
  playCashPlans()
  if not statGame:
    turnPlayer.hand = turnPlayer.sortBlues
  turnPlayer.update = true
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
    turnReport.update players[killPiece.playerNr].color
    playSound "Gunshot"
    playSound "Deanscream-2"
  move()

proc aiShouldKillPiece:bool =
  if turn.playerNr == killPiece.playerNr:
    hypo.ownKillBest selectedMove
  else: turnPlayer.shouldKillEnemyOn selectedMove

proc movePiece =
  killPiece = players.killablePieceOn selectedMove.toSquare
  if killPiece.playerNr == -1: 
    move()
  elif turnPlayer.kind == Human:
    startKillDialog selectedMove.toSquare
  else: decideKillAndMove(
    if aiShouldKillPiece(): "Yes" else: "No"
  )

proc setupGame* =
  turn = (0,0,false,0)
  blueDeck.resetDeck
  players = newGameSetupPlayers(playerKinds)
  setConfigStateTo SetupGame

proc endGame* =
  report.recordTurn()
  setupGame()
  soundToPlay.setLen 0

proc startGame* =
  inc turn.nr
  players = players.newGamePlayers
  players[0].turnNr = 1
  report.turns.setLen 0
  turnReport.init()
  setConfigStateTo StartGame
  gameWon = false

proc nextPlayerTurn =
  turn.diceMoved = false
  if turn.playerNr == players.high:
    inc turn.nr
    turn.playerNr = players.low
  else: inc turn.playerNr
  turnPlayer.turnNr = turn.nr
  turnPlayer.update = true
  turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars
  blueDeck.lastDrawn = ""
 
proc nextTurn =
  playSound "page-flip-2"
  report.turn.update(turnPlayer.discardCards blueDeck, Discarded)
  turnPlayer.update = true
  report.recordTurn()
  nextPlayerTurn()
  report.turn.init()
  if anyHuman players:
    showMenu false

proc nextGameState* =
  if turnPlayer.cash >= cashToWin:
    endGame()
  else:
    if turn.nr == 0:
      echo "start game"
      startGame()
    else:
      nextTurn()
    if statGame: diceRoll.rollDice()
    else: startDiceRoll()
  playSound "carhorn-1"

proc aiStartTurn =
  if turnPlayer.legalPiecesCount == 0:
    echo $turnPlayer.color&" has no legal pieces and has left the game in shame"
    phase = EndTurn
  else:
    diceMoves[^1].moves.setLen 0
    playCashPlans()
    if turn.undrawnBlues == 0: 
      hypo = hypotheticalInit(turnPlayer)
      phase = Reroll
    else: phase = Draw

proc aiDraw =
  while turn.undrawnBlues > 0:
    drawCard()
    playCashPlans()
  if phase != PostMove:
    hypo = turnPlayer.hypotheticalInit
  phase = Reroll

proc aiReroll =
  if statGame:
    if not diceReroll.isPausing or eval.aiShouldReroll diceRoll:
      diceRoll.rollDice()
      report.turn.update diceRoll
      diceReroll.isPausing = true # appropriating an existing flag - don't EVER do that ;-)
    else:
      diceReroll.isPausing = false
      phase = AiMove
  elif diceReroll.isPausing and cpuTime() - diceReroll.pauseStartTime >= 0.25:
    diceReroll.isPausing = false
    startDiceRoll()
  elif not diceReroll.isPausing:
    report.turn.update diceRoll
    if eval.aiShouldReroll diceRoll:
      diceReroll.isPausing = true
      diceReroll.pauseStartTime = cpuTime()
    else: phase = AiMove

proc aiMove =
  if hypo.legalPieces.len > 0:
    selectedMove = eval.bestMove diceRoll
    if selectedMove.pieceNr > -1: 
      movePiece()
  else: echo $turnPlayer.color&" has no pieces to move"
  phase = PostMove

proc aiPostMove =
  if turn.undrawnBlues > 0:
    aiDraw()
  if turnPlayer.hand.len > 3:
    turnPlayer.hand = turnPlayer.sortBlues
  phase = EndTurn

proc endTurn* =
  phase = Await
  nextGameState()

proc aiEndTurn =
  if autoEndTurn and turnPlayer.cash < cashToWin:
    endTurn()
  else: showMenu true

proc aiTakeTurn*() =
  case phase
  of Await: aiStartTurn()
  of Draw: aiDraw()
  of Reroll: aiReroll()
  of AiMove: aiMove()
  of PostMove:aiPostMove()
  of EndTurn: aiEndTurn()
  turnPlayer.update = true

