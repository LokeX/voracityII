from algorithm import sorted,sortedByIt
from math import sum
import strutils
import sequtils
import random
import os

type
  MoveSelection* = tuple
    hoverSquare,fromSquare,toSquare:int
    toSquares:seq[int]
    event:bool
  Board* = array[61,tuple[nr:int,name:string]]
  PlayerColor* = enum Red,Green,Blue,Yellow,Black,White
  DieFace* = enum 
    DieFace1 = 1,DieFace2 = 2,DieFace3 = 3,
    DieFace4 = 4,DieFace5 = 5,DieFace6 = 6
  Dice* = array[1..2,DieFace]
  ProtoCard = array[4,string]
  PlanSquares = tuple[required,oneInMany:seq[int]]
  CardKind* = enum Deed,Plan,Job,Event,News,Mission
  BlueCard* = object
    title*:string
    case cardKind*:CardKind
    of Plan,Mission,Job,Deed:
      squares*:PlanSquares
      cash*:int
      eval*:int
      covered*:bool
    of Event,News:
      moveSquares*:seq[int]
      bgPath*:string
  Deck* = object 
    fullDeck*,drawPile*,discardPile*:seq[BlueCard]
    lastDrawn*:string
  PlayerKind* = enum Human,Computer,None
  Pieces* = array[5,int]
  Player* = object
    color*:PlayerColor
    kind*:PlayerKind
    turnNr*:int
    pieces*:Pieces
    hand*:seq[BlueCard]
    cash*:int
    agro*:int
    skipped*:int
    update*:bool
  Turn* = tuple
    nr:int 
    player:int
    diceMoved:bool
    undrawnBlues:int

const
  kindFile* = "dat\\playerkinds.cfg"
  handlesFile = "dat\\handles.txt"
  
  defaultPlayerKinds* = @[Human,Computer,None,None,None,None]
  cashToWin* = 1_000_000
  piecePrice* = 10_000
  startCash* = 50_000
  
  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]
  bars* = [1,16,18,20,28,35,40,46,51,54]

proc newBoard*(path:string):Board =
  var count = 0
  result[0] = (0,"Removed")
  for name in lines path:
    inc count
    result[count] = (count,name)

proc newDeck*(path:string):Deck

var 
  diceRoll*:Dice = [DieFace3,DieFace4]
  turn*:Turn
  blueDeck* = newDeck "decks\\blues.txt"
  board* = newBoard "dat\\board.txt"
  playerKinds*:array[6,PlayerKind]
  playerHandles*:array[6,string]
  players*:seq[Player]
  moveSelection*:MoveSelection = (-1,-1,-1,@[],false)
  diceRolls*:seq[Dice]

func parseProtoCards(lines:sink seq[string]):seq[ProtoCard] =
  var 
    cardLine:int
    protoCard:ProtoCard 
  for line in lines:
    protocard[cardLine] = line
    if cardLine == 3:
      result.add protoCard
      cardLine = 0
    else: inc cardLine

func parseCardSquares(str:string,brackets:array[2,char]):seq[int] =
  let (f,l) = (str.find(brackets[0]),str.find(brackets[1]))
  if -1 in [f,l]: @[] else: str[f+1..l-1].split(',').mapIt it.parseInt

func parseCardKindFrom(kind:string):CardKind =
  try: CardKind(CardKind.mapIt(($it).toLower).find kind[0..kind.high-1].toLower) 
  except: raise newException(CatchableError,"Error, parsing CardKind: "&kind)

func newBlueCards(protoCards:seq[ProtoCard]):seq[BlueCard] =
  var card:BlueCard
  for protoCard in protoCards:
    card = BlueCard(title:protoCard[1],cardKind:parseCardKindFrom protoCard[0])
    if card.cardKind in [Event,News]:
      card.moveSquares = parseCardSquares(protoCard[2],['{','}'])
      card.bgPath = protoCard[3]
    else:
      card.squares = (
        parseCardSquares(protoCard[2],['{','}']),
        parseCardSquares(protoCard[2],['[',']']),
      )
      card.cash = protoCard[3].parseInt
    result.add card

