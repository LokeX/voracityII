import win except splitWhitespace,strip
import game
import megasound
import colors
import board
import dialog
import sequtils
import deck
import batch
import eval
import menu
import reports
import random
import strutils
import sugar

type
  SinglePiece = tuple[playerNr,pieceNr:int]
  EventMoveFmt = tuple[fromSquare,toSquare:string]

const
  (humanRoll*,computerRoll*) = (0,80)

var
  singlePiece*:SinglePiece
  dialogBarMoves*:seq[Move]

proc drawCursor*(b:var Boxy) =
  if turn.nr > 0 and showCursor:
    let 
      x = (playerBatches[turn.player].area.x2-40).toFloat
      y = (playerBatches[turn.player].area.y1+10).toFloat
      cursor = Rect(x:x,y:y,w:20,h:20)
    b.drawRect(cursor,contrastColors[players[turn.player].color])

proc paintUndrawnBlues:Image =
  var ctx = newImage(110,180).newContext
  ctx.font = fjallaOneRegular
  ctx.fontSize = 160
  ctx.fillStyle = color(1,1,0)
  ctx.fillText($turn.undrawnBlues,20,160)
  ctx.image

var 
  nrOfUndrawnBluesPainter* = DynamicImage[void](
    name:"undrawBlues",
    area:(855,495,0,0), # may do drawpile.toArea
    updateImage:paintUndrawnBlues,
    update:true
  )

proc drawPlayerBatches*(b:var Boxy) =
  for batchNr,_ in players:
    if playerBatches[batchNr].isActive: 
      b.drawBatch playerBatches[batchNr]

proc paintPieces*:Image =
  var ctx = newImage(squares[0].dims.area.x2-bx.toInt,boardImg.height).newContext
  ctx.font = ibmBold
  ctx.fontSize = 10
  for i,player in (if turn.nr == 0: players.filterIt(it.kind != None) else: players):
    for square in player.pieces.deduplicate():
      let 
        nrOfPiecesOnSquare = player.pieces.filterIt(it == square).len
        piece = player.color.pieceOn(square)
      ctx.fillStyle = playerColors[player.color]
      ctx.fillRect(piece)
      if turn.nr > 0 and i == turn.player and square == moveSelection.fromSquare:
        ctx.fillStyle = contrastColors[player.color]
        ctx.fillRect(Rect(x:piece.x+4,y:piece.y+4,w:piece.w-8,h:piece.h-8))
      if nrOfPiecesOnSquare > 1:
        ctx.fillStyle = contrastColors[player.color]
        ctx.fillText($nrOfPiecesOnSquare,piece.x+2,piece.y+10)
  ctx.image

proc mouseOnPlayerBatchNr*:int =
  result = -1
  for i,_ in players:
    if mouseOn playerBatches[i]: return i

var 
  piecesImg* = DynamicImage[void](
    name:"pieces",
    area:(bx.toInt,by.toInt,0,0),
    updateImage:paintPieces,
    update:true
  )

proc setupNewGame* =
  turn = (0,0,false,0)
  blueDeck.resetDeck
  players = newDefaultPlayers()
  playerBatches = newPlayerBatches()
  piecesImg.update = true
  setMenuTo SetupMenu
  playSound "carhorn-1"

proc togglePlayerKind(batchNr:int) =
  playerKinds[batchNr] = 
    case playerKinds[batchNr]
    of Human:Computer
    of Computer:None
    of None:Human
  players[batchNr].kind = playerKinds[batchNr]
  updateBatch batchNr
  updateStatsBatch()
  piecesImg.update = true

proc mouseOnCardSlot(player:var Player,deck:var Deck):int =
  result = -1
  for (_,slot) in player.hand.cardSlots:
    if mouseOn slot.area: return slot.nr

proc movesFrom(player:Player,square:int):seq[int] =
  if turn.diceMoved: moveToSquares square
  else: moveToSquares(square,diceRoll)

proc select(square:int) =
  if turnPlayer.hasPieceOn square:
    moveSelection = (-1,square,-1,turnPlayer.movesFrom(square),false)
    moveToSquaresPainter.context = moveSelection.toSquares
    moveToSquaresPainter.update = true
    piecesImg.update = true
    playSound "carstart-1"

func pieceOnSquare(player:Player,square:int):int =
  for i,piece in player.pieces:
    if piece == square: return i

proc drawMoveToSquares*(b:var Boxy,square:int) =
  if square != moveSelection.hoverSquare:
    if turn.diceMoved:
      moveToSquaresPainter.context = square.moveToSquares
    else:
      moveToSquaresPainter.context = square.moveToSquares diceRoll
    moveToSquaresPainter.update = true
    moveSelection.hoverSquare = square
  b.drawDynamicImage moveToSquaresPainter

