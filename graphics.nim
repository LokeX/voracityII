import win
import batch
import strutils
import game
import megasound
import sequtils
import random
import play

type
  BoardSquares* = array[61,Square]
  Square* = tuple[nr:int,name:string,dims:Dims]
  Dims* = tuple[area:Area,rect:Rect]
  AnimationMove* = tuple[fromSquare,toSquare:int]
  MoveAnimation* = object
    active*:bool
    frame,moveOnFrame,currentSquare,fromsquare*,toSquare*:int
    color: PlayerColor
    movesIdx:int
    moves:seq[AnimationMove]
    squares:seq[int]
  BatchSetup = tuple
    name:string
    bgColor:PlayerColor
    entries:seq[string]
    hAlign:HorizontalAlignment
    font:string
    fontSize:float
    padding:(int,int,int,int)

const
  playerColors*:array[PlayerColor,Color] = [
    color(50,0,0),color(0,50,0),
    color(0,0,50),color(50,50,0),
    color(255,255,255),color(1,1,1)
  ]
  playerColorsTrans*:array[PlayerColor,Color] = [
    color(50,0,0,150),color(0,50,0,150),
    color(0,0,50,150),color(50,50,0,150),
    color(255,255,255,150),color(1,1,1,150)
  ]
  contrastColors*:array[PlayerColor,Color] = [
    color(1,1,1),color(255,255,255),
    color(1,1,1),color(255,255,255),
    color(1,1,1),color(255,255,255),
  ]
  (humanRoll*, computerRoll*) = (0,80)
  diceRollRects = (Rect(x:1450,y:60,w:50,h:50),Rect(x:1450,y:120,w:50,h:50))
  diceRollDims:array[1..2,Dims] = [
    (diceRollRects[0].toArea, diceRollRects[0]),
    (diceRollRects[1].toArea, diceRollRects[1])
  ]
  boardPos = vec2(225,50)
  (bx*,by*) = (boardPos.x,boardPos.y)
  sqOff = 43.0
  (tbxo, lryo) = (220.0,172.0)
  (tyo,byo) = (70.0,690.0)
  (lxo,rxo) = (70.0,1030.0)
  maxRollFrames = 120

  (pbx,pby) = (20,20)
  kalam* = "fonts\\Kalam-Bold.ttf"
  fjallaOneRegular* = "fonts\\FjallaOne-Regular.ttf"
  ibmBold* = "fonts\\IBMPlexMono-Bold.ttf"
  inputEntries: seq[string] = @[
    "Write player handle:\n",
    "\n",
  ]
  condensedRegular = "fonts\\AsapCondensed-Regular.ttf"
  titleBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBorder:Border = (size:0,angle:0,color:color(0,0,100))
  inputBatchInit = BatchInit(
    kind: InputBatch,
    name: "inputBatch",
    titleOn: true,
    titleLine: (color:color(1,1,0),bgColor:color(0,0,0),border:titleBorder),
    pos: (400,200),
    inputCursor: (0.5,color(0,1,0)),
    inputLine: (color(0,1,0),color(0,0,0),inputBorder),
    padding: (40,40,20,20),
    entries: inputEntries,
    inputMaxChars: 8,
    alphaOnly: true,
    font: (condensedRegular,30.0,color(1,1,1)),
    bgColor: color(0,0,0),
    border: (15,25,color(0,0,100)),
    shadow: (15,1.5,color(255,255,255,200))
  )

let
  boardImg* = readImage "pics\\engboard.jpg"

var
  # batchInputNr* = -1
  mouseOnBatchPlayerNr* = -1
  pinnedBatchNr* = -1
  inputBatch* = newBatch inputBatchInit
  playerBatches*: array[6, Batch]
  showCursor*: bool
  dieRollFrame* = maxRollFrames
  moveAnimation*: MoveAnimation
  dieEdit: int

template mouseOnBatchColor*:untyped = players[mouseOnBatchPlayerNr].color

