from math import sum
import game
import sequtils
import eval
import reports
import random
import strutils
import times
import sugar

type
  ChangeMenuState* = enum MenuOn,MenuOff,NoAction
  ConfigState* = enum None,StartGame,SetupGame,GameWon,StatGame
  SinglePiece = tuple[playerNr,pieceNr:int]
  EventMoveFmt* = tuple[fromSquare,toSquare:string]

var
  singlePiece*:SinglePiece
  dialogBarMoves*:seq[Move]
  changeMenuState* = NoAction
  # turnOffMenu*:bool
  runMoveAnimation*:bool
  rollTheDice*:bool
  runSelectBar*:bool
  killDialogSquare* = -1
  updateKeybar*:bool
  updatePieces*:bool
  updateUndrawnBlues*:bool
  soundToPlay*:seq[string]
  configState* = None

template playSound(s:string) =
  soundToPlay.add s

proc setupNewGame* =
  configState = SetupGame
  turn = (0,0,false,0)
  blueDeck.resetDeck
  players = newDefaultPlayers()

func pieceOnSquare(player:Player,square:int):int =
  for i,piece in player.pieces:
    if piece == square: return i

proc barToMassacre(player:Player,players:seq[Player]):int =
  if (let playerBars = turnPlayer.onBars; playerBars.len > 0):
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
    updatePieces = true

proc playCashPlansTo*(deck:var Deck) =
  let
    initialCash = turnPlayer.cash
    cashedPlans = cashInPlansTo deck
  if cashedPlans.len > 0:
    updateTurnReportCards(cashedPlans,Cashed)
    turnPlayer.update = true
    playSound "coins-to-table-2"
    if initialCash < cashToWin and turnPlayer.cash >= cashToWin:
      configState = GameWon
      # writeGamestats()
      # playSound "applause-2"
      # setMenuTo NewGameMenu
      # updateKeybar = true
      # showMenu = true
    else:
      turn.undrawnBlues += cashedPlans.mapIt(
        if it.squares.required.len == 1: 2 else: 1
      ).sum
      updateUndrawnBlues = true

proc move*(square:int)
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
    move moveSelection.toSquare

proc barMove(moveEvent:BlueCard):bool =
  dialogBarMoves = turnPlayer.eventMovesEval moveEvent
  # echo dialogBarMoves.mapIt(it.eventMoveFmt).mapIt(it.fromSquare&"\n"&it.toSquare).join("\n")
  if dialogBarMoves.len > 0:
    if dialogBarMoves.len == 1 or turnPlayer.kind == Computer:
      moveSelection.event = true
      moveSelection.fromSquare = dialogBarMoves[0].fromSquare
      moveSelection.toSquare = dialogBarMoves[0].toSquare
      return true
    else: runSelectBar = true
      # selectBar()

proc playNews =
  updatePieces = true
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
    case turnPlayer.hand[^1].cardKind 
    of Event: playEvent()
    of News: playNews()
    else:discard

proc playEvent =
  let event = turnPlayer.hand[^1]
  turnPlayer.hand.playTo blueDeck,turnPlayer.hand.high
  case event.title
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
  elif barMove event: move moveSelection.toSquare
  playCashPlansTo blueDeck

proc drawCardFrom*(deck:var Deck) =
  turnPlayer.hand.drawFrom deck
  var action:PlayedCard = Played
  let blue = turnPlayer.hand[^1]
  case blue.cardKind
  of Event: playEvent()
  of News: playNews()
  else: action = Drawn
  updateTurnReportCards(@[blue],action)
  dec turn.undrawnBlues
  updateUndrawnBlues = true
  turnPlayer.update = true
  playSound "page-flip-2"

func singlePieceOn*(players:seq[Player],square:int):SinglePiece =
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
  updatePieces = true
  playSound "driveBy"
  if moveSelection.toSquare in bars:
    inc turn.undrawnBlues
    updateUndrawnBlues = true
    playSound "can-open-1"

