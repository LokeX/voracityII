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
# import misc
import random

type
  SinglePiece = tuple[playerNr,pieceNr:int]

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
  playerBatches[batchNr].setSpanText($playerKinds[batchNr],0)
  playerBatches[batchNr].update = true
  players[batchNr].kind = playerKinds[batchNr]
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
    moveSelection = (-1,square,-1,moveToSquares(square,diceRoll))
    moveToSquaresPainter.context = moveSelection.toSquares
    moveToSquaresPainter.update = true
    piecesImg.update = true
    playSound "carstart-1"

func pieceOnSquare(player:Player,square:int):int =
  for i,piece in player.pieces:
    if piece == square: return i

proc drawMoveToSquares*(b:var Boxy,square:int) =
  if square != moveSelection.hoverSquare and turnPlayer.hasPieceOn(square):
    if turn.diceMoved:
      moveToSquaresPainter.context = square.moveToSquares
    else:
      moveToSquaresPainter.context = square.moveToSquares diceRoll
    moveToSquaresPainter.update = true
    moveSelection.hoverSquare = square
  b.drawDynamicImage moveToSquaresPainter

proc drawSquares*(b:var Boxy) =
  if moveSelection.fromSquare != -1:
    b.drawMoveToSquares
  elif (let square = mouseOnSquare(); square != -1) and turnPlayer.hasPieceOn square:
    b.drawMoveToSquares square

proc massacre(player:Player,players:seq[Player]):int =
  if (let playerBars = turnPlayer.onBars; playerBars.len > 0):
    echo "turnPlayer bars: ",playerBars
    let 
      maxPieces = playerBars.mapIt(players.nrOfPiecesOn it).max
      barsWithMaxPieces = bars.filterIt(players.nrOfPiecesOn(it) == maxPieces)
      chosenBar = barsWithMaxPieces[rand 0..barsWithMaxPieces.high]
    chosenBar
  else: -1

proc playMassacre =
  const noSuchBar = -1
  if (let moveFrom = turnPlayer.massacre players; moveFrom != noSuchBar):
    for (playerNr,pieceNr) in players.piecesOn moveFrom:
      echo "killing ",$players[playerNr].color," piece on square: ",$players[playerNr].pieces[pieceNr]
      players[playerNr].pieces[pieceNr] = 0
      playSound "Deanscream-2"
      playSound "Gunshot"
    echo "massacre bar, square: ",moveFrom
   
proc move*(square:int)
proc barMove(moveEvent:BlueCard):bool =
  let barsWithPieces = bars.filterIt it in turnPlayer.pieces
  if barsWithPieces.len > 0:
    let chosenBar = barsWithPieces[rand 0..barsWithPieces.high]
    moveSelection.fromSquare = chosenBar
    moveSelection.toSquare = moveEvent.moveSquares[rand 0..moveEvent.moveSquares.high]
  barsWithPieces.len > 0

proc playEvent()
proc playDejaVue =
  playSound "SCARYBEL-1"
  turnPlayer.hand.add blueDeck.discardPile[^2]
  delete(blueDeck.discardPile,blueDeck.discardPile.high - 1)
  blueDeck.lastDrawn = turnPlayer.hand[^1].title
  echo "Deja vue: survived discard pile draw"
  if turnPlayer.hand.len > 0 and turnPlayer.hand[^1].cardKind == Event: 
    playEvent()
  if (let cashedPlans = cashInPlansTo blueDeck; cashedPlans.len > 0):
    updateTurnReportCards(cashedPlans,Cashed)

proc playNews =
  let news = turnPlayer.hand[^1]
  turnPlayer.hand.playTo blueDeck,turnPlayer.hand.high
  for (playerNr,pieceNr) in players.piecesOn news.moveSquares[0]:
    players[playerNr].pieces[pieceNr] = news.moveSquares[1]

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

proc drawCardFrom*(deck:var Deck) =
  turnPlayer.hand.drawFrom deck
  echo "drew card: ",turnPlayer.hand[^1].title
  echo "card kind: ",turnPlayer.hand[^1].cardKind
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