template selectedBatchColor*:untyped =
  if mouseOnBatchPlayerNr != -1: players[mouseOnBatchPlayerNr].color
  else: players[pinnedBatchNr].color

template batchSelected*:untyped =
  mouseOnBatchPlayerNr != -1 or pinnedBatchNr != -1

proc drawCursor*(b:var Boxy) =
  if turn.nr > 0 and showCursor:
    let
      x = (playerBatches[turn.player].area.x2-40).toFloat
      y = (playerBatches[turn.player].area.y1+10).toFloat
      cursor = Rect(x:x,y:y,w:20,h:20)
    b.drawRect(cursor,contrastColors[players[turn.player].color])

proc editDiceRoll*(input:string) =
  if input.toUpper == "D": dieEdit = 1
  elif dieEdit > 0 and (let dieFace = try: input.parseInt except: 0; dieFace in 1..6):
    diceRoll[dieEdit] = DieFace(dieFace)
    dieEdit = if dieEdit == 2: 0 else: dieEdit + 1
  else: dieEdit = 0

proc mouseOnDice*:bool = diceRollDims.anyIt mouseOn it.area

proc rotateDie(b:var Boxy,die:int) =
  b.drawImage(
    $diceRoll[die],
    center = vec2(
      (diceRollDims[die].rect.x+(diceRollDims[die].rect.w/2)),
      diceRollDims[die].rect.y+(diceRollDims[die].rect.h/2)),
    angle = ((dieRollFrame div 3)*9).toFloat,
    tint = color(1, 1, 1, 1.0)
  )

proc drawDice*(b:var Boxy) =
  if dieRollFrame == maxRollFrames:
    for i,die in diceRoll:
      b.drawImage($die,vec2(diceRollDims[i].rect.x, diceRollDims[i].rect.y))
  else:
    rollDice()
    b.rotateDie(1)
    b.rotateDie(2)
    inc dieRollFrame
    if dieRollFrame == maxRollFrames:
      # diceRolls.add diceRoll
      turnReport.diceRolls.add diceRoll
      #please: don't do as I do

proc isRollingDice*:bool = dieRollFrame < maxRollFrames

proc startDiceRoll* =
  if not isRollingDice():
    dieRollFrame = 
      if turnPlayer.kind == Human: humanRoll 
      else: computerRoll
    playSound("wuerfelbecher")

proc endDiceRoll* = dieRollFrame = maxRollFrames

proc mayReroll*:bool = isDouble() and not isRollingDice()

func squareDims:array[61,Dims] =
  result[0].rect = Rect(x:1225,y:150,w:35,h:100)
  for i in 0..17:
    result[37+i].rect = Rect(x:tbxo+(i.toFloat*sqOff),y:tyo,w:35,h:100)
    result[24-i].rect = Rect(x:tbxo+(i.toFloat*sqOff),y:byo,w:35,h:100)
    if i < 12:
      result[36-i].rect = Rect(x:lxo,y:lryo+(i.toFloat*sqOff),w:100,h:35)
      if i < 6:
        result[55+i].rect = Rect(x:rxo,y:lryo+(i.toFloat*sqOff),w:100,h:35)
      else:
        result[1+(i-6)].rect = Rect(x:rxo,y:lryo+(i.toFloat*sqOff),w:100,h:35)
  for dim in result.mitems:
    dim.area = toArea(dim.rect.x+bx,dim.rect.y+by,dim.rect.w,dim.rect.h)

proc buildBoardSquares*(board:Board):BoardSquares =
  const squareDims = squareDims()
  for (nr,name) in board:
    if nr > 0:
      result[nr] = (nr,name,squareDims[nr])
    else:
      result[0] = (0,"Removed",squareDims[0])

let
  squares* = buildBoardSquares board

proc mouseOnSquare*: int =
  for square in squares:
    if mouseOn square.dims.area:
      return square.nr
  result = -1

proc paintSquares*(img:var Image,squareNrs:seq[int],color:Color) =
  var ctx = img.newContext
  ctx.fillStyle = color
  for i in squareNrs:
    ctx.fillRect(squares[i].dims.rect)

