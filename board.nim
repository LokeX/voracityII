import win
import colors
import strutils
import random
import megasound
import sequtils

type
  DieFace* = enum 
    DieFace1 = 1,DieFace2 = 2,DieFace3 = 3,
    DieFace4 = 4,DieFace5 = 5,DieFace6 = 6
  Dice* = array[1..2,DieFace]
  BoardSquares* = array[61,Square]
  Square* = tuple[nr:int,name:string,dims:Dims,icon:Image]
  Dims* = tuple[area:Area,rect:Rect]
  MoveSelection* = tuple
    hoverSquare,fromSquare,toSquare:int
    toSquares:seq[int]
    event:bool
  AnimationMove* = tuple[fromSquare,toSquare:int]
  MoveAnimation* = object
    active*:bool
    frame,moveOnFrame,currentSquare,fromsquare*,toSquare*:int
    color:PlayerColor
    movesIdx:int
    moves:seq[AnimationMove]
    squares:seq[int]

const
  diceRollRects = (Rect(x:1450,y:60,w:50,h:50),Rect(x:1450,y:120,w:50,h:50))
  diceRollDims:array[1..2,Dims] = [
    (diceRollRects[0].toArea,diceRollRects[0]),
    (diceRollRects[1].toArea,diceRollRects[1])
  ]
  boardPos = vec2(225,50)
  (bx*,by*) = (boardPos.x,boardPos.y)
  sqOff = 43.0
  (tbxo,lryo) = (220.0,172.0)
  (tyo,byo) = (70.0,690.0)
  (lxo,rxo) = (70.0,1030.0)
  maxRollFrames = 120

  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]
  bars* = [1,16,18,20,28,35,40,46,51,54]

var
  diceRolls*:seq[Dice]
  diceRoll*:Dice = [DieFace3,DieFace4]
  dieRollFrame* = maxRollFrames
  moveSelection*:MoveSelection = (-1,-1,-1,@[],false)
  moveAnimation*:MoveAnimation
  dieEdit:int

proc editDiceRoll*(input:string) =  
  if input.toUpper == "D": dieEdit = 1 
  elif dieEdit > 0 and (let dieFace = try: input.parseInt except: 0; dieFace in 1..6):
    diceRoll[dieEdit] = DieFace(dieFace)
    dieEdit = if dieEdit == 2: 0 else: dieEdit + 1
  else: dieEdit = 0

proc mouseOnDice*:bool = diceRollDims.anyIt mouseOn it.area

proc rollDice*() = 
  for die in diceRoll.mitems: 
    die = DieFace(rand(1..6))

proc rotateDie(b:var Boxy,die:int) =
  b.drawImage(
    $diceRoll[die],
    center = vec2(
      (diceRollDims[die].rect.x+(diceRollDims[die].rect.w/2)),
      diceRollDims[die].rect.y+(diceRollDims[die].rect.h/2)),
    angle = ((dieRollFrame div 3)*9).toFloat,
    tint = color(1,1,1,1.toFloat)
  )

proc drawDice*(b:var Boxy) =
  if dieRollFrame == maxRollFrames:
    for i,die in diceRoll:
      b.drawImage($die,vec2(diceRollDims[i].rect.x,diceRollDims[i].rect.y))
  else:
    rollDice()
    b.rotateDie(1)
    b.rotateDie(2)
    inc dieRollFrame
    if dieRollFrame == maxRollFrames: 
      diceRolls.add diceRoll #please: don't do as I do

proc isRollingDice*: bool = dieRollFrame < maxRollFrames

proc isDouble*: bool = diceRoll[1] == diceRoll[2]

proc startDiceRoll*(rollFrames:int) =
  if not isRollingDice(): 
    dieRollFrame = rollFrames
    playSound("wuerfelbecher")

proc endDiceRoll* = dieRollFrame = maxRollFrames

proc mayReroll*:bool = isDouble() and not isRollingDice()

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

func iconPath(square:Square):string =
  let squareName = square.name.toLower
  "pics\\board_icons\\"&(
    case squareName:
    of "villa","condo","slum": "livingspaces"
    of "bank","shop","bar","highway": squareName
    of "gas station": "gas_station"
    else: $square.nr
  )&".png"

