import win except strip
import deck
import strutils
import sequtils
from algorithm import sorted,sortedByIt
import random
import batch
import colors
import board
import os
 
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
    agro*:int
  Turn* = tuple
    nr:int 
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
  handlesFile = "dat\\handles.txt"
  
  defaultPlayerKinds = @[Human,Computer,None,None,None,None]
  cashToWin* = 500_000
  piecePrice* = 10_000
  startCash* = 50_000
  
  (pbx,pby) = (20,20)
  popUpCard = Rect(x:500,y:275,w:cardWidth*0.9,h:cardHeight*0.9)
  drawPile = Rect(x:855,y:495,w:110,h:180)
  discardPile = Rect(x:1025,y:495,w:cardWidth*0.441,h:cardHeight*0.441)

  inputEntries:seq[string] = @[
    "Write player handle:\n",
    "\n",
  ]
  condensedRegular = "fonts\\AsapCondensed-Regular.ttf"
  titleBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBatchInit = BatchInit(
    kind:InputBatch,
    name:"inputBatch",
    titleOn:true,
    titleLine:(color:color(1,1,0),bgColor:color(0,0,0),border:titleBorder),
    pos:(400,200),
    inputCursor:(0.5,color(0,1,0)),
    inputLine:(color(0,1,0),color(0,0,0),inputBorder),
    padding:(40,40,20,20),
    entries:inputEntries,
    inputMaxChars:8,
    alphaOnly:true,
    font:(condensedRegular,30.0,color(1,1,1)),
    bgColor:color(0,0,0),
    border:(15,25,color(0,0,100)),
    shadow:(15,1.5,color(255,255,255,200))
  )

var 
  inputBatch* = newBatch inputBatchInit
  blueDeck* = newDeck "decks\\blues.txt"
  playerKinds*:array[6,PlayerKind]
  playerBatches*:array[6,Batch]
  playerHandles*:array[6,string]
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
    if playerKinds[playerNr] == Human and playerHandles[playerNr].len > 0:
      @[playerHandles[playerNr]]
    else:
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
  result.entries = playerBatchTxt playerNr

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
  # let gotOneInMany = player.pieces.anyIt it in plan.squares.oneInMany
  plan.squares.oneInmany.len == 0 or 
  player.pieces.anyIt it in plan.squares.oneInMany

func isCashable*(player:Player,plan:BlueCard):bool =
  (player.requiredSquaresOk plan) and (player.oneInManySquaresOk plan)

# func isCashable*(player:Player,plan:BlueCard):bool =
#   let   
#     squaresRequiredOk = player.requiredSquaresOk plan
#     gotOneInMany = player.pieces.anyIt it in plan.squares.oneInMany
#     oneInMoreOk = plan.squares.oneInmany.len == 0 or gotOneInMany
#   squaresRequiredOk and oneInMoreOk

func plans*(player:Player):tuple[cashable,notCashable:seq[BlueCard]] =
  for plan in player.hand:
    if player.isCashable plan: result.cashable.add plan
    else: result.notCashable.add plan

func needsProtectionOn*(player:Player,fromSquare,toSquare:int):bool =
  var hypoPlayer = player
  try: hypoPlayer.pieces[hypoPlayer.pieces.find fromSquare] = toSquare
  except: raise newException(CatchableError,"no piece on: "&($fromSquare))
  hypoPlayer.plans.notCashable
    .anyIt(toSquare in it.squares.required or toSquare in it.squares.oneInMany)

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

proc initPlayers =
  randomize()
  for i,kind in playerKindsFromFile(): playerKinds[i] = kind
  playerHandles = playerHandlesFromFile()
  players = newDefaultPlayers()
  playerBatches = newPlayerBatches()

initPlayers()
blueDeck.initCardSlots discardPile,popUpCard,drawPile