proc paintSquares*(squareNrs:seq[int],color:Color):Image =
  result = newImage(boardImg.width,boardImg.height)
  result.paintSquares(squareNrs,color)

proc paintMoveToSquares*(squares:seq[int]):Image =
  result = newImage(boardImg.width,boardImg.height)
  result.paintSquares(squares.deduplicate, color(0,0,0,100))

var
  moveToSquaresPainter* = DynamicImage[seq[int]](
    name:"moveToSquares",
    rect:Rect(x:bx,y:by),
    updateImage:paintMoveToSquares,
    update:true
  )

proc drawMoveToSquares*(b:var Boxy,square:int) =
  if square != moveSelection.hoverSquare:
    if turn.diceMoved:
      moveToSquaresPainter.context = square.moveToSquares
    else:
      moveToSquaresPainter.context = square.moveToSquares diceRoll
    moveToSquaresPainter.update = true
    moveSelection.hoverSquare = square
  b.drawDynamicImage moveToSquaresPainter

proc drawSquares*(b:var Boxy) =
  if moveSelection.fromSquare != -1:
    b.drawDynamicImage moveToSquaresPainter
  elif (let square = mouseOnSquare(); square != -1) and turnPlayer.hasPieceOn(square):
    b.drawMoveToSquares square
  else: moveSelection.hoverSquare = -1

proc pieceOn*(color:PlayerColor,squareNr:int):Rect =
  let
    r = squares[squareNr].dims.rect
    colorOffset = (color.ord*15).toFloat
  if squareNr == 0: Rect(x:r.x,y:r.y+6+colorOffset,w:r.w-10,h:12)
  elif r.w == 35: Rect(x:r.x+5,y:r.y+6+colorOffset,w:r.w-10,h:12)
  else: Rect(x:r.x+6+colorOffset,y:r.y+5,w: 12,h:r.h-10)

proc paintPieces*:Image =
  var ctx = newImage(boardImg.width+50,boardImg.height).newContext
  ctx.font = ibmBold
  ctx.fontSize = 10
  for i,player in (if turn.nr != 0: players else: players.filterIt it.kind != None):
    for square in player.pieces.deduplicate:
      let
        nrOfPiecesOnSquare = player.pieces.countIt it == square
        piece = player.color.pieceOn square
      ctx.fillStyle = playerColors[player.color]
      ctx.fillRect piece
      if turn.nr > 0 and i == turn.player and square ==
          moveSelection.fromSquare:
        ctx.fillStyle = contrastColors[player.color]
        ctx.fillRect Rect(x:piece.x+4,y:piece.y+4,w:piece.w-8,h:piece.h-8)
      if nrOfPiecesOnSquare > 1:
        ctx.fillStyle = contrastColors[player.color]
        ctx.fillText($nrOfPiecesOnSquare,piece.x+2,piece.y+10)
  ctx.image

var
  piecesImg* = DynamicImage[void](
    name:"pieces",
    rect:Rect(x: bx, y: by),
    updateImage:paintPieces,
    update: true
  )

proc updatePiecesPainter* = piecesImg.update = true

func squareDistance(fromSquare,toSquare:int):int =
  if fromSquare < toSquare: toSquare-fromSquare
  else: (toSquare+60)-fromSquare

func animationSquares(fromSquare,toSquare:int):seq[int] =
  var square = fromSquare
  for _ in 1..squareDistance(fromSquare,toSquare):
    result.add square
    inc square
    if square > 60: square = 1

proc startMoveAnimation*(color:PlayerColor,fromSquare,toSquare: int) =
  moveAnimation.fromsquare = fromSquare
  moveAnimation.toSquare = toSquare
  moveAnimation.squares = animationSquares(
    moveAnimation.fromSquare,
    moveAnimation.toSquare
  )
  moveAnimation.color = color
  moveAnimation.frame = 0
  moveAnimation.moveOnFrame = 60 div moveAnimation.squares.len
  moveAnimation.currentSquare = 0
  moveAnimation.active = true

