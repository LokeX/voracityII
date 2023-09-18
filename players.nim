import win
import deck
import sequtils
import algorithm
import random

type
  PlayerKind* = enum Human,Computer,None
  PlayerColors* = enum Red,Green,Blue,Yellow,Black,White
  Players = array[1..6,Player]
  Player* = object
    nr*:int
    color*:PlayerColors
    kind*:PlayerKind
    turnNr*:int
    pieces*:array[5,int]
    hand*:seq[BlueCard]
    cash*:int
  Turn* = object
    nr*:int
    player*:Player
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
  players*:Players
  turn*:Turn

proc nrOfPiecesOnBars(player:Player): int =
  player.pieces.countIt(it in bars)

proc drawFrom*(deck:var Deck) =
  if turn.undrawnBlues > 0:
    if deck.drawPile.len == 0:
      deck.shufflePiles
    turn.player.hand.add deck.drawPile.pop
    dec turn.undrawnBlues

proc drawFrom*(deck:var Deck,nr:int) =
  if deck.drawPile.len == 0: deck.shufflePiles
  for _ in 1..nr: turn.player.hand.add deck.drawPile.pop

proc playTo*(deck:var Deck,idx:int) =
  deck.discardPile.add turn.player.hand[idx]
  turn.player.hand.del idx

proc discardCards*(deck:var Deck) =
  while turn.player.hand.len > 3:
    playTo deck,turn.player.hand.high

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

proc turnPlayerPlans*:tuple[cashable,notCashable:seq[BlueCard]] = turn.player.plans

proc cashInPlans*(deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = turn.player.plans
  for plan in cashable.sortedByIt it.cash:
    deck.discardPile.add plan
  turn.player.hand = notCashable
  turn.player.cash += cashable.mapIt(it.cash).sum
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
    for (_,slot) in turn.player.hand.cardSlots:
      if mouseOn slot.area: 
        playTo deck,slot.nr

proc nrOfPlayers*: int =
  players.filterIt(it.kind != None).len

proc newDefaultPlayers*:Players =
  for i in 1..6:
    result[i] = Player(
      nr:i,
      kind:playerKinds[i],
      color:PlayerColors(i-1),
      pieces:highways
    )

proc newPlayers*(kind:openarray[PlayerKind]):Players =
  randomize()
  var randomPosition = rand(1..6)
  for color in PlayerColors:
    while result[randomPosition].nr != 0: 
      randomPosition = rand(1..6)
    result[randomPosition] = Player(
      nr:randomPosition,
      color:color,
      kind:kind[color.ord],
      pieces:highways,
      cash:25000
    )

proc nextPlayerTurn* =
  # discardCards()
  # startDiceRoll()
  let contesters = players.filterIt(it.kind != None)
  if turn.nr == 0: turn = Turn(nr:1,player:contesters[0]) else:
    let
      isLastPlayer = turn.player.nr == contesters[^1].nr
      turnNr = if isLastPlayer: turn.nr+1 else: turn.nr
      nextPlayer = if isLastPlayer: contesters[0] else:
        contesters[contesters.mapIt(it.nr).find(turn.player.nr)+1]
    turn = Turn(nr:turnNr,player:nextPlayer)
  turn.player.turnNr = turn.nr 
  turn.undrawnBlues = turn.player.nrOfPiecesOnBars

proc playerKindsFromFile:seq[PlayerKind] =
  try:
    readFile(settingsFile)
    .split("@[,]\" ".toRunes)
    .filterIt(it.len > 0)
    .mapIt(PlayerKind(PlayerKind.mapIt($it).find(it)))
  except: return

proc playerKindsToFile* =
  writeFile(settingsFile,$playerKinds.mapIt($it))

players = newDefaultPlayers()
for i,kind in playerKindsFromFile(): 
  playerKinds[playerKinds.low+i] = kind
