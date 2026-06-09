from math import sum
import game
import stat
import eval
import sequtils
import random
import times
import macros

type
  Phase* = enum Await,Draw,Reroll,AiMove,PostMove,EndTurn
  DiceReroll = tuple[isPausing:bool,pauseStartTime:float]
  ConfigState* = enum StartGame,SetupGame,GameWon
  Play* = ref object of Game
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

# macro injectGamePlayTemplates(params:varargs[untyped]): untyped =
#   proc templ(param:string):NimNode =
#     let node = ident(param)
#     case param:
#       of "turnPlayer": 
#         quote do:
#           template `node`: untyped = gamePlay.players[gamePlay.turn.playerNr]
#       of "turn": 
#         quote do:
#           template `node`: untyped = gamePlay.turn
#       of "players": 
#         quote do: 
#           template `node`: untyped = gamePlay.players
#       of "diceRoll": 
#         quote do: 
#           template `node`: untyped = gamePlay.diceRoll
#       of "blueDeck": 
#         quote do: 
#           template `node`: untyped = gamePlay.blueDeck
#       of "playerKinds": 
#         quote do: 
#           template `node`: untyped = gamePlay.playerKinds
#       of "turnReports": 
#         quote do: 
#           template `node`: untyped = gamePlay.report.turns
#       of "report": 
#         quote do: 
#           template `node`: untyped = gamePlay.report
#       of "eval": 
#         quote do: 
#           template `node`: untyped = gamePlay.eval
#       of "diceMoves": 
#         quote do: 
#           template `node`: untyped = gamePlay.eval.diceMoves
#       of "hypo": 
#         quote do: 
#           template `node`: untyped = gamePlay.eval.hypothetical
#       of "killPiece": 
#         quote do: 
#           template `node`: untyped = gamePlay.killPiece
#       of "diceReroll": 
#         quote do: 
#           template `node`: untyped = gamePlay.diceReroll
#       of "selectedMove": 
#         quote do: 
#           template `node`: untyped = gamePlay.selectedMove
#       of "turnReport": 
#         quote do:
#           template `node`: untyped = gamePlay.report.turn
#       else:nil
#   var body = newTree(nnkStmtList)
#   for param in params:
#     let node = param.strVal.templ
#     if node != nil: body.add(node)
#     else: echo "no such template: ",param.strVal
#   result = body
  # echo result.repr

import sets,hashes,strutils

macro injectTemplatesIfUsed(body:untyped):untyped =
  let holy = [
    ("players".toLower.hash,      quote do: gamePlay.players),
    ("diceRoll".toLower.hash,     quote do: gamePlay.diceRoll),
    ("blueDeck".toLower.hash,     quote do: gamePlay.blueDeck),
    ("playerKinds".toLower.hash,  quote do: gamePlay.playerKinds),
    ("turnReports".toLower.hash,  quote do: gamePlay.report.turns),
    ("report".toLower.hash,       quote do: gamePlay.report),
    ("eval".toLower.hash,         quote do: gamePlay.eval),
    ("diceMoves".toLower.hash,    quote do: gamePlay.eval.diceMoves),
    ("hypo".toLower.hash,         quote do: gamePlay.eval.hypothetical),
    ("killPiece".toLower.hash,    quote do: gamePlay.killPiece),
    ("diceReroll".toLower.hash,   quote do: gamePlay.diceReroll),
    ("selectedMove".toLower.hash, quote do: gamePlay.selectedMove),
    ("turnPlayer".toLower.hash,   quote do: gamePlay.players[gamePlay.turn.playerNr]),
    ("turn".toLower.hash,         quote do: gamePlay.turn),
    ("turnReport".toLower.hash,   quote do: gamePlay.report.turn)
  ]
  var 
    stmtList = newTree(nnkStmtList)
    generated = initHashSet[string]()
  proc templGen(templName:string):NimNode =
    let nodeHash = templName.toLower.hash
    for idx in 0..holy.high:
      if nodeHash == holy[idx][0]:
        let (name,body) = (ident(templName),holy[idx][1])
        return quote do: 
          template `name`:untyped = `body`
  proc scan(parent:NimNode) =
    if parent.kind == nnkIdent and not (parent.strVal in generated):
      if (let templ = templGen(parent.strVal); templ != nil):
        stmtList.add(templ)
        generated.incl(parent.strVal)
    for child in parent:scan(child)
  scan(body)
  stmtList.add(body)
  result = stmtList
  echo result.repr

proc playCashPlans*(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,turnReport,blueDeck,turn)
  injectTemplatesIfUsed:
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

proc playNews(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,blueDeck,players)
  injectTemplatesIfUsed:
    let news = turnPlayer.hand[^1]
    turnPlayer.hand.playTo(blueDeck,turnPlayer.hand.high)
    for (playerNr,pieceNr) in players.piecesOn news.moveSquares[0]:
      players[playerNr].pieces[pieceNr] = news.moveSquares[1]
    if news.moveSquares[1] == 0: playSound "electricity"
    else: playSound "driveBy"
    updatePiecesPainter()
    gamePlay.playCashPlans()