proc typesetIcon(font:Font,txt:string,width,height:int):Arrangement =
  typeset(
    font,txt,
    bounds = vec2(width.toFloat,height.toFloat),
    hAlign = CenterAlign,
    vAlign = MiddleAlign,
    wrap = false
  )

let
  asap = readTypeface "fonts\\AsapCondensed-Bold.ttf"
  whiteAsap16 = setNewFont(asap,size = 20,color = color(1,1,0))
  blackAsap16 = setNewFont(asap,size = 20,color = color(0,0,0))

proc initIcon(square:Square):Image =
  result = readImage square.iconPath
  if square.name in ["Villa","Condo","Slum","Bank","Shop"]:
    let 
      txt = whiteAsap16.typesetIcon(square.name,result.width,result.height)
      stroke = blackAsap16.typesetIcon(square.name,result.width,result.height)
    result.fillText(txt,translate vec2(0,0))
    result.strokeText(stroke,translate(vec2(0,0)),1.0)

proc paintIcon(square:Square):Image =
  let 
    shadowSize = 4.0
    icon = square.initIcon
    ctx = newImage(icon.width+shadowSize.toInt,icon.height+shadowSize.toInt).newContext
  ctx.fillStyle = color(0,0,0,150)
  ctx.fillrect(
    Rect(x:shadowSize,y:shadowSize,w:icon.width.toFloat,h:icon.height.toFloat))
  ctx.drawImage(icon,0,0)
  result = ctx.image

proc buildBoardSquares*(path:string):BoardSquares =
  const squareDims = squareDims()
  var count = 0
  result[0] = (0,"Removed",squareDims[0],nil)
  for name in lines path:
    inc count
    result[count] = (count,name,squareDims[count],nil)
    result[count].icon = result[count].paintIcon

let 
  boardImg* = readImage "pics\\engboard.jpg"
  squares* = buildBoardSquares "dat\\board.txt"

proc mouseOnSquare*:int =
  result = -1
  for square in squares:
    if mouseOn square.dims.area:
      return square.nr

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
    area:(bx.toInt,by.toInt,0,0),
    updateImage:paintMoveToSquares,
    update:true
  )

proc pieceOn*(color:PlayerColor,squareNr:int): Rect =
  let 
    r = squares[squareNr].dims.rect
    colorOffset = (color.ord*15).toFloat
  if squareNr == 0: Rect(x:r.x,y:r.y+6+colorOffset,w:r.w-10,h:12)
  elif r.w == 35: Rect(x:r.x+5,y:r.y+6+colorOffset,w:r.w-10,h:12)
  else: Rect(x:r.x+6+colorOffset,y:r.y+5,w:12,h:r.h-10)

func squareDistance(fromSquare,toSquare:int):int =
  if fromSquare < toSquare:
    toSquare-fromSquare
  else: (toSquare+60)-fromSquare

func animationSquares(fromSquare,toSquare:int):seq[int] =
  var count = fromSquare
  for _ in 1..squareDistance(fromSquare,toSquare):
    result.add count
    inc count
    if count > 60: 
      count = 1

proc startMoveAnimation*(color:PlayerColor,fromSquare,toSquare:int) =
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
  moveAnimation.movesIdx =  0
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
        moveAnimation.color,moveAnimation.squares[square]
      )
      pieceRect.x = bx+pieceRect.x
      pieceRect.y = by+pieceRect.y
      b.drawRect(pieceRect,playerColors[moveAnimation.color])
    if moveAnimation.currentSquare == moveAnimation.squares.high:
      if moveAnimation.moves.len > 1 and moveAnimation.movesIdx < moveAnimation.moves.high:
        nextMoveAnimation()
      else: moveAnimation.active = false

proc drawBoard*(b:var Boxy) =
  b.drawImage("board",boardPos)

addImage("board",boardImg)
for die in DieFace: 
  addImage $die,("pics\\diefaces\\"&($die.ord)&".png").readImage
