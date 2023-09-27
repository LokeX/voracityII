import win
import deck
import strutils
import sequtils
import algorithm
import random
import batch
import colors
import board
import megasound

type
  PlayerKind* = enum Human,Computer,None
  Pieces* = array[5,int]
  Player* = object
    color*:PlayerColor
    kind*:PlayerKind
    turnNr*:int
    pieces*:Pieces
    hand*:seq[BlueCard]
    cash*:int
  Turn* = tuple
    nr:int # turnNr == 0 is player setup flag?
    player:int
    diceMoved:bool
    undrawnBlues:int
  BatchSetup = tuple
    name:string
    bgColor:PlayerColor
    entries:seq[string]
    hAlign:HorizontalAlignment
    font:string
    fontSize:float
    padding:(int,int,int,int)

const
  roboto = "fonts\\Roboto-Regular_1.ttf"
  fjallaOneRegular = "fonts\\FjallaOne-Regular.ttf"
  ibmBold = "fonts\\IBMPlexMono-Bold.ttf"
  settingsFile* = "settings.cfg"
  defaultPlayerKinds = @[Human,Computer,None,None,None,None]
  (pbx,pby) = (20,20)

var
  playerKinds*:array[6,PlayerKind]
  playerBatches*:array[6,Batch]
  players*:seq[Player]
  turn*:Turn
  showCursor*:bool

template turnPlayer*:untyped = players[turn.player]

proc drawCursor*(b:var Boxy) =
  if turn.nr > 0 and showCursor:
    let 
      x = (playerBatches[turn.player].area.x2-40).toFloat
      y = (playerBatches[turn.player].area.y1+10).toFloat
      cursor = Rect(x:x,y:y,w:20,h:20)
    b.drawRect(cursor,contrastColors[players[turn.player].color])

proc playerBatch(setup:BatchSetup,yOffset:int):Batch = 
  newBatch BatchInit(
    kind:TextBatch,
    name:setup.name,
    pos:(pbx,pby+yOffset),
    padding:setup.padding,
    entries:setup.entries,
    hAlign:setup.hAlign,
    fixedBounds:(175,110),
    font:(setup.font,setup.fontSize,contrastColors[setup.bgColor]),
    bgColor:playerColors[setup.bgColor],
    shadow:(10,1.75,color(255,255,255,200))
  )

proc playerBatchTxt(playerNr:int):seq[string] =
  if turn.nr == 0:
    @[$playerKinds[playerNr]]
  else: @[
    "Turn Nr: "&($turn.nr)&"\n",
    "Cards: "&($players[playerNr].hand.len)&"\n",
    "Cash: "&(insertSep($players[playerNr].cash,'.'))
  ]

proc updateBatch(playerNr:int) =
  playerBatches[playerNr].setSpanTexts playerBatchTxt playerNr
  playerBatches[playerNr].update = true

proc batchSetup(playerNr:int):BatchSetup =
  let player = players[playerNr]
  result.name = $player.color
  result.bgColor = player.color
  if turn.nr == 0: 
    result.hAlign = CenterAlign
    result.font = fjallaOneRegular
    result.fontSize = 30
    result.padding = (0,0,35,35)
  else: 
    result.hAlign = LeftAlign
    result.font = roboto
    result.fontSize = 18
    result.padding = (20,20,20,20)
  result.entries = playerBatchTxt(playerNr)

proc newPlayerBatches:array[6,Batch] =
  var 
    yOffset = pby
    setup:BatchSetup
  for playerNr,_ in players:
    if playerNr > 0: 
      yOffset = pby+((result[playerNr-1].rect.h.toInt+15)*playerNr)
    setup = batchSetup(playerNr)
    result[playerNr] = setup.playerBatch yOffset
    result[playerNr].update = true

func nrOfPiecesOnBars(player:Player): int =
  player.pieces.countIt it in bars

proc drawFrom*(deck:var Deck) =
  if turn.undrawnBlues > 0:
    if deck.drawPile.len == 0:
      deck.shufflePiles
    turnPlayer.hand.add deck.drawPile.pop
    dec turn.undrawnBlues

proc drawFrom*(deck:var Deck,nrOfCards:int) =
  for _ in 1..nrOfCards: drawFrom deck

proc playTo*(deck:var Deck,idx:int) =
  deck.discardPile.add turnPlayer.hand[idx]
  turnPlayer.hand.del idx

proc discardCards*(deck:var Deck) =
  while turnPlayer.hand.len > 3:
    playTo deck,turnPlayer.hand.high

func requiredSquaresAndPieces*(plan:BlueCard):tuple[squares,nrOfPieces:seq[int]] =
  let squares = plan.squares.required.deduplicate
  (squares,squares.mapIt plan.squares.required.count it)