proc newDeck*(path:string):Deck =
  result = Deck(fullDeck:path.lines.toSeq.parseProtoCards.newBlueCards)
  result.drawPile = result.fullDeck
  result.drawPile.shuffle

proc resetDeck*(deck:var Deck) =
  deck.discardPile.setLen 0
  deck.drawPile = deck.fullDeck
  deck.drawPile.shuffle
  deck.lastDrawn = ""

proc shufflePiles*(deck:var Deck) =
  deck.drawPile.add deck.discardPile
  deck.discardPile.setLen 0
  deck.drawPile.shuffle

proc drawFrom*(hand:var seq[BlueCard],deck:var Deck) =
  if deck.drawPile.len == 0:
    deck.shufflePiles
  hand.add deck.drawPile.pop
  deck.lastDrawn = hand[^1].title

proc drawFromDiscardPile*(hand:var seq[BlueCard],deck:var Deck) =
  if deck.discardPile.len > 0:
    hand.add deck.discardPile.pop
    deck.lastDrawn = hand[^1].title

proc playTo*(hand:var seq[BlueCard],deck:var Deck,card:int) =
  deck.discardPile.add hand[card]
  hand.del card

proc rollDice*() = 
  for die in diceRoll.mitems: 
    die = DieFace(rand(1..6))

proc isDouble*: bool = diceRoll[1] == diceRoll[2]

func adjustToSquareNr*(adjustSquare:int):int =
  if adjustSquare > 60: adjustSquare - 60 else: adjustSquare

func canKillPieceOn*(square:int):bool =
  square notIn highways and square notIn gasStations

func moveToSquare(fromSquare:int,die:int):int = 
  adjustToSquareNr fromSquare+die

func moveToSquares*(fromSquare,die:int):seq[int] =
  if fromsquare != 0: result.add moveToSquare(fromSquare,die)
  else: result.add highways.mapIt moveToSquare(it,die)
  if fromSquare in highways or fromsquare == 0:      
    result.add gasStations.mapIt moveToSquare(it,die)
  result = result.filterIt(it != fromSquare).deduplicate

func moveToSquares*(fromSquare:int):seq[int] =
  if fromSquare == 0: 
    result.add highways
    result.add gasStations
  elif fromSquare in highways: 
    result.add gasStations

func moveToSquares*(fromSquare:int,dice:Dice):seq[int] =
  result.add moveToSquares fromSquare
  for i,die in dice:
    if i == 1 or dice[1] != dice[2]:
      result.add moveToSquares(fromSquare,die.ord)
  result.deduplicate

func diceMoved*(fromSquare,toSquare:int):bool =
  if fromSquare == 0:
    tosquare notin gasStations and toSquare notin highways
  elif fromSquare in highways:
    toSquare notin gasStations
  else: true

func dieUsed*(fromSquare,toSquare:int,dice:Dice):int =
  if toSquare in moveToSquares(fromSquare,dice[1].ord):
    dice[1].ord
  elif toSquare in moveToSquares(fromSquare,dice[2].ord):
    dice[2].ord
  else: -1

proc movesFrom*(player:Player,square:int):seq[int] =
  if turn.diceMoved: moveToSquares square
  else: moveToSquares(square,diceRoll)

template turnPlayer*:untyped = players[turn.player]

func anyHuman*(players:seq[Player]):bool =
  players.anyIt it.kind == Human

func anyComputer*(players:seq[Player]):bool =
  players.anyIt it.kind == Computer

func anyHandles*(handles:seq[string]):bool =
  handles.anyIt it.len > 0

func removedPieces*(player:Player):int =
  player.pieces.count 0

func indexFromColor*(players:seq[Player],playerColor:PlayerColor):int =
  for i,player in players:
    if player.color == playerColor: return i
  result = -1