proc drawSquares*(b:var Boxy) =
  if moveSelection.fromSquare != -1:
    b.drawDynamicImage moveToSquaresPainter
  elif (let square = mouseOnSquare(); square != -1) and turnPlayer.hasPieceOn(square):
    b.drawMoveToSquares square
  else: moveSelection.hoverSquare = -1

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
    piecesImg.update = true

proc playCashPlansTo*(deck:var Deck) =
  if (let cashedPlans = cashInPlansTo(deck); cashedPlans.len > 0):
    updateTurnReportCards(cashedPlans,Cashed)
    turn.player.updateBatch
    playSound "coins-to-table-2"
    echo "Cashed plans:"
    echo $turnPlayer.color," players pieces",turnPlayer.pieces
    echo cashedPlans
    if turnPlayer.cash >= cashToWin:
      writeGamestats()
      playSound "applause-2"
      setMenuTo NewGameMenu

proc move*(square:int)
proc eventMoveFmt(move:Move):EventMoveFmt =
  ("from:"&squares[move.fromSquare].name&" Nr. "&($squares[move.fromSquare].nr)&"\n",
   "to:"&squares[move.toSquare].name&" Nr. "&($squares[move.toSquare].nr)&"\n")

proc dialogEntries(moves:seq[Move],f:EventMoveFmt -> string):seq[string] =
  var ms = moves.mapIt(it.eventMoveFmt).mapIt(f it).deduplicate
  stripLineEnd ms[^1]
  ms

proc endBarMoveSelection(selection:string) =
  if (let toSquare = selection.splitWhitespace[^1].parseInt; toSquare != -1):
    moveSelection.toSquare = toSquare
    moveSelection.event = true
    move moveSelection.toSquare

proc selectBarMoveDest(selection:string) =
  let 
    entries = dialogBarMoves.dialogEntries move => move.toSquare
    fromSquare = selection.splitWhitespace[^1].parseInt
  if fromSquare != -1:
    moveSelection.fromSquare = fromSquare
  if entries.len > 1:
    startDialog(entries,0..entries.high,endBarMoveSelection)
  elif entries.len == 1: 
    moveSelection.toSquare = dialogBarMoves[0].toSquare
    moveSelection.event = true
    move moveSelection.toSquare

proc selectBar =
  showMenu = false
  let entries = dialogBarMoves.dialogEntries move => move.fromSquare
  if entries.len > 1:
    startDialog(entries,0..entries.high,selectBarMoveDest)
  elif entries.len == 1: 
    moveSelection.fromSquare = dialogBarMoves[0].fromSquare
    selectBarMoveDest entries[0]

proc barMove(moveEvent:BlueCard):bool =
  dialogBarMoves = turnPlayer.eventMovesEval moveEvent
  echo dialogBarMoves.mapIt(it.eventMoveFmt).mapIt(it.fromSquare&"\n"&it.toSquare).join("\n")
  if dialogBarMoves.len == 1 or turnPlayer.kind == Computer:
    moveSelection.event = true
    moveSelection.fromSquare = dialogBarMoves[0].fromSquare
    moveSelection.toSquare = dialogBarMoves[0].toSquare
    return true
  else: selectBar()

proc playNews =
  piecesImg.update = true
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
  nrOfUndrawnBluesPainter.update = true
  turn.player.updateBatch
  playSound "page-flip-2"

proc togglePlayerKind* =
  if (let batchNr = mouseOnPlayerBatchNr(); batchNr != -1) and turn.nr == 0:
    togglePlayerKind batchNr

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

func diceMoved(fromSquare,toSquare:int):bool =
  if fromSquare == 0:
    tosquare notin gasStations and toSquare notin highways
  elif fromSquare in highways:
    toSquare notin gasStations
  else: true

proc move =
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
    updateBatch turn.player
  playCashPlansTo blueDeck
  turnPlayer.hand = turnPlayer.sortBlues
  playerBatches[turn.player].update = true
  moveSelection.fromSquare = -1
  piecesImg.update = true
  playSound "driveBy"
  if moveSelection.toSquare in bars:
    inc turn.undrawnBlues
    nrOfUndrawnBluesPainter.update = true
    playSound "can-open-1"

proc animateMove* =
  startMoveAnimation(
    turnPlayer.color,
    moveSelection.fromSquare,
    moveSelection.toSquare
  )
  move()