proc playCashPlansTo*(deck:var Deck) =
  if (let cashedPlans = cashInPlansTo(deck); cashedPlans.len > 0):
    updateTurnReportCards(cashedPlans,Cashed)
    # turnReport.cards.cashed.add cashedPlans
    turn.player.updateBatch
    playSound "coins-to-table-2"
    if turnPlayer.cash >= cashToWin:
      playSound "applause-2"
      setMenuTo NewGameMenu

func singlePieceOn*(players:seq[Player],square:int):SinglePiece =
  result = (-1,-1)
  if players.nrOfPiecesOn(square) == 1:
    for playerNr,player in players:
      for pieceNr,piece in player.pieces:
        if piece == square: return (playerNr,pieceNr)

proc initMove:Move =
  result.die = -1
  result.eval = -1
  result.fromSquare = moveSelection.fromSquare
  result.toSquare = moveSelection.toSquare
  result.pieceNr = turnPlayer.pieceOnSquare moveSelection.fromSquare

proc move =
  echo "executing move"
  turn.diceMoved = not noDiceUsedToMove(
    moveSelection.fromSquare,moveSelection.toSquare)
  let move = initMove()
  if turnPlayer.kind == Human: updateTurnReport move
  #   turnReport.moves.add move
  turnPlayer.pieces[move.pieceNr] = moveSelection.toSquare
  if moveSelection.fromSquare == 0: 
    turnPlayer.cash -= 5000
    updateBatch turn.player
  echo "cashing plans"
  playCashPlansTo blueDeck
  echo "survived: cashing plans"
  turnPlayer.hand = turnPlayer.sortBlues
  echo "survived sorting blues"
  playerBatches[turn.player].update = true
  moveSelection.fromSquare = -1
  piecesImg.update = true
  playSound "driveBy"
  if moveSelection.toSquare in bars:
    inc turn.undrawnBlues
    nrOfUndrawnBluesPainter.update = true
    playSound "can-open-1"

proc animateMove* =
  # atEndOfAnimationCall move
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

proc canKillPieceOn*(square:int):bool =
  square notIn highways and square notIn gasStations

proc move*(square:int) =
  moveSelection.toSquare = square
  singlePiece = players.singlePieceOn square
  if turnPlayer.kind == Human and singlePiece.playerNr != -1 and canKillPieceOn square:
    let entries:seq[string] = @[
      "Remove piece on:\n",
      squares[square].name&" Nr."&($squares[square].nr)&"?\n",
      "\n",
      "Yes\n",
      "No",
    ]
    showMenu = false
    startDialog(entries,3..4,killPieceAndMove)
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
        echo "back from move"
    elif turnPlayer.hand.len > 3: 
      if (let slotNr = turnPlayer.mouseOnCardSlot blueDeck; slotNr != -1):
        turnPlayer.hand.playTo blueDeck,slotNr
        turnPlayer.hand = turnPlayer.sortBlues

proc nextTurn* =
  # echo "new game"
  if turnPlayer.cash >= cashToWin:
    setupNewGame()
    setMenuTo SetupMenu
  else:
    if turn.nr == 0:
      inc turn.nr
      players = newPlayers()
      playerBatches = newPlayerBatches()
      resetReports()
      setMenuTo GameMenu
      showMenu = false
    else: 
      playSound "page-flip-2"
      turnReport.cards.discarded.add turnPlayer.discardCards blueDeck
      echoTurnReport()
      if turnPlayer.kind == Human:
        recordTurnReport()
      nextPlayerTurn()
      initTurnReport()
      showMenu = false
    startDiceRoll()
  playSound "carhorn-1"

proc rightMouse*(m:KeyEvent) =
  if moveSelection.fromSquare != -1:
    moveSelection.fromSquare = -1
    piecesImg.update = true
  elif not showMenu:
    showMenu = true
  else: nextTurn()
