from algorithm import sorted,sortedByIt
from math import sum
import strutils
import sequtils
import random
import os

type
  PlayerKind* = enum Human,Computer,None
  Move* = tuple[pieceNr,die,fromSquare,toSquare,eval:int]
  CashedCards* = seq[tuple[title:string,count:int]]  
  PlayedCard* = enum Drawn,Played,Cashed,Discarded
  MoveSelection* = tuple
    fromSquare,toSquare:int
    toSquares:seq[int]
    event:bool
  SquareKind = enum GasStation,Highway,Bar,Other
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
    of Event,News:
      moveSquares*:seq[int]
      bgPath*:string
  Deck* = object 
    fullDeck*,drawPile*,discardPile*:seq[BlueCard]
    lastDrawn*:string
  Pieces* = array[5,int]
  Player* = object
    color*:PlayerColor
    kind*:PlayerKind
    turnNr*:int
    pieces*:Pieces
    hand*:seq[BlueCard]
    cash*:int
    agro*:int
    # skipped*:int
    update*:bool
  Turn* = tuple
    nr:int 
    player:int
    diceMoved:bool
    undrawnBlues:int

const
  playerKindStrs = PlayerKind.mapIt $it
  cardKindStr = CardKind.mapIt ($it).toLower
  playerKindFile* = "dat\\playerkinds.cfg"
  handlesFile = "dat\\handles.txt"
  
  defaultPlayerKinds* = @[Human,Computer,None,None,None,None]
  cashToWin* = 1_000_000
  piecePrice* = 10_000
  startCash* = 50_000
  
  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]
  bars* = [1,16,18,20,28,35,40,46,51,54]

func squareKinds:array[0..60,SquareKind] =
  for idx in 0..60:
    result[idx] =
      if idx in highways:
       Highway
      elif idx in gasStations:
        GasStation
      elif idx in bars:
        Bar
      else: Other

const
  squareKind = squareKinds()

var 
  board*:Board
  blueDeck*:Deck
  diceRoll*:Dice = [DieFace3,DieFace4]
  turn*:Turn
  playerKinds*:array[6,PlayerKind]
  playerHandles*:array[6,string]
  players*:seq[Player]
  moveSelection*:MoveSelection = (-1,-1,@[],false)

proc newBoard*(path:string):Board =
  var count = 0
  result[0] = (0,"Removed")
  for name in lines path:
    inc count
    result[count] = (count,name)

func isBar*(square:int):bool = squareKind[square] == Bar
func isGasStation*(square:int):bool = squareKind[square] == GasStation
func isHighway*(square:int):bool = squareKind[square] == Highway

func parseProtoCards(lines:seq[string]):seq[ProtoCard] =
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
  try: CardKind(cardKindStr.find kind[0..kind.high-1].toLower) 
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

func adjustToSquareNr*(adjustSquare:int):int =
  if adjustSquare > 60: adjustSquare - 60 else: adjustSquare

func canKillPieceOn*(square:int):bool =
  not square.isHighway and not square.isGasStation

func moveToSquare(fromSquare:int,die:int):int = 
  adjustToSquareNr fromSquare+die

func moveToSquares*(fromSquare,die:int):seq[int] =
  if fromsquare != 0: result.add moveToSquare(fromSquare,die)
  else: result.add highways.mapIt moveToSquare(it,die)
  if fromSquare.isHighway or fromsquare == 0:      
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

proc rollDice*() = 
  for die in diceRoll.mitems: 
    die = DieFace(rand(1..6))

proc isDouble*: bool = diceRoll[1] == diceRoll[2]

func diceMoved*(fromSquare,toSquare:int):bool =
  if fromSquare == 0:
    not tosquare.isGasStation and not toSquare.isHighway
  elif fromSquare.isHighway:
    not toSquare.isGasStation
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

func nrOfRemovedPieces*(player:Player):int =
  player.pieces.count 0

# func indexFromColor*(players:seq[Player],playerColor:PlayerColor):int =
#   for i,player in players:
#     if player.color == playerColor: return i
#   result = -1

func piecesOn*(players:seq[Player],square:int):seq[tuple[playerNr,pieceNr:int]] =
  for playerNr,player in players:
    for pieceNr,piece in player.pieces:
      if piece == square: result.add (playerNr,pieceNr)

func pieceOnSquare*(player:Player,square:int):int =
  for i,piece in player.pieces:
    if piece == square: return i

func nrOfPiecesOn*(players:seq[Player],square:int):int =
  players.mapIt(it.pieces.countIt it == square).sum

func nrOfPiecesOnBars*(player:Player): int =
  player.pieces.countIt it.isBar

func hasPieceOn*(player:Player,square:int):bool =
  for pieceSquare in player.pieces:
    if pieceSquare == square: return true

func piecesOnBars*(player:Player):seq[int] = 
  for square in player.pieces:
    if square.isBar: result.add square

func pieceNrsOnBars*(player:Player):seq[int] =
  for nr,square in player.pieces:
    if square.isBar: result.add nr

template requiredSquaresOk(player,plan:untyped):untyped =
  plan.squares.required.deduplicate
    .allIt player.pieces.count(it) >= plan.squares.required.count it

template oneInManySquaresOk(player,plan:untyped):untyped =
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

proc cashInPlansTo*(player:var Player,deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = player.plans
  for plan in cashable.sortedByIt it.cash:
    deck.discardPile.add plan
  player.hand = notCashable
  player.cash += cashable.mapIt(it.cash).sum
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
      agro:rand 0..9
    )
  result = playerSlots.filterIt it.kind != None

proc nextPlayerTurn* =
  turn.diceMoved = false
  turnPlayer.turnNr = turn.nr
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

proc playerKindsFromFile:seq[PlayerKind] =
  try:
    playerKindFile.readFile.splitLines
    .mapIt(PlayerKind(playerKindStrs.find(it)))
  except: defaultPlayerKinds

proc playerKindsToFile*(playerKinds:openArray[PlayerKind]) =
  playerKindFile.writeFile(playerKinds.mapIt($it).join "\n")

template initGame* =
  randomize()
  board = newBoard "dat\\board.txt"
  blueDeck = newDeck "decks\\blues.txt"
  for i,kind in playerKindsFromFile(): playerKinds[i] = kind
  playerHandles = playerHandlesFromFile()
  players = newDefaultPlayers()
