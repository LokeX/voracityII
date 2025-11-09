import win except splitWhitespace
import graphics
import game
import play
import batch
import strutils
import sequtils
import megasound

type
  SquareTexts = array[61,seq[string]]
  BoardSquares* = array[61,Square]
  Square* = tuple[nr:int,name:string,dims:graphics.Dims]
  AnimationMove* = tuple[fromSquare,toSquare:int]
  MoveAnimations* = object
    active*:bool
    frame,moveOnFrame,currentSquare,fromsquare*,toSquare*:int
    color: PlayerColor
    movesIdx:int
    moves:seq[AnimationMove]
    squares:seq[int]

const
  boardPos = vec2(225,50)
  (bx*,by*) = (boardPos.x,boardPos.y)
  sqOff = 43.0
  (tbxo, lryo) = (220.0,172.0)
  (tyo,byo) = (70.0,690.0)
  (lxo,rxo) = (70.0,1030.0)

  asapCondensedItalic = "fonts\\AsapCondensed-Italic.ttf"

# let
  squareTextBatchInit = BatchInit(
    kind:TextBatch,
    name:"squaretext",
    pos:(460,280),
    padding:(15,75,8,15),
    border:(2,0,color(1,1,1)),
    font:(asapCondensedItalic,20.0,color(1,1,1)),
    bgColor:color(0,0,0),
    opacity:25,
    shadow:(10,1.5,color(255,255,255,150))
  )

let
  flavourFont = setNewFont("fonts\\AsapCondensed-Italic.ttf",size = 16.0,color(1,1,1))
  boardImg* = readImage "pics\\engboard.jpg"


var 
  moveAnimation*: MoveAnimations
  squareTextBatch = newBatch squareTextBatchInit
  squareTexts:SquareTexts
  squares*:BoardSquares
  squareTimer* = 0
  mouseSquare* = -1
  lastTextSquare = -1
  hoverSquare = -1

proc buildSquareTexts(path:string):SquareTexts =
  var square = 0
  for line in path.lines:
    if line.startsWith("square:"):
      square = line[7..line.high].splitWhitespace[^1].parseInt
    else: result[square].add line

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

proc drawMoveToSquares*(b:var Boxy) =
  if mouseSquare != hoverSquare:
    if turn.diceMoved:
      moveToSquaresPainter.context = mouseSquare.moveToSquares
    else:
      moveToSquaresPainter.context = mouseSquare.moveToSquares diceRoll
    moveToSquaresPainter.update = true
    hoverSquare = mouseSquare
  b.drawDynamicImage moveToSquaresPainter

proc drawSquares*(b:var Boxy) =
  if moveSelection.fromSquare != -1:
    b.drawDynamicImage moveToSquaresPainter
  elif mouseSquare > -1 and turnPlayer.hasPieceOn(mouseSquare):
    b.drawMoveToSquares
  else: hoverSquare = -1

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

proc selectPiece*(square:int) =
  if not turn.diceMoved or square == 0 or square.isHighway:
    if turnPlayer.hasPieceOn square:
      hoverSquare = -1
      moveSelection = (square,-1,turnPlayer.movesFrom(square),false)
      moveToSquaresPainter.context = moveSelection.toSquares
      moveToSquaresPainter.update = true
      piecesImg.update = true
      updateKeybar = true
      playSound "carstart-1"

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

proc squareTextSpans(square:int):seq[Span] =
  for idx,text in squareTexts[square]:
    result.add newSpan(text,flavourFont)
    if idx < squareTexts[square].high:
      result[^1].text.add "\n"

proc drawSquareText*(b:var Boxy) =
  if (mouseSquare > -1):
    if mouseSquare != lastTextSquare:
      squareTimer = 2 # times the timer tick of 0.4 secs
      lastTextSquare = mouseSquare
      squareTextBatch.setSpans mouseSquare.squareTextSpans
      squareTextBatch.update = true
    b.drawBatch squareTextBatch
  elif squareTimer > 0:
    lastTextSquare = -1
    b.drawBatch squareTextBatch

proc createBoardTextFile* =
  let f = open("dat\\boardtxt.txt",fmWrite)
  for idx in 0..60:
    f.write("square:"&($idx)&"\nThis is a test text for square: "&($idx)&"\n")

template initBoard* =
  addImage("board",boardImg)
  squares = buildBoardSquares board
  squareTexts = buildSquareTexts "dat\\boardtxt.txt"