proc playEvent(gamePlay:Play = mainPlay)
proc playDejaVue(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,blueDeck,turnReport)
  injectTemplatesIfUsed:
    playSound "SCARYBEL-1"
    turnPlayer.hand.add blueDeck.discardPile[^2]
    delete(blueDeck.discardPile,blueDeck.discardPile.high - 1)
    let blue = turnPlayer.hand[^1]
    blueDeck.lastDrawn = blue.title
    turnReport.update(blue,Drawn)
    var action = Played
    if turnPlayer.hand.len > 0:
      case blue.cardKind:
        of Event: gamePlay.playEvent()
        of News: gamePlay.playNews()
        else: action = Drawn
    if action == Played:
      turnReport.update(blue,Played)

proc playMassacre(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,players)
  injectTemplatesIfUsed:
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

proc movePiece*(gamePlay:Play = mainPlay)
proc barMove(gamePlay:Play = mainPlay,moveEvent:BlueCard) =
  # injectGamePlayTemplates(turnPlayer,selectedMove)
  injectTemplatesIfUsed:
    let barMoves = players.eventMovesEval(turnPlayer,moveEvent)
    if barMoves.len > 0:
      if barMoves.len == 1 or turnPlayer.kind == Computer:
        selectedMove = barMoves[0]
        gamePlay.movePiece()
      else: selectBar barMoves

proc playEvent(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,turn,blueDeck)
  injectTemplatesIfUsed:
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
      of "Massacre": gamePlay.playMassacre()
      of "Deja vue":
        if blueDeck.discardPile.len > 1:
          gamePlay.playDejaVue()
      else: gamePlay.barMove event
    gamePlay.playCashPlans()

proc drawCard*(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,turn,turnReport,blueDeck)
  injectTemplatesIfUsed:
    turnPlayer.hand.drawFrom blueDeck
    var action = Played
    let blue = turnPlayer.hand[^1]
    turnReport.update(blue,Drawn)
    case blue.cardKind:
      of Event: gamePlay.playEvent()
      of News: gamePlay.playNews()
      else: action = Drawn
    if action == Played:
      turnReport.update(blue,Played)
    dec turn.undrawnBlues
    undrawnBluesUpdate()
    turnPlayer.update = true
    playSound "page-flip-2"
    gamePlay.playCashPlans()

proc move(gamePlay:Play = mainPlay) =
# proc move =
  # injectTemplatesIfUsed:
  # injectGamePlayTemplates(turnPlayer,selectedMove,turn,turnReport)
  # echo gamePlay.repr
  injectTemplatesIfUsed:
    selectedMove.moveAnimation()
    turnReport.update selectedMove
    turnPlayer.pieces[selectedMove.pieceNr] = selectedMove.toSquare
    if selectedMove.fromSquare == 0:
      turnPlayer.cash -= piecePrice
    gamePlay.playCashPlans()
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

proc decideKillAndMove*(gamePlay:Play = mainPlay,confirmedKill:string) =
  # injectGamePlayTemplates(players,turnReport,killPiece)
  injectTemplatesIfUsed:
    if confirmedKill == "Yes":
      players[killPiece.playerNr].pieces[killPiece.pieceNr] = 0
      turnReport.update players[killPiece.playerNr].color
      playSound "Gunshot"
      playSound "Deanscream-2"
    gamePlay.move()

proc aiShouldKillPiece(gamePlay:Play = mainPlay):bool =
  # injectTemplatesIfUsed:
  # injectGamePlayTemplates(turnPlayer,killPiece,hypo,selectedMove,turn)
  injectTemplatesIfUsed:
    if turn.playerNr == killPiece.playerNr:
      hypo.ownKillBest selectedMove
    else: players.shouldKillEnemyOn(turnPlayer,selectedMove)

proc movePiece(gamePlay:Play = mainPlay) =
  # echo gamePlay.repr
  # injectTemplatesIfUsed:
  # injectGamePlayTemplates(turnPlayer,players,killPiece,selectedMove)
  injectTemplatesIfUsed:
    killPiece = players.killablePieceOn selectedMove.toSquare
    if killPiece.playerNr == -1: 
      gamePlay.move()
    elif turnPlayer.kind == Human:
      startKillDialog selectedMove.toSquare
    else: gamePlay.decideKillAndMove(
      if gamePlay.aiShouldKillPiece(): "Yes" else: "No"
    )
 
proc setupGame*(gamePlay:Play = mainPlay) =
  echo gamePlay.gameId
  injectTemplatesIfUsed:
  # injectGamePlayTemplates(turn,players,blueDeck,playerKinds)
    turn = (0,0,false,0)
    blueDeck.resetDeck
    players = newGameSetupPlayers(playerKinds)
    setConfigStateTo SetupGame

