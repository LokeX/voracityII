import win
import deck
import sequtils
import algorithm

type
  PlayerKind* = enum Human,Computer,None
  PlayerColors* = enum Red,Green,Blue,Yellow,Black,White
  Player* = ref object
    nr*:int
    color*:PlayerColors
    kind*:PlayerKind
    batch*:AreaHandle
    turnNr*:int
    piecesOnSquares*:array[5,int]
    hand*:seq[BlueCard]
    cash*:int
  Turn* = ref object
    nr*:int
    player*:Player
    diceMoved*:bool
    undrawnBlues*:int

var
  players*:array[1..6,Player]
  turn*:Turn = nil

proc discardCards*(deck:var Deck) =
  while turn.player.hand.len > 3:
    turn.player.hand.playTo deck.discardPile,turn.player.hand.high

proc discardCard*(deck:var Deck,index:int) =
  if index < turn.player.hand.len:
    turn.player.hand.playTo deck.discardPile,index
    turn.player.hand.del(index)

func requiredSquaresAndPieces*(plan:BlueCard):tuple[squares,nrOfPieces:seq[int]] =
  let squares = plan.squares.required.deduplicate()
  (squares,squares.mapIt(plan.squares.required.count(it)))

proc hasOneInManyFor(player:Player,plan:BlueCard):bool =
  player.piecesOnSquares.anyIt(it in plan.squares.oneInMany)

proc hasCashable*(player:Player,plan:BlueCard):bool =
  let 
    (squares,nrOfPiecesRequired) = plan.requiredSquaresAndPieces()
    nrOfPiecesOnSquares = squares.mapIt(player.piecesOnSquares.count(it))
    requiredOk = toSeq(0..squares.len-1).allIt(nrOfPiecesOnSquares[it] >= nrOfPiecesRequired[it])
    oneInMoreOk = plan.squares.oneInmany.len == 0 or player.hasOneInManyFor plan
  requiredOk and oneInMoreOk

proc plans*(player:Player):tuple[cashable,notCashable:seq[BlueCard]] =
  for plan in player.hand.filterIt it.cardKind == Plan:
    if player.hasCashable plan:
      result.cashable.add plan
    else:
      result.notCashable.add plan

proc turnPlayerPlans*:tuple[cashable,notCashable:seq[BlueCard]] = turn.player.plans

proc cashInPlans*(deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = turn.player.plans
  cashable.sortedByIt(it.cash).playManyTo deck.discardPile
  turn.player.hand = notCashable
  turn.player.cash += cashable.mapIt(it.cash).sum
  cashable

# proc drawBlueCard*(cardTitle:string) = 
#   if nrOfUndrawnBlueCards > 0:
#     if blueCards.len == 0:
#       shuffleBlueCards()
#     var index = -1 
#     if cardTitle.len > 0:
#       index = blueCards.mapIt(it.title).find(cardTitle)
#     if index == -1:
#       turn.player.cards.add(blueCards.pop)
#     else:
#       turn.player.cards.add(blueCards[index])
#       blueCards.delete(index)
#     dec nrOfUndrawnBlueCards

# proc drawBlueCard*() = drawBlueCard("")

# proc rollDice*() = 
#   for i,die in dice: dice[i] = rand(1..6)

# proc isRollingDice*(): bool =
#   dieRollFrame < maxRollFrames

# proc nrOfPlayers*(): int =
#   players.filterIt(it.kind != none).len

# proc newDefaultPlayers*(): array[1..6,Player] =
#   for i in 1..6:
#     result[i] = Player(
#       nr:i,
#       kind:playerKinds[i],
#       color:PlayerColors(i-1),
#       piecesOnSquares:highways
#     )
# #    echo players[i].kind

# proc newPlayers*(kind:array[6,PlayerKind]): array[1..6,Player] =
#   randomize()
#   var randomPosition = rand(1..6)
#   for color in PlayerColors:
#     while result[randomPosition] != nil: 
#       randomPosition = rand(1..6)
#     result[randomPosition] = Player(
#       nr:randomPosition,
#       color:color,
#       kind:kind[color.ord],
#       piecesOnSquares:highways,
#       cash:25000
#     )

# proc nextPlayerTurn*() =
#   if turn != nil: discardCards()
#   startDiceRoll()
#   let contesters = players.filterIt(it.kind != none)
#   if turn == nil: turn = Turn(nr:1,player:contesters[0]) else:
#     let
#       isLastPlayer = turn.player.nr == contesters[^1].nr
#       turnNr = if isLastPlayer: turn.nr+1 else: turn.nr
#       nextPlayer = if isLastPlayer: contesters[0] else:
#         contesters[contesters.mapIt(it.nr).find(turn.player.nr)+1]
#     turn = Turn(nr:turnNr,player:nextPlayer)
#   turn.player.turnNr = turn.nr 
#   nrOfUndrawnBlueCards = countNrOfUndrawnBlueCards() 

# proc playerKindsFromFile*(): seq[PlayerKind] =
#   try:
#     readFile(settingsFile)
#     .split("@[,]\" ".toRunes)
#     .filterIt(it.len > 0)
#     .mapIt(PlayerKind(PlayerKind.mapIt($it).find(it)))
#   except: return

# proc playerKindsToFile*() =
#   writeFile(settingsFile,$playerKinds.mapIt($it))

# players = newDefaultPlayers()
# for i,kind in playerKindsFromFile(): 
#   playerKinds[playerKinds.low+i] = kind
