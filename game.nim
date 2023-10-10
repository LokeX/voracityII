import win
import deck
import strutils
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
  BatchSetup = tuple
    name:string
    bgColor:PlayerColor
    entries:seq[string]
    hAlign:HorizontalAlignment
    font:string
    fontSize:float
    padding:(int,int,int,int)

const
  roboto* = "fonts\\Kalam-Bold.ttf"
  fjallaOneRegular* = "fonts\\FjallaOne-Regular.ttf"
  ibmBold* = "fonts\\IBMPlexMono-Bold.ttf"
  settingsFile* = "settings.cfg"
  defaultPlayerKinds = @[Human,Computer,None,None,None,None]
  (pbx,pby) = (20,20)
  cashToWin* = 250_000
  popUpCard = Rect(x:500,y:275,w:cardWidth,h:cardHeight)
  drawPile = Rect(x:855,y:495,w:110,h:180)
  discardPile = Rect(x:1025,y:495,w:cardWidth*0.441,h:cardHeight*0.441)

var 
  blueDeck* = newDeck "dat\\blues.txt"
  playerKinds*:array[6,PlayerKind]
  playerBatches*:array[6,Batch]
  players*:seq[Player]
  turn*:Turn
  showCursor*:bool

template turnPlayer*:untyped = players[turn.player]

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
    border:(3,20,contrastColors[setup.bgColor]),
    blur:2,
    opacity:25,
    bgColor:playerColors[setup.bgColor],
    shadow:(10,1.75,color(255,255,255,100))
  )

proc playerBatchTxt(playerNr:int):seq[string] =
  if turn.nr == 0:
    @[$playerKinds[playerNr]]
  else: @[
    "Turn Nr: "&($turn.nr)&"\n",
    "Cards: "&($players[playerNr].hand.len)&"\n",
    "Cash: "&(insertSep($players[playerNr].cash,'.'))
  ]

proc updateBatch*(playerNr:int) =
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
    result.padding = (20,20,12,10)
  result.entries = playerBatchTxt(playerNr)

proc newPlayerBatches*:array[6,Batch] =
  var 
    yOffset = pby
    setup:BatchSetup
  for playerNr,_ in players:
    if playerNr > 0: 
      yOffset = pby+((result[playerNr-1].rect.h.toInt+15)*playerNr)
    setup = batchSetup playerNr
    result[playerNr] = setup.playerBatch yOffset
    result[playerNr].update = true

func nrOfPiecesOnBars*(player:Player): int =
  player.pieces.countIt it in bars

func hasPieceOn*(player:Player,square:int):bool =
  for pieceSquare in player.pieces:
    if pieceSquare == square: return true

proc discardCards*(player:var Player,deck:var Deck) =
  while player.hand.len > 3:
    player.hand.playTo deck,player.hand.high

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

proc cashInPlansTo*(deck:var Deck):seq[BlueCard] =
  let (cashable,notCashable) = turnPlayer.cashablePlans
  for plan in cashable.sortedByIt it.cash:
    deck.discardPile.add plan
  turnPlayer.hand = notCashable
  turnPlayer.cash += cashable.mapIt(it.cash).sum
  cashable

func nrOfPiecesOn*(players:seq[Player],square:int):int =
  players.mapIt(it.pieces.countIt it == square).sum

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
      cash:25000
    )
  playerSlots.filterIt it.kind != None

proc nextPlayerTurn* =
  turn.diceMoved = false
  turnPlayer.turnNr = turn.nr
  turn.player.updateBatch
  if turn.player == players.high:
    inc turn.nr
    turn.player = players.low
  else: inc turn.player
  turn.player.updateBatch
  turn.undrawnBlues = turnPlayer.nrOfPiecesOnBars
  blueDeck.lastDrawn = ""

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
blueDeck.initCardSlots discardPile,popUpCard,drawPile

when isMainModule:
  printPlayers()
  players = newPlayers()
  printPlayers()