proc endGame*(gamePlay:Play = mainPlay) =
  injectTemplatesIfUsed:
  # injectGamePlayTemplates(report)
    report.recordTurn(turnPlayer)
    gamePlay.setupGame()
    soundToPlay.setLen 0

proc startGame*(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turn,players,turnReport,turnReports)
  injectTemplatesIfUsed:
    inc turn.nr
    players = players.newGamePlayers
    players[0].turnNr = 1
    turnReports.setLen 0
    turnReport.init(turnPlayer)
    setConfigStateTo StartGame
    gameWon = false

proc nextPlayerGetsTurn(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turn,players,blueDeck,turnPlayer)
  injectTemplatesIfUsed:
    turn.diceMoved = false
    if turn.playerNr == players.high:
      inc turn.nr
      turn.playerNr = players.low
    else: inc turn.playerNr
    turnPlayer.turnNr = turn.nr
    turnPlayer.update = true
    turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars
    blueDeck.lastDrawn = ""

proc nextTurn(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(players,turnReport,turnPlayer,blueDeck,report)
  injectTemplatesIfUsed:
    playSound "page-flip-2"
    turnReport.update(turnPlayer.discardCards blueDeck, Discarded)
    turnPlayer.update = true
    report.recordTurn(turnPlayer)
    gamePlay.nextPlayerGetsTurn()
    turnReport.init(turnPlayer)
    if anyHuman players:
      showMenu false

proc nextGameState*(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,diceRoll,turn)
  injectTemplatesIfUsed:
    if turnPlayer.cash >= cashToWin:
      gamePlay.endGame()
    else:
      if turn.nr == 0:
        gamePlay.startGame()
      else:
        gamePlay.nextTurn()
      if statGame: diceRoll.rollDice()
      else: startDiceRoll()
    playSound "carhorn-1"

proc aiStartTurn(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,turn,diceMoves,hypo)
  injectTemplatesIfUsed:
    if turnPlayer.legalPiecesCount == 0:
      echo $turnPlayer.color&" has no legal pieces and has left the game in shame"
      phase = EndTurn
    else:
      diceMoves[^1].moves.setLen 0
      gamePlay.playCashPlans()
      if turn.undrawnBlues == 0: 
        hypo = players.hypotheticalInit turnPlayer
        phase = Reroll
      else: phase = Draw

proc aiDraw(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,turn,hypo)
  injectTemplatesIfUsed:
    while turn.undrawnBlues > 0:
      gamePlay.drawCard()
      gamePlay.playCashPlans()
    if phase != PostMove:
      hypo = players.hypotheticalInit turnPlayer
    phase = Reroll

proc aiReroll(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(diceRoll,diceReroll,eval,turnReport)
  injectTemplatesIfUsed:
    if statGame:
      if not diceReroll.isPausing or eval.aiShouldReroll diceRoll:
        diceRoll.rollDice()
        turnReport.update diceRoll
        diceReroll.isPausing = true # appropriating an existing flag - don't EVER do that ;-)
      else:
        diceReroll.isPausing = false
        phase = AiMove
    elif diceReroll.isPausing and cpuTime() - diceReroll.pauseStartTime >= 0.25:
      diceReroll.isPausing = false
      startDiceRoll()
    elif not diceReroll.isPausing:
      turnReport.update diceRoll
      if eval.aiShouldReroll diceRoll:
        diceReroll.isPausing = true
        diceReroll.pauseStartTime = cpuTime()
      else: phase = AiMove

proc aiMove(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,diceRoll,eval,hypo,selectedMove)
  injectTemplatesIfUsed:
    if hypo.legalPieces.len > 0:
      selectedMove = eval.bestMove diceRoll
      if selectedMove.pieceNr > -1: 
        gamePlay.movePiece()
    else: echo $turnPlayer.color&" has no pieces to move"
    phase = PostMove

proc aiPostMove(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer,turn)
  injectTemplatesIfUsed:
    if turn.undrawnBlues > 0:
      gamePlay.aiDraw()
    if turnPlayer.hand.len > 3:
      turnPlayer.hand = turnPlayer.sortBlues
    phase = EndTurn

proc endTurn*(gamePlay:Play = mainPlay) =
  injectTemplatesIfUsed:
    phase = Await
    gamePlay.nextGameState()

proc aiEndTurn(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer)
  injectTemplatesIfUsed:
    if autoEndTurn and turnPlayer.cash < cashToWin:
      gamePlay.endTurn()
    else: showMenu true

proc aiTakeTurn*(gamePlay:Play = mainPlay) =
  # injectGamePlayTemplates(turnPlayer)
  injectTemplatesIfUsed:
    case phase
    of Await: gamePlay.aiStartTurn()
    of Draw: gamePlay.aiDraw()
    of Reroll: gamePlay.aiReroll()
    of AiMove: gamePlay.aiMove()
    of PostMove:gamePlay.aiPostMove()
    of EndTurn: gamePlay.aiEndTurn()
    turnPlayer.update = true

template initPlay* =
  mainPlay = new Play
  mainGame = mainPlay