func isCashable*(player:Player,plan:BlueCard):bool =
  let 
    (squares,nrOfPiecesRequired) = plan.requiredSquaresAndPieces
    nrOfPiecesOnSquares = squares.mapIt player.pieces.count it
    requiredOk = toSeq(0..squares.high).allIt nrOfPiecesOnSquares[it] >= nrOfPiecesRequired[it]
    gotOneInMany = player.pieces.anyIt it in plan.squares.oneInMany
    oneInMoreOk = plan.squares.oneInmany.len == 0 or gotOneInMany
  requiredOk and oneInMoreOk

func cashablePlans*(player:Player):tuple[cashable,notCashable:seq[BlueCard]] =
  for plan in player.hand.filterIt it.cardKind == Plan:
    if player.isCashable plan: result.cashable.add plan
    else: result.notCashable.add plan

proc cashInPlans*(deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = turnPlayer.cashablePlans
  for plan in cashable.sortedByIt it.cash:
    deck.discardPile.add plan
  turnPlayer.hand = notCashable
  turnPlayer.cash += cashable.mapIt(it.cash).sum
  cashable

proc newDefaultPlayers*:seq[Player] =
  for i,kind in playerKinds:
    result.add Player(
      kind:kind,
      color:PlayerColor(i),
      pieces:highways
    )

proc newPlayers*:seq[Player] =
  var 
    randomPosition = rand(1..6)
    playerSlots:array[1..6,Player]
  for player in players:
    while playerSlots[randomPosition].cash != 0: 
      randomPosition = rand(1..6)
    playerSlots[randomPosition] = Player(
      color:player.color,
      kind:player.kind,
      pieces:highways,
      cash:25000
    )
  playerSlots.filterIt it.kind != None

proc nextPlayerTurn* =
  echo "next turn"
  playSound "carhorn-1"
  turnPlayer.turnNr = turn.nr
  turn.player.updateBatch
  if turn.player == players.high:
    inc turn.nr
    turn.player = players.low
  else: inc turn.player
  turn.player.updateBatch
  turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars

proc drawPlayerBatches*(b:var Boxy) =
  for batchNr,_ in players:
    if playerBatches[batchNr].isActive: 
      b.drawBatch playerBatches[batchNr]

proc paintPieces*:Image =
  var ctx = newImage(boardImg.width,boardImg.height).newContext
  ctx.font = ibmBold
  ctx.fontSize = 10
  for player in (if turn.nr == 0: players.filterIt(it.kind != None) else: players):
    for square in player.pieces.deduplicate():
      let 
        nrOfPiecesOnSquare = player.pieces.filterIt(it == square).len
        piece = player.color.pieceOn(square)
      ctx.fillStyle = playerColors[player.color]
      ctx.fillRect(piece)
      if nrOfPiecesOnSquare > 1:
        ctx.fillStyle = contrastColors[player.color]
        ctx.fillText($nrOfPiecesOnSquare,piece.x+2,piece.y+10)
  ctx.image

proc mouseOnPlayerBatchNr:int =
  result = -1
  for i,batch in playerBatches:
    if mouseOn batch: return i

var 
  piecesImg* = DynamicImage[void](
    name:"pieces",
    area:(bx.toInt,by.toInt,0,0),
    updateImage:paintPieces,
    update:true
  )

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

proc playCard(deck:var Deck) =
  for (_,slot) in turnPlayer.hand.cardSlots:
    if mouseOn slot.area: 
      playTo deck,slot.nr
      break

proc leftMousePressed*(m:KeyEvent,deck:var Deck) =
  if mouseOn deck.drawSlot.area:
    drawFrom deck,1
    # discard cashInPlans deck
  else:
    let batchNr = mouseOnPlayerBatchNr()
    if batchNr != -1 and turn.nr == 0:
      togglePlayerKind batchNr
    else: playCard deck

proc rightMousePressed*(m:KeyEvent,deck:var Deck) =
  if turn.nr == 0:
    inc turn.nr
    players = newPlayers()
    playerBatches = newPlayerBatches()
    playSound "carhorn-1"
  else: nextPlayerTurn()

proc playerKindsFromFile:seq[PlayerKind] =
  try:
    readFile(settingsFile)
    .split("@[,]\" ".toRunes)
    .filterIt(it.len > 0)
    .mapIt(PlayerKind(PlayerKind.mapIt($it).find(it)))
  except: defaultPlayerKinds

proc playerKindsToFile*(playerKinds:openArray[PlayerKind]) =
  writeFile(settingsFile,$playerKinds.mapIt($it))

proc printPlayers =
  for player in players:
    for field,value in player.fieldPairs:
      echo field,": ",value

proc initPlayers =
  randomize()
  for i,kind in playerKindsFromFile(): playerKinds[i] = kind
  players = newDefaultPlayers()
  playerBatches = newPlayerBatches()

initPlayers()

when isMainModule:
  printPlayers()
  players = newPlayers()
  printPlayers()

