from algorithm import sorted,sortedByIt
from math import sum
import strutils
import sequtils
import random
import os

type
  Move* = tuple[pieceNr,die,fromSquare,toSquare,eval:int]
  SquareKind = enum GasStation,Highway,Bar,Other
  Board* = array[61,tuple[nr:int,name:string]]
  DieFace* = enum 
    DieFace1 = 1,DieFace2 = 2,DieFace3 = 3,
    DieFace4 = 4,DieFace5 = 5,DieFace6 = 6
  Dice* = array[1..2,DieFace]
  KillablePiece* = tuple[playerNr,pieceNr:int]
  PlayedKind* = enum Drawn,Played,Cashed,Discarded
  Cashable = tuple[cashable,notCashable:seq[BlueCard]]
  CardKind* = enum Deed,Plan,Job,Event,News,Mission
  BlueCard* = object
    title*:string
    case cardKind*:CardKind
    of Plan,Mission,Job,Deed:
      squares*:tuple[required,oneInMany:seq[int]]
      cash*:int
      eval*:int
    of Event,News:
      moveSquares*:seq[int]
      bgPath*:string
  Deck* = object 
    fullDeck*,drawPile*,discardPile*:seq[BlueCard]
    lastDrawn*:string
  Pieces* = array[5,int]
  PlayerKind* = enum Human,Computer,None
  PlayerColor* = enum Red,Green,Blue,Yellow,Black,White
  Player* = object
    color*:PlayerColor
    kind*:PlayerKind
    turnNr*:int
    pieces*:Pieces
    hand*:seq[BlueCard]
    cash*:int
    agro*:int
    update*:bool
  Turn* = tuple
    nr:int 
    playerNr:int
    diceMoved:bool
    undrawnBlues:int
  Game* = object
    gameId:string
    playerKinds*:array[6,PlayerKind]
    blueDeck*:Deck
    diceRoll*:Dice = [DieFace3,DieFace4]
    turn*:Turn
    players*:seq[Player]

const
  playerKindStrs = PlayerKind.mapIt $it
  cardKindStr = CardKind.mapIt ($it).toLower
  playerKindFile* = "dat\\playerkinds.cfg"
  
  defaultPlayerKinds* = [Human,Computer,None,None,None,None]
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
  mainGame*:Game

  # playerKinds*:array[6,PlayerKind]
  # blueDeck*:Deck
  # diceRoll*:Dice = [DieFace3,DieFace4]
  # turn*:Turn
  # players*:seq[Player]
 
template turnPlayer*:untyped = mainGame.players[turn.playerNr]
template playerKinds*:untyped = mainGame.playerKinds
template blueDeck*:untyped = mainGame.blueDeck
template diceRoll*:untyped = mainGame.diceRoll
template turn*:untyped = mainGame.turn
template players*:untyped = mainGame.players
# template getMainGame*:untyped = mainGame

proc newBoard*(path:string):Board =
  var count = 0
  result[0] = (0,"Removed")
  for name in lines path:
    inc count
    result[count] = (count,name)

func isBar*(square:int):bool = squareKind[square] == Bar
func isGasStation*(square:int):bool = squareKind[square] == GasStation
func isHighway*(square:int):bool = squareKind[square] == Highway

func parseProtoCards(lines:seq[string]):seq[array[4,string]] =
  var 
    cardLine:int
    protoCard:array[4,string] 
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

func newBlueCards(protoCards:seq[array[4,string]]):seq[BlueCard] =
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

template adjustToSquareNr*(adjustSquare:untyped):untyped =
  if adjustSquare > 60: adjustSquare - 60 else: adjustSquare

template canKillPieceOn*(square:int):untyped =
  square != 0 and not square.isHighway and not square.isGasStation

template moveToSquare(fromSquare,die:untyped):untyped = 
  adjustToSquareNr fromSquare+die

func moveToSquares*(fromSquare,die:int):seq[int] =
  if fromsquare != 0: result.add moveToSquare(fromSquare,die)
  else: result.add highways.mapIt moveToSquare(it,die)
  if fromSquare.isHighway or fromsquare == 0:      
    result.add gasStations.mapIt moveToSquare(it,die)
  result.filterIt(it != fromSquare).deduplicate

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

proc rollDice*(diceRoll:var Dice) = 
  for die in diceRoll.mitems: 
    die = DieFace(rand(1..6))

func isDouble*(diceRoll:Dice): bool = diceRoll[1] == diceRoll[2]

func diceMoved*(fromSquare,toSquare:int):bool =
  if fromSquare == 0:
    not tosquare.isGasStation and not toSquare.isHighway
  elif fromSquare.isHighway:
    not toSquare.isGasStation
  else: true

func movesFrom*(turn:Turn,diceRoll:Dice,square:int):seq[int] =
  if turn.diceMoved: moveToSquares square
  else: moveToSquares(square,diceRoll)

# template turnPlayer*:untyped = players[turn.playerNr]

func anyHuman*(players:seq[Player]):bool =
  players.anyIt it.kind == Human

func anyComputer*(players:seq[Player]):bool =
  players.anyIt it.kind == Computer

