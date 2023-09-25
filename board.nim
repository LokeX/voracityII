import win
import colors

type
  BoardSquares* = array[61,Square]
  Square* = tuple[nr:int,name:string,dims:Dims,icon:Image]
  Dims = tuple[area:Area,rect:Rect]

const
  boardPos = vec2(225,50)
  (bx*,by*) = (boardPos.x,boardPos.y)
  sqOff = 43.0
  (tbxo,lryo) = (220.0,172.0)
  (tyo,byo) = (70.0,690.0)
  (lxo,rxo) = (70.0,1030.0)

  condos* = [31,32]
  slums* = [56,58,59]
  shops* = [23,34,42,44,50]
  banks* = [3,14,24,38,52]
  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]
  bars* = [1,16,18,20,28,35,40,46,51,54]

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

const dims = squareDims()

proc paintIcon(path:string):Image =
  let 
    shadowSize = 4.0
    icon = readImage path
    ctx = newImage(icon.width+shadowSize.toInt,icon.height+shadowSize.toInt).newContext
  ctx.fillStyle = color(0,0,0,150)
  ctx.fillrect(
    Rect(x:shadowSize,y:shadowSize,w:icon.width.toFloat,h:icon.height.toFloat))
  ctx.drawImage(icon,0,0)
  result = ctx.image

func iconPath(square:Square):string =
  let squareName = square.name.toLower
  "pics\\board_icons\\"&(
    case squareName:
    of "villa","condo","slum": "livingspaces"
    of "bank","shop","bar","highway": squareName
    of "gas station": "gas_station"
    else: $square.nr
  )&".png"

proc buildBoardSquares*(path:string):BoardSquares =
  var count = 0
  for name in lines path:
    inc count
    result[count] = (count,name,dims[count],nil)
    result[count].icon = result[count].iconPath.paintIcon

let 
  boardImg* = readImage "pics\\engboard.jpg"
  squares* = buildBoardSquares "dat\\board.txt"

proc paintSquares*(img:var Image,squareNrs:seq[int],color:Color) =
  var ctx = img.newContext
  ctx.fillStyle = color
  for i in squareNrs: 
    ctx.fillRect(squares[i].dims.rect)

proc pieceOn*(color:PlayerColor,squareNr:int): Rect =
  let r = squares[squareNr].dims.rect
  if squareNr == 0:
    result = Rect(x:r.x,y:r.y+6+(color.ord*15).toFloat,w:r.w-10,h:12)
  elif r.w == 35:
    result = Rect(x:r.x+5,y:r.y+6+(color.ord*15).toFloat,w:r.w-10,h:12)
  else:
    result = Rect(x:r.x+6+(color.ord*15).toFloat,y:r.y+5,w:12,h:r.h-10)

proc drawBoard*(b:var Boxy) =
  b.drawImage("board",boardPos)

addImage("board",boardImg)
