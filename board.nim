import win
import pieces

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

proc paintIcon(path:string):Image =
  let 
    shadowSize = 4.0
    icon = readImage path
    ctx = newImage(icon.width+shadowSize.toInt,icon.height+shadowSize.toInt).newContext
  ctx.fillStyle = color(0,0,0,150)
  ctx.fillrect(
    Rect(x:shadowSize,y:shadowSize,w:icon.width.toFloat,h:icon.height.toFloat))
  result = ctx.image
  result.draw(icon,translate vec2(0,0))

func iconPath(square:Square):string =
  let squareName = square.name.toLower
  "pics\\board_icons\\"&(
    case squareName:
    of "villa","condo","slum": "livingspaces"
    of "bank","shop","bar","highway": squareName
    of "gas station": "gas_station"
    else: $square.nr
  )&".png"

func squareDims:array[61,Dims] =
  result[0].rect = Rect(x:bx+1225,y:by+150,w:35,h:100)
  for i in 0..17:
    result[37+i].rect = Rect(x:bx+tbxo+(i.toFloat*sqOff),y:by+tyo,w:35,h:100)
    result[24-i].rect = Rect(x:bx+tbxo+(i.toFloat*sqOff),y:by+byo,w:35,h:100)
    if i < 12:
      result[36-i].rect = Rect(x:bx+lxo,y:by+lryo+(i.toFloat*sqOff),w:100,h:35)
      if i < 6:
        result[55+i].rect = Rect(x:bx+rxo,y:by+lryo+(i.toFloat*sqOff),w:100,h:35)
      else:
        result[1+(i-6)].rect = Rect(x:bx+rxo,y:by+lryo+(i.toFloat*sqOff),w:100,h:35)
  for dim in result.mitems:
    dim.area = dim.rect.toArea

const dims = squareDims()
proc buildBoardSquares*(path:string):BoardSquares =
  var count = 0
  for name in lines path:
    inc count
    result[count] = (count,name,dims[count],nil)
    result[count].icon = result[count].iconPath.paintIcon

let 
  boardImg = readImage "pics\\engboard.jpg"
  squares* = buildBoardSquares "dat\\board.txt"

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
  for square in squares:
    b.drawRect(square.dims.rect,color(0,0,0,150))

addImage("board",boardImg)
