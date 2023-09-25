import win
import deck
import sequtils
import algorithm
import random
import batch
import colors
import board

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

const
  # robotoRegular = "fonts\\Roboto-Regular_1.ttf"
  # condensedRegular = "fonts\\AsapCondensed-Regular.ttf"
  fjallaOneRegular = "fonts\\FjallaOne-Regular.ttf"

  settingsFile* = "settings.cfg"
  defaultPlayerKinds = @[Human,Computer,None,None,None,None]
  (pbx,pby) = (20,20)

var
  playerKinds*:array[6,PlayerKind]
  playerBatches*:array[6,Batch]
  players*:seq[Player]
  turn*:Turn

proc playerBatch(name:string,bgColor:PlayerColor,entries:seq[string],yOffset:int):Batch = 
  newBatch BatchInit(
    kind:TextBatch,
    name:name,
    pos:(pbx,pby+yOffset),
    padding:(0,0,35,35),
    entries:entries,
    hAlign:CenterAlign,
    fixedBounds:(175,0),
    font:(fjallaOneRegular,30.0,contrastColors[bgColor]),
    bgColor:playerColors[bgColor],
    shadow:(10,1.75,color(255,255,255,200))
  )

proc newPlayerBatches:array[6,Batch] =
  var yOffset = pby
  for color in PlayerColor:
    if color.ord > 0:
      yOffset = pby+((result[color.ord-1].rect.h.toInt+15)*color.ord)
    result[color.ord] = playerBatch($color,color,@[$playerKinds[color.ord]],yOffset)
    result[color.ord].update = true

template turnPlayer*:untyped = players[turn.player]

func nrOfPiecesOnBars(player:Player): int =
  player.pieces.countIt it in bars

proc drawFrom*(deck:var Deck) =
  if turn.undrawnBlues > 0:
    if deck.drawPile.len == 0:
      deck.shufflePiles
    turnPlayer.hand.add deck.drawPile.pop
    dec turn.undrawnBlues

proc drawFrom*(deck:var Deck,batchNr:int) =
  if deck.drawPile.len == 0: deck.shufflePiles
  for _ in 1..batchNr: turnPlayer.hand.add deck.drawPile.pop

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

proc turnPlayerPlans*:tuple[cashable,notCashable:seq[BlueCard]] = turnPlayer.cashablePlans

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
  turnPlayer.turnNr = turn.nr
  if turn.player == players.high:
    inc turn.nr
    turn.player = 0
  else: inc turn.player
  turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars

proc drawPlayerBatches*(b:var Boxy) =
  if turn.nr == 0:
    for batch in playerBatches:
      if batch.isActive: b.drawBatch batch

proc paintPieces*:Image =
  var ctx = newImage(boardImg.width,boardImg.height).newContext
  ctx.font = "fonts\\IBMPlexMono-Bold.ttf"
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
  piecesImg* = DynamicImage[void](name:"pieces",updateImage:paintPieces,update:true)

proc leftMousePressed*(m:KeyEvent,deck:var Deck) =
  if mouseOn deck.drawSlot.area:
    drawFrom deck,1
    # discard cashInPlans deck
  else:
    let batchNr = mouseOnPlayerBatchNr()
    if batchNr != -1 and turn.nr == 0:
      playerKinds[batchNr] = 
        case playerKinds[batchNr]
        of Human:Computer
        of Computer:None
        of None:Human
      playerBatches[batchNr].setSpanText($playerKinds[batchNr],0)
      playerBatches[batchNr].update = true
      players[batchNr].kind = playerKinds[batchNr]
      piecesImg.update = true
    else:
      for (_,slot) in turnPlayer.hand.cardSlots:
        if mouseOn slot.area: 
          playTo deck,slot.nr
          break

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

randomize()
for i,kind in playerKindsFromFile(): playerKinds[i] = kind
players = newDefaultPlayers()
playerBatches = newPlayerBatches()

when isMainModule:
  printPlayers()
  players = newPlayers()
  printPlayers()

