import win except splitWhitespace
# import miscui
import game
import play
import batch
import sugar
import strutils
import sequtils
import megasound
import dialog
import menu

type
  Dims* = tuple[area:Area,rect:Rect]
  EventMoveFmt = tuple[fromSquare,toSquare:string]
  SquareTexts = array[61,tuple[text:seq[string],spans:seq[Span]]]
  BoardSquares* = array[61,Square]
  Square* = tuple[nr:int,name:string,dims:Dims]
  AnimationMove* = tuple[fromSquare,toSquare:int]
  MoveAnimations* = object
    active*:bool
    frame,moveOnFrame,currentSquare,fromsquare*,toSquare*:int
    color: PlayerColor
    movesIdx:int
    moves:seq[AnimationMove]
    squares:seq[int]

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
  maxRollFrames = 120
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

  asapCondensedItalic = "fonts\\AsapCondensed-Italic.ttf"

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
  squareHeaderFont = setNewFont(ibmSemiBold,size = 16.0,color(50,50,0))
  flavourFont = setNewFont("fonts\\AsapCondensed-Italic.ttf",size = 16.0,color(1,1,1))
  boardImg* = readImage "pics\\engboard.jpg"

var 
  dialogBarMoves:seq[Move]
  moveAnimation*: MoveAnimations
  squareTextBatch = newBatch squareTextBatchInit
  squareTexts:SquareTexts
  squares*:BoardSquares
  squareTimer* = 0
  mouseSquare* = -1
  lastTextSquare = -1
  hoverSquare = -1
  dieRollFrame = maxRollFrames
  dieEdit:int

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
  result.paintSquares(squares.deduplicate,color(0,0,0,100))

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
      if turn.nr > 0 and i == turn.player and square == moveSelection.fromSquare:
        ctx.fillStyle = contrastColors[player.color]
        ctx.fillRect Rect(x:piece.x+4,y:piece.y+4,w:piece.w-8,h:piece.h-8)
      if nrOfPiecesOnSquare > 1:
        ctx.fillStyle = contrastColors[player.color]
        ctx.fillText($nrOfPiecesOnSquare,piece.x+2,piece.y+10)
  result = ctx.image

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

proc eventMoveFmt(move:Move):EventMoveFmt =
  ("from:"&board[move.fromSquare].name&" Nr. "&($board[move.fromSquare].nr)&"\n",
   "to:"&board[move.toSquare].name&" Nr. "&($board[move.toSquare].nr)&"\n")

proc dialogEntries(moves:seq[Move],f:EventMoveFmt -> string):seq[string] =
  var ms = moves.mapIt(it.eventMoveFmt).mapIt(f it).deduplicate
  stripLineEnd ms[^1]
  ms

proc endBarMoveSelection(selection:string) =
  if (let toSquare = selection.splitWhitespace[^1].parseInt; toSquare != -1):
    moveSelection.toSquare = toSquare
    moveSelection.event = true
    movePiece moveSelection.toSquare

proc barMoveMouseMoved(entries:seq[string]):proc =
  var square = -1
  proc =
    let selectedSquare = try:
      entries[dialogBatch.selection]
      .splitWhitespace[^1]
      .parseInt
    except: -1
    if selectedSquare notin [-1,square]:
      square = selectedSquare
      moveToSquaresPainter.context = @[square]
      moveToSquaresPainter.update = true
      if entries[dialogBatch.selection].startsWith "from":
        moveSelection.fromSquare = square #yeah, it's a hack

proc selectBarMoveDest(selection:string) =
  let
    entries = dialogBarMoves.dialogEntries move => move.toSquare
    fromSquare = selection.splitWhitespace[^1].parseInt
  if fromSquare != -1:
    moveSelection.fromSquare = fromSquare
  if entries.len > 1:
    dialogOnMouseMoved = entries.barMoveMouseMoved()
    startDialog(entries,0..entries.high,endBarMoveSelection)
  elif entries.len == 1:
    moveSelection.toSquare = dialogBarMoves[0].toSquare
    moveSelection.event = true
    movePiece moveSelection.toSquare

proc selectBar*(dialogMoves:seq[Move]) =
  dialogBarMoves = dialogMoves
  showMenu = false
  let entries = dialogBarMoves.dialogEntries move => move.fromSquare
  if entries.len > 1:
    dialogOnMouseMoved = entries.barMoveMouseMoved()
    startDialog(entries,0..entries.high,selectBarMoveDest)
  elif entries.len == 1:
    moveSelection.fromSquare = dialogBarMoves[0].fromSquare
    selectBarMoveDest entries[0]

proc startKillDialog*(square:int) =
  let entries:seq[string] = @[
    "Remove piece on:\n",
    board[square].name&" Nr."&($board[square].nr)&"?\n",
    # "Cash chance: "&cashChance.formatFloat(ffDecimal,2)&"%\n",
    "\n",
    "Yes\n",
    "No",
  ]
  showMenu = false
  startDialog(entries,3..4,decideKillAndMove)

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

proc animateMoveSelection* =
  startMoveAnimation(
    turnPlayer.color,
    moveSelection.fromSquare,
    moveSelection.toSquare
  )

proc drawBoard*(b:var Boxy) =
  b.drawImage("board", boardPos)

proc buildSquareTexts(path:string):SquareTexts =
  var square = 0
  for line in path.lines:
    if line.startsWith("square:"):
      square = line[7..line.high].splitWhitespace[^1].parseInt
      result[square].text.add squares[square].name&" Nr. "&($squares[square].nr)
    else: result[square].text.add line

proc buildSquareTextSpans(square:int):seq[Span] =
  for idx,text in squareTexts[square].text:
    if idx == 0: 
      result.add newSpan(text&"\n",squareHeaderFont)
    elif idx == 1: 
      result.add newSpan(text,flavourFont)
    else: result[^1].text.add text
    if idx < squareTexts[square].text.high:
      result[^1].text.add "\n"

proc drawSquareText*(b:var Boxy) =
  if (mouseSquare > -1):
    if mouseSquare != lastTextSquare:
      squareTimer = 1 # times the timer tick of 0.4 secs
      lastTextSquare = mouseSquare
      squareTextBatch.setSpans squareTexts[mouseSquare].spans
      squareTextBatch.update = true
    b.drawBatch squareTextBatch
  elif squareTimer > 0:
    lastTextSquare = -1
    b.drawBatch squareTextBatch

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

# proc createBoardTextFile* =
#   let f = open("dat\\boardtxt.txt",fmWrite)
#   for idx in 0..60:
#     f.write("square:"&($idx)&"\nThis is a test text for square: "&($idx)&"\n")

template initGamePlay* =
  addImage("board",boardImg)
  squares = buildBoardSquares board
  squareTexts = buildSquareTexts "dat\\boardtxt.txt"
  for square in 0..squareTexts.high:
    squareTexts[square].spans = buildSquareTextSpans square
  for die in DieFace:
    addImage($die,("pics\\diefaces\\"&($die.ord)&".png").readImage)