proc killPieceAndMove*(confirmedKill:string) =
  if confirmedKill == "Yes":
    players[singlePiece.playerNr].pieces[singlePiece.pieceNr] = 0
    updateTurnReport players[singlePiece.playerNr].color
    playSound "Gunshot"
    playSound "Deanscream-2"
  animateMove()

proc shouldKillEnemyOn(killer:Player,toSquare:int): bool =
  if killer.hasPieceOn(toSquare) or 
    killer.cash-(killer.removedPieces*piecePrice) <= startCash div 2: 
      return false 
  else:
    let 
      randKill = rand(1..100) <= 5
      needsProtection = killer.needsProtectionOn(moveSelection.fromSquare,toSquare)
      agroKill = rand(1..100) <= killer.agro and not needsProtection
      planChance = players[singlePiece.playerNr].cashChanceOn(toSquare,blueDeck)
      barKill = toSquare in bars and (
        killer.nrOfPiecesOnBars > 1 or players.len < 3
      )
    (planChance > 0.05*(players.len.toFloat/2)) or agroKill or barKill or randKill

proc aiRemovePiece(move:Move): bool =
  turnPlayer.hypotheticalInit.friendlyFireAdviced(move) or 
  turnPlayer.shouldKillEnemyOn move.toSquare

proc aiKillDecision =
  killPieceAndMove(
    if aiRemovePiece getMove(): 
      "Yes" 
    else: 
      "No"
  )

proc startKillDialog(square:int) =
  let 
    targetPlayer = players[singlePiece.playerNr]
    targetSquare = targetPlayer.pieces[singlePiece.pieceNr]
    cashChance = targetPlayer.cashChanceOn(targetSquare,blueDeck)*100
    entries:seq[string] = @[
      "Remove piece on:\n",
      squares[square].name&" Nr."&($squares[square].nr)&"?\n",
      "Cash chance: "&cashChance.formatFloat(ffDecimal,2)&"%\n",
      "\n",
      "Yes\n",
      "No",
    ]
  # dialogBarMoves.setLen 0
  showMenu = false
  startDialog(entries,4..5,killPieceAndMove)

proc hasKillablePiece(square:int):bool =
  singlePiece = players.singlePieceOn square
  singlePiece.playerNr != -1 and canKillPieceOn square

proc move*(square:int) =
  moveSelection.toSquare = square
  if square.hasKillablePiece:
    if turnPlayer.kind == Human:
      startKillDialog square
    else: aiKillDecision()
  else: animateMove()

proc leftMouse*(m:KeyEvent) =
  if turn.undrawnBlues > 0 and mouseOn blueDeck.drawSlot.area: 
    drawCardFrom blueDeck
    playCashPlansTo blueDeck
    turnPlayer.hand = turnPlayer.sortBlues
  elif not isRollingDice():
    if (let square = mouseOnSquare(); square != -1): 
      if moveSelection.fromSquare == -1 or square notIn moveSelection.toSquares:
        select square
      elif moveSelection.fromSquare != -1:
        move square
    elif turnPlayer.hand.len > 3: 
      if (let slotNr = turnPlayer.mouseOnCardSlot blueDeck; slotNr != -1):
        turnPlayer.hand.playTo blueDeck,slotNr
        turnPlayer.hand = turnPlayer.sortBlues

proc endGame =
  if turnPlayer.kind == Human:
    recordTurnReport()
  # writeGamestats()
  setupNewGame()
  setMenuTo SetupMenu
  showMenu = true

proc startNewGame =
  inc turn.nr
  players = newPlayers()
  playerBatches = newPlayerBatches()
  resetReports()
  setMenuTo GameMenu
  showMenu = false

proc nextTurn =
  playSound "page-flip-2"
  updateTurnReportCards(turnPlayer.discardCards blueDeck, Discarded)
  # if turnPlayer.kind == Human:
  recordTurnReport()
  diceRolls.setLen 0
  nextPlayerTurn()
  initTurnReport()
  if anyHuman players: showMenu = false
  updateTurnReportCards(cashInPlansTo blueDeck, Cashed)

proc nextGameState* =
  if turnPlayer.cash >= cashToWin: 
    endGame()
  else:
    if turn.nr == 0: 
      startNewGame()
    else: 
      nextTurn()
    startDiceRoll(if turnPlayer.kind == Human: humanRoll else: computerRoll)
  playSound "carhorn-1"

proc rightMouse*(m:KeyEvent) =
  if moveSelection.fromSquare != -1:
    moveSelection.fromSquare = -1
    piecesImg.update = true
  elif not showMenu:
    showMenu = true
  else: nextGameState()