func anyHandles*(handles:seq[string]):bool =
  handles.anyIt it.len > 0

func nrOfRemovedPieces*(player:Player):int =
  player.pieces.count 0

iterator legalPiecesIter*(pieces:openArray[int],cash:int):(int,int) =
  let nrAllowed = cash div piecePrice
  var count = 0
  for pieceNr,square in pieces:
    if square == 0:
      if count == nrAllowed:
        yield (pieceNr,-1)
        continue
      inc count
    yield (pieceNr,square)

func legalPiecesCount*(player:Player):int =
  for _,square in player.pieces.legalPiecesIter player.cash:
    if square > -1: inc result

iterator playersInColorsOtherThan*(players:seq[Player],color:PlayerColor):Player =
  for player in players:
    if player.color != color: yield player

iterator piecesInColorsOtherThan*(players:seq[Player],color:PlayerColor):int =
  for player in players.playersInColorsOtherThan color:
    for piece in player.pieces: yield piece

iterator piecesOn*(players:seq[Player],square:int):(int,int) =
  for playerNr,player in players:
    for pieceNr,piece in player.pieces:
      if piece == square: 
        yield (playerNr,pieceNr)

func pieceNrOnSquare*(player:Player,square:int):int =
  for i,piece in player.pieces:
    if piece == square: return i
  -1

func nrOfPiecesOn*(players:seq[Player],square:int):int =
  players.mapIt(it.pieces.countIt it == square).sum

func killablePieceOn*(players:seq[Player],square:int):KillablePiece =
  result = (-1,-1)
  if canKillPieceOn(square):
    var count = 0
    for playerNr,player in players:
      for pieceNr,piece in player.pieces:
        if piece == square: 
          inc count
          if count > 1: 
            return (-1,-1)
          else: result = (playerNr,pieceNr)

func nrOfPiecesOnBars*(player:Player):int =
  player.pieces.countIt it.isBar

func hasPieceOn*(player:Player,square:int):bool =
  for pieceSquare in player.pieces:
    if pieceSquare == square: return true

func hasLegalPieceOn*(player:Player,square:int):bool =
  for _,pieceSquare in player.pieces.legalPiecesIter player.cash:
    if pieceSquare == square: return true

func piecesOnBars*(player:Player):seq[int] = 
  for square in player.pieces:
    if square.isBar: result.add square

iterator pieceNrsOnBars*(player:Player):int =
  for pieceNr,square in player.pieces:
    if square.isBar: yield pieceNr

template requiredSquaresOk(pieces,card:untyped):untyped =
  card.squares.required.deduplicate
    .allIt pieces.count(it) >= card.squares.required.count it

template oneInManySquaresOk(pieces,card:untyped):untyped =
  card.squares.oneInmany.len == 0 or 
  pieces.anyIt it in card.squares.oneInMany

func isCashable*(pieces:openArray[int],card:BlueCard):bool =
  (pieces.requiredSquaresOk card) and (pieces.oneInManySquaresOk card)

func cashesIn*(pieces:openArray[int],cards:seq[BlueCard]):Cashable =
  for card in cards:
    if pieces.isCashable card: result.cashable.add card
    else: result.notCashable.add card

proc discardCards*(player:var Player,deck:var Deck):seq[BlueCard] =
  while player.hand.len > 3:
    result.add player.hand[player.hand.high]
    player.hand.playTo deck,player.hand.high

proc cashInPlansTo*(player:var Player,deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = player.pieces.cashesIn player.hand
  for plan in cashable.sortedByIt it.cash:
    deck.discardPile.add plan
  player.hand = notCashable
  player.cash += cashable.mapIt(it.cash).sum
  cashable

proc newGameSetupPlayers*(playerKinds:array[6,PlayerKind]):seq[Player] =
  for i,kind in playerKinds:
    result.add Player(
      kind:kind,
      color:PlayerColor(i),
      pieces:highways
    )

proc newGamePlayers*(gameSetupPlayers:seq[Player]):seq[Player] =
  var 
    randomPosition = rand(5)
    playerSlots:array[6,Player]
  for player in gameSetupPlayers:
    while playerSlots[randomPosition].cash != 0: 
      randomPosition = rand(5)
    playerSlots[randomPosition] = Player(
      color:player.color,
      kind:player.kind,
      pieces:highways,
      cash:startCash,
      agro:rand 0..9
    )
  playerSlots.filterIt it.kind != None

proc playerKindsFromFile*:array[6,PlayerKind] =
  try:
    for idx,line in playerKindFile.readFile.splitLines.toSeq:
      result[idx] = PlayerKind(playerKindStrs.find(line))
  except: result = defaultPlayerKinds

proc playerKindsToFile*(playerKinds:openArray[PlayerKind]) =
  playerKindFile.writeFile(playerKinds.mapIt($it).join "\n")

template initGame* =
  randomize()
  board = newBoard "dat\\board.txt"
  blueDeck = newDeck "decks\\blues.txt"
  playerKinds = playerKindsFromFile()
  players = newGameSetupPlayers(playerKinds)
  mainGame.gameId = "main"