proc killPieceAndMove*(confirmedKill:string) =
  if confirmedKill == "Yes":
    players[singlePiece.playerNr].pieces[singlePiece.pieceNr] = 0
    updateTurnReport players[singlePiece.playerNr].color
    playSound "Gunshot"
    playSound "Deanscream-2"
  if configState == StatGame: move()
  else: runMoveAnimation = true

proc hostileFireEval(player:Player,pieceNr,toSquare:int):int =
  var hypoPlayer = player
  hypoPlayer.pieces[pieceNr] = toSquare
  hypoPlayer.hand = hypoPlayer.plans.notCashable
  hypoPlayer.hypotheticalInit.evalPos

proc hostileFireAdviced*(player:Player,fromSquare,toSquare:int):bool =
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
      barKill = toSquare in bars and (
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

proc move*(square:int) =
  moveSelection.toSquare = square
  if square.hasKillablePiece:
    if turnPlayer.kind == Human:
      killDialogSquare = square
    else: aiKillDecision()
  elif configState == StatGame: 
    move()
  else: runMoveAnimation = true
    # animateMove()

proc endGame =
  if turnPlayer.kind == Human:
    recordTurnReport()
  setupNewGame()

proc startNewGame =
  configState = StartGame
  inc turn.nr
  players = newPlayers()
  resetReports()

proc nextTurn =
  playSound "page-flip-2"
  updateTurnReportCards(turnPlayer.discardCards blueDeck, Discarded)
  recordTurnReport()
  diceRolls.setLen 0
  nextPlayerTurn()
  initTurnReport()
  if anyHuman players: changeMenuState = MenuOff
  playCashPlansTo blueDeck

proc nextGameState* =
  if turnPlayer.cash >= cashToWin: 
    endGame()
  else:
    if turn.nr == 0: 
      startNewGame()
    else: 
      nextTurn()
    if configState == StatGame: rollDice()
    else: rollTheDice = true
    # startDiceRoll(if turnPlayer.kind == Human: humanRoll else: computerRoll)
  playSound "carhorn-1"

type
  Phase* = enum Await,Draw,Reroll,AiMove,PostMove,EndTurn
  DiceReroll = tuple[isPausing:bool,pauseStartTime:float]

var
  autoEndTurn* = true
  hypo:Hypothetic
  phase*:Phase
  diceReroll:DiceReroll

template phaseIs*:untyped = phase

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
  move.eval.toFloat >= hypothetical.evalPos().toFloat*0.85

proc moveAi =
  let (isWinningMove,move) = hypo.aiMove([diceRoll[1].ord,diceRoll[2].ord])
  if isWinningMove or move.betterThan hypo:
    if turnPlayer.skipped > 0: 
      turnPlayer.skipped = 0
    moveSelection.fromSquare = move.fromSquare
    move move.toSquare
  else:
    inc turnPlayer.skipped
    echo "ai skips move:"
    # echo "currentPosEval: ",currentPosEval
    # echo "moveEval: ",move.eval
  phase = PostMove

proc startTurn = 
  hypo = hypotheticalInit(turnPlayer)
  phase = Draw

proc rerollPhase =
  if configState == StatGame:
    if not diceReroll.isPausing or hypo.reroll:
      rollDice()
      diceReroll.isPausing = true
    else:
      diceReroll.isPausing = false
      phase = AiMove
  if diceReroll.isPausing and cpuTime() - diceReroll.pauseStartTime >= 0.25:
    diceReroll.isPausing = false
    rollTheDice = true
    # startDiceRoll(computerRoll)
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

proc endTurn* = 
  # showMenu = false
  phase = Await
  nextGameState()

proc endTurnPhase =
  if autoEndTurn and turnPlayer.cash < cashToWin:
    endTurn()
  else: changeMenuState = MenuOn

proc aiTakeTurn*() =
  case phase
  of Await: startTurn()
  of Draw: drawCards()
  of Reroll: rerollPhase()
  of AiMove: moveAi()
  of PostMove: postMovePhase()
  of EndTurn: endTurnPhase()
  turnPlayer.update = true

# please, for the love of God: don't even breethe on it!
# proc aiRightMouse* =
#   if phase == EndTurn: 
#     if showMenu: 
#       endTurn()
      # showMenu = not showMenu
 
