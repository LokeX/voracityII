import win
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

type
  SinglePiece = tuple[playerNr,pieceNr:int]

const
  (humanRoll*,computerRoll*) = (0,80)

var
  singlePiece*:SinglePiece

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

proc canMovePieceFrom*(player:Player,square:int):bool =
  player.hasPieceOn(square) and
  (not turn.diceMoved or square in highways or 
  (square == 0 and player.cash >= 5000))

proc select(square:int) =
  if turnPlayer.canMovePieceFrom square:
    moveSelection = (-1,square,-1,moveToSquares(square,diceRoll),false)
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
  const noSuchBar = -1
  if (let bar = turnPlayer.barToMassacre players; bar != noSuchBar):
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
    if turnPlayer.cash >= cashToWin:
      writeGamestats()
      playSound "applause-2"
      setMenuTo NewGameMenu

proc move*(square:int)
proc barMove(moveEvent:BlueCard):bool =
  let barsWithPieces = bars.filterIt it in turnPlayer.pieces
  if (barsWithPieces.len > 0):
    let chosenBar = barsWithPieces[rand 0..barsWithPieces.high]
    moveSelection.event = true
    moveSelection.fromSquare = chosenBar
    moveSelection.toSquare = moveEvent.moveSquares[rand 0..moveEvent.moveSquares.high]
  barsWithPieces.len > 0

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
  result = (-1,-1)
  if players.nrOfPiecesOn(square) == 1:
    for playerNr,player in players:
      for pieceNr,piece in player.pieces:
        if piece == square: return (playerNr,pieceNr)

proc getMove:Move =
  result.die = -1
  result.eval = -1
  result.fromSquare = moveSelection.fromSquare
  result.toSquare = moveSelection.toSquare
  result.pieceNr = turnPlayer.pieceOnSquare moveSelection.fromSquare

proc move =
  var move = getMove()
  if not turn.diceMoved and not moveSelection.event:
    turn.diceMoved = not noDiceUsedToMove(
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
