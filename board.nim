import win
# import sequtils

type
  BoardSquares* = array[61,Square]
  Square* = tuple[nr:int,name:string,dims:Dims,icon:Image]
  Dims = tuple[area:Area,rect:Rect]

const
  boardPos = vec2(225,50)
  (bx*,by*) = (boardPos.x.toInt,boardPos.y.toInt)
  sqOff = 43
  (tbxo,lryo) = (220,172)
  (tyo,byo) = (70,690)
  (lxo,rxo) = (70,1030)

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

func squareAreas:array[61,Area] =
  result[0] = (bx+1225,by+150,35,100)
  for i in 0..17:
    result[37+i] = (bx+tbxo+(i*sqOff),by+tyo,35,100)
    result[24-i] = (bx+tbxo+(i*sqOff),by+byo,35,100)
    if i < 12:
      result[36-i] = (bx+lxo,by+lryo+(i*sqOff),100,35)
      if i < 6:
        result[55+i] = (bx+rxo,by+lryo+(i*sqOff),100,35)
      else:
        result[1+(i-6)] = (bx+rxo,by+lryo+(i*sqOff),100,35)

func squareDims(areas:openArray[Area]):array[61,Dims] =
  for i,area in squareAreas():
    result[i] = (area,area.toRect)

const dims = squareDims squareAreas()
proc buildBoardSquares*(path:string):BoardSquares =
  var count = 0
  for name in lines path:
    inc count
    result[count] = (count,name,dims[count],nil)
    result[count].icon = result[count].iconPath.paintIcon

let 
  boardImg = readImage "pics\\engboard.jpg"
  squares* = buildBoardSquares "dat\\board.txt"

proc drawBoard*(b:var Boxy) =
  b.drawImage("board",boardPos)
  # for square in squares:
  #   b.drawRect(square.dims.rect,color(0,0,0,150))

addImage("board",boardImg)