func knownBluesIn(discardPile,hand:seq[BlueCard]):seq[BlueCard] =
  result.add discardPile
  result.add hand

func require(cards:seq[BlueCard],square:int): seq[BlueCard] =
  cards.filterIt(square in it.squares.required or square in it.squares.oneInMany)

func cashChanceOn*(player:Player,square:int,deck:Deck): float =
  let 
    knownCards = knownBluesIn(deck.discardPile,player.hand)
    unknownCards = deck.fullDeck
      .filterIt(
        it.cardKind notin [News,Event] and
        it.title notIn knownCards.mapIt(it.title)
      )
    chance = unknownCards.require(square).len.toFloat/unknownCards.len.toFloat
  chance*player.hand.len.toFloat

func piecesOn*(players:seq[Player],square:int):seq[tuple[playerNr,pieceNr:int]] =
  for playerNr,player in players:
    for pieceNr,piece in player.pieces:
      if piece == square: result.add (playerNr,pieceNr)

func nrOfPiecesOn*(players:seq[Player],square:int):int =
  players.mapIt(it.pieces.countIt it == square).sum

func nrOfPiecesOnBars*(player:Player): int =
  player.pieces.countIt it in bars

func hasPieceOn*(player:Player,square:int):bool =
  for pieceSquare in player.pieces:
    if pieceSquare == square: return true

func onBars*(player:Player):seq[int] = bars.filterIt player.hasPieceOn it

func requiredSquaresOk*(player:Player,plan:BlueCard):bool =
  plan.squares.required.deduplicate
    .allIt player.pieces.count(it) >= plan.squares.required.count it

func oneInManySquaresOk*(player:Player,plan:BlueCard):bool =
  plan.squares.oneInmany.len == 0 or 
  player.pieces.anyIt it in plan.squares.oneInMany

func isCashable*(player:Player,plan:BlueCard):bool =
  (player.requiredSquaresOk plan) and (player.oneInManySquaresOk plan)

func plans*(player:Player):tuple[cashable,notCashable:seq[BlueCard]] =
  for plan in player.hand:
    if player.isCashable plan: result.cashable.add plan
    else: result.notCashable.add plan

proc discardCards*(player:var Player,deck:var Deck):seq[BlueCard] =
  while player.hand.len > 3:
    result.add player.hand[player.hand.high]
    player.hand.playTo deck,player.hand.high

proc cashInPlansTo*(deck:var Deck):seq[BlueCard] =
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
      color:PlayerColor(i),
      pieces:highways
    )

proc newPlayers*:seq[Player] =
  var 
    randomPosition = rand(5)
    playerSlots:array[6,Player]
  for player in players:
    while playerSlots[randomPosition].cash != 0: 
      randomPosition = rand(5)
    playerSlots[randomPosition] = Player(
      color:player.color,
      kind:player.kind,
      pieces:highways,
      cash:startCash,
      agro:rand 1..100
    )
  playerSlots.filterIt it.kind != None

proc nextPlayerTurn* =
  turn.diceMoved = false
  turnPlayer.turnNr = turn.nr
  # batchUpdate[turn.player] = true
  turnPlayer.update = true
  if turn.player == players.high:
    inc turn.nr
    turn.player = players.low
  else: inc turn.player
  turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars
  blueDeck.lastDrawn = ""

proc playerHandlesToFile*(playerHandles:openArray[string]) =
  writeFile(handlesFile,playerHandles.mapIt(if it.len > 0: it else: "n/a").join "\n")

proc playerHandlesFromFile:array[6,string] =
  if fileExists handlesFile:
    var count = 0
    for line in lines handlesFile:
      let lineStrip = line.strip
      if lineStrip != "n/a":
        result[count] = lineStrip
      inc count

proc initPlayers* =
  playerHandles = playerHandlesFromFile()
  players = newDefaultPlayers()