proc startMovesAnimations*(color:PlayerColor,moves:seq[AnimationMove]) =
  moveAnimation.moves = moves
  moveAnimation.movesIdx = 0
  startMoveAnimation(color,
    moves[moveAnimation.movesIdx].fromSquare,
    moves[moveAnimation.movesIdx].toSquare
  )

proc nextMoveAnimation =
  inc moveAnimation.movesIdx
  startMoveAnimation(moveAnimation.color,
    moveAnimation.moves[moveAnimation.movesIdx].fromSquare,
    moveAnimation.moves[moveAnimation.movesIdx].toSquare
  )

proc moveAnimationActive*:bool = moveAnimation.active

proc doMoveAnimation*(b:var Boxy) =
  if moveAnimation.active:
    inc moveAnimation.frame
    if moveAnimation.frame >= moveAnimation.moveOnFrame-1:
      moveAnimation.frame = 0
      inc moveAnimation.currentSquare
    for square in 0..moveAnimation.currentSquare:
      var pieceRect = pieceOn(
        moveAnimation.color, moveAnimation.squares[square]
      )
      pieceRect.x = bx+pieceRect.x
      pieceRect.y = by+pieceRect.y
      b.drawRect(pieceRect, playerColors[moveAnimation.color])
    if moveAnimation.currentSquare == moveAnimation.squares.high:
      if moveAnimation.moves.len > 1 and moveAnimation.movesIdx <
          moveAnimation.moves.high:
        nextMoveAnimation()
      else: moveAnimation.active = false

proc drawBoard*(b:var Boxy) =
  b.drawImage("board", boardPos)

addImage("board",boardImg)
for die in DieFace:
  addImage($die,("pics\\diefaces\\"&($die.ord)&".png").readImage)

proc mouseOnPlayerBatchNr*: int =
  result = -1
  for i, _ in players:
    if mouseOn playerBatches[i]: return i

proc playerBatch(setup:BatchSetup,yOffset:int):Batch =
  newBatch BatchInit(
    kind: TextBatch,
    name: setup.name,
    pos: (pbx, pby+yOffset),
    padding: setup.padding,
    entries: setup.entries,
    hAlign: setup.hAlign,
    fixedBounds: (175, 110),
    font: (setup.font, setup.fontSize, contrastColors[setup.bgColor]),
    border: (3, 20, contrastColors[setup.bgColor]),
    blur: 2,
    opacity: 25,
    bgColor: playerColors[setup.bgColor],
    shadow: (10, 1.75, color(255, 255, 255, 100))
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
    "Cash: "&(insertSep($players[playerNr].cash, '.'))
  ]

proc drawPlayerBatches*(b:var Boxy) =
  for batchNr, _ in players:
    if players[batchNr].update:
      playerBatches[batchNr].setSpanTexts playerBatchTxt batchNr
      playerBatches[batchNr].update = true
      players[batchNr].update = false
    b.drawBatch playerBatches[batchNr]

proc batchSetup(playerNr:int):BatchSetup =
  let player = players[playerNr]
  result.name = $player.color
  result.bgColor = player.color
  if turn.nr == 0:
    result.hAlign = CenterAlign
    result.font = fjallaOneRegular
    result.fontSize = 30
    result.padding = (0, 0, 35, 35)
  else:
    result.hAlign = LeftAlign
    result.font = kalam
    result.fontSize = 18
    result.padding = (20, 20, 12, 10)
  result.entries = playerBatchTxt playerNr

proc newPlayerBatches*:array[6,Batch] =
  var
    yOffset = pby
    setup: BatchSetup
  for playerNr, _ in players:
    if playerNr > 0:
      yOffset = pby+((result[playerNr-1].rect.h.toInt+15)*playerNr)
    setup = batchSetup playerNr
    result[playerNr] = setup.playerBatch yOffset
    result[playerNr].update = true
    result[playerNr].dynMove(Right, 30)

randomize()

