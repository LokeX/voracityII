import win
import deck
import sequtils
import algorithm
import random
import batch

type
  PlayerKind* = enum Human,Computer,None
  PlayerColors* = enum Red,Green,Blue,Yellow,Black,White
  Pieces* = array[5,int]
  Player* = object
    color*:PlayerColors
    kind*:PlayerKind
    turnNr*:int
    pieces*:Pieces
    hand*:seq[BlueCard]
    cash*:int
  Turn* = object
    nr*:int # turnNr == 0 is player setup flag?
    player*:int
    diceMoved*:bool
    undrawnBlues*:int

const
  playerColors*:array[PlayerColors,Color] = [
    color(50,0,0),color(0,50,0),
    color(0,0,50),color(50,50,0),
    color(255,255,255),color(1,1,1)
  ]
  playerColorsTrans*:array[PlayerColors,Color] = [
    color(50,0,0,150),color(0,50,0,150),
    color(0,0,50,150),color(50,50,0,150),
    color(255,255,255,150),color(1,1,1,150)
  ]
  contrastColors*:array[PlayerColors,Color] = [
    color(1,1,1),
    color(255,255,255),
    color(1,1,1),
    color(255,255,255),
    color(1,1,1),
    color(255,255,255),
  ]  

  robotoRegular = "fonts\\Roboto-Regular_1.ttf"
  condensedRegular = "fonts\\AsapCondensed-Regular.ttf"
  fjallaOneRegular = "fonts\\FjallaOne-Regular.ttf"

  settingsFile* = "settings.cfg"
  defaultPlayerKinds = @[Human,Computer,None,None,None,None]
  (bx,by) = (20,20)

  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]
  bars* = [1,16,18,20,28,35,40,46,51,54]

var
  setupBatches*,playerBatches*:seq[Batch]
  playerKinds*:seq[PlayerKind]
  players*:seq[Player]
  turn*:Turn

proc setupBatch(name:string,bgColor:PlayerColors,entries:seq[string],yOffset:int):Batch = 
  newBatch BatchInit(
    kind:TextBatch,
    name:name,
    pos:(bx,by+yOffset),
    padding:(0,0,35,35),
    entries:entries,
    hAlign:CenterAlign,
    fixedBounds:(175,0),
    font:(fjallaOneRegular,30.0,contrastColors[bgColor]),
    bgColor:playerColors[bgColor],
    shadow:(10,1.75,color(255,255,255,200))
  )

proc gameBatch(name:string,bgColor:PlayerColors,entries:seq[string],yOffset:int):Batch = 
  newBatch BatchInit(
    kind:TextBatch,
    name:name,
    pos:(bx,by+yOffset),
    padding:(0,0,5,5),
    entries:entries,
    hAlign:LeftAlign,
    fixedBounds:(175,0),
    font:(fjallaOneRegular,14.0,contrastColors[bgColor]),
    bgColor:playerColors[bgColor],
    shadow:(10,1.75,color(255,255,255,200))
  )

proc newSetupBatches:seq[Batch] =
  var yOffset = by
  for color in PlayerColors:
    if result.len > 0:
      yOffset = by+((result[^1].rect.h.toInt+15)*color.ord)
    result.add setupBatch($color,color,@[$playerKinds[color.ord]],yOffset)
    result[^1].update = true

template turnPlayer*:untyped = players[turn.player]

func nrOfPiecesOnBars(player:Player): int =
  player.pieces.countIt(it in bars)

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
    gotOneInMany = player.pieces.anyIt(it in plan.squares.oneInMany)
    oneInMoreOk = plan.squares.oneInmany.len == 0 or gotOneInMany
  requiredOk and oneInMoreOk

func plans*(player:Player):tuple[cashable,notCashable:seq[BlueCard]] =
  for plan in player.hand.filterIt it.cardKind == Plan:
    if player.isCashable plan: result.cashable.add plan
    else: result.notCashable.add plan

proc turnPlayerPlans*:tuple[cashable,notCashable:seq[BlueCard]] = turnPlayer.plans

proc cashInPlans*(deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = turnPlayer.plans
  for plan in cashable.sortedByIt it.cash:
    deck.discardPile.add plan
  turnPlayer.hand = notCashable
  turnPlayer.cash += cashable.mapIt(it.cash).sum
  cashable

proc newDefaultPlayers*:seq[Player] =
  for i,kind in playerKinds:
    result.add Player(
      kind:kind,
      color:PlayerColors(i),
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
    for batch in setupBatches:
      if batch.isActive: b.drawBatch batch

proc mouseOnSetupBatchNr:int =
  result = -1
  for i,batch in setupBatches:
    if mouseOn batch: return i

proc leftMousePressed*(m:KeyEvent,deck:var Deck) =
  if mouseOn deck.discardSlot.area:
    case show:
    of Hand: show = Discard
    of Discard: show = Hand
  elif show == Discard:
    show = Hand
  elif mouseOn deck.drawSlot.area:
    drawFrom deck,1
    # discard cashInPlans deck
  else:
    let batchNr = mouseOnSetupBatchNr()
    if batchNr != -1 and turn.nr == 0:
      playerKinds[batchNr] = 
        case playerKinds[batchNr]
        of Human:Computer
        of Computer:None
        of None:Human
      setupBatches[batchNr].setSpanText($playerKinds[batchNr],0)
      setupBatches[batchNr].update = true
    else:
      for (_,slot) in turnPlayer.hand.cardSlots:
        if mouseOn slot.area: 
          playTo deck,slot.nr

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
playerKinds = playerKindsFromFile()
playerKindsToFile playerKinds
players = newDefaultPlayers()
setupBatches = newSetupBatches()

when isMainModule:
  printPlayers()
  players = newPlayers()
  printPlayers()

