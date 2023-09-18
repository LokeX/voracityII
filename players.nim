import win
import deck
import sequtils
import algorithm
import random

type
  PlayerKind* = enum Human,Computer,None
  PlayerColors* = enum Red,Green,Blue,Yellow,Black,White
  Player* = object
    color*:PlayerColors
    kind*:PlayerKind
    turnNr*:int
    pieces*:array[5,int]
    hand*:seq[BlueCard]
    cash*:int
  Turn* = object
    nr*:int # turnNr == 0 is player setup flag?
    player*:int
    diceMoved*:bool
    undrawnBlues*:int

const
  settingsFile* = "settings.cfg"
  defaultPlayerKinds = [Human,Computer,None,None,None,None]
  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]
  bars* = [1,16,18,20,28,35,40,46,51,54]

var
  playerKinds*:array[1..6,PlayerKind] = defaultPlayerKinds
  players*:seq[Player]
  turn*:Turn

proc nrOfPiecesOnBars(player:Player): int =
  player.pieces.countIt(it in bars)

proc drawFrom*(deck:var Deck) =
  if turn.undrawnBlues > 0:
    if deck.drawPile.len == 0:
      deck.shufflePiles
    players[turn.player].hand.add deck.drawPile.pop
    dec turn.undrawnBlues

proc drawFrom*(deck:var Deck,nr:int) =
  if deck.drawPile.len == 0: deck.shufflePiles
  for _ in 1..nr: players[turn.player].hand.add deck.drawPile.pop

proc playTo*(deck:var Deck,idx:int) =
  deck.discardPile.add players[turn.player].hand[idx]
  players[turn.player].hand.del idx

proc discardCards*(deck:var Deck) =
  while players[turn.player].hand.len > 3:
    playTo deck,players[turn.player].hand.high

func requiredSquaresAndPieces*(plan:BlueCard):tuple[squares,nrOfPieces:seq[int]] =
  let squares = plan.squares.required.deduplicate
  (squares,squares.mapIt plan.squares.required.count it)

proc hasOneInManyFor(player:Player,plan:BlueCard):bool =
  player.pieces.anyIt(it in plan.squares.oneInMany)

proc isCashable*(player:Player,plan:BlueCard):bool =
  let 
    (squares,nrOfPiecesRequired) = plan.requiredSquaresAndPieces
    nrOfPiecesOnSquares = squares.mapIt player.pieces.count it
    requiredOk = toSeq(0..squares.len-1).allIt nrOfPiecesOnSquares[it] >= nrOfPiecesRequired[it]
    oneInMoreOk = plan.squares.oneInmany.len == 0 or player.hasOneInManyFor plan
  requiredOk and oneInMoreOk

proc plans*(player:Player):tuple[cashable,notCashable:seq[BlueCard]] =
  for plan in player.hand.filterIt it.cardKind == Plan:
    if player.isCashable plan: result.cashable.add plan
    else: result.notCashable.add plan

proc turnPlayerPlans*:tuple[cashable,notCashable:seq[BlueCard]] = players[turn.player].plans

proc cashInPlans*(deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = players[turn.player].plans
  for plan in cashable.sortedByIt it.cash:
    deck.discardPile.add plan
  players[turn.player].hand = notCashable
  players[turn.player].cash += cashable.mapIt(it.cash).sum
  cashable

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
    for (_,slot) in players[turn.player].hand.cardSlots:
      if mouseOn slot.area: 
        playTo deck,slot.nr

proc nrOfPlayers*: int =
  players.filterIt(it.kind != None).len

proc newDefaultPlayers*:seq[Player] =
  for i in 1..6:
    result.add Player(
      kind:playerKinds[i],
      color:PlayerColors(i-1),
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
  if turn.player == players.high:
    inc turn.nr
    turn.player = 0
  else: inc turn.player
  turn.undrawnBlues = players[turn.player].nrOfPiecesOnBars

proc playerKindsFromFile:seq[PlayerKind] =
  try:
    readFile(settingsFile)
    .split("@[,]\" ".toRunes)
    .filterIt(it.len > 0)
    .mapIt(PlayerKind(PlayerKind.mapIt($it).find(it)))
  except: return

proc playerKindsToFile* =
  writeFile(settingsFile,$playerKinds.mapIt($it))

randomize()
players = newDefaultPlayers()
for i,kind in playerKindsFromFile(): 
  playerKinds[playerKinds.low+i] = kind
