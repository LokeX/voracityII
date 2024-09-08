import sequtils,misc

const
  highways* = [5,17,29,41,53]
  gasStations* = [2,15,27,37,47]

func adjustToSquareNr*(adjustSquare:int):int =
  if adjustSquare > 60: adjustSquare - 60 else: adjustSquare

func moveToSquare(fromSquare:int,die:int):int = 
  adjustToSquareNr fromSquare+die

func moveToSquares*(fromSquare,die:int):seq[int] =
  if fromsquare != 0: result.add moveToSquare(fromSquare,die)
  else: result.add highways.mapIt moveToSquare(it,die)
  if fromSquare in highways or fromsquare == 0:      
    result.add gasStations.mapIt moveToSquare(it,die)
  result = result.filterIt(it != fromSquare).deduplicate

func covers(pieceSquare,coverSquare:int):bool =
  pieceSquare == coverSquare or
  toSeq(1..6).anyIt coverSquare in moveToSquares(pieceSquare,it)

func covers(pieces,squares:openArray[int]):bool =
  let coverPieces = pieces.filterIt it.covers squares[0]
  if coverPieces.len == 0: 
    return false 
  elif squares.len == 1: 
    return true
  else:
    for piece in coverPieces:
      var ps = @pieces
      ps.del ps.find piece
      if ps.covers squares[1..squares.high]:
        return true
      
  # debugEcho "squares: ",squares
  # debugEcho "pieces: ",pieces
  # debugEcho "square: ",squares[0]
  # debugEcho "coverPieces: ",coverPieces
  # debugEcho "coversquares: "
  # for piece in pieces:
  #   debugEcho "from square: ",piece
  #   debugEcho toSeq(1..6).mapIt(moveToSquares(piece,it)).flatmap.deduplicate
  # debugEcho ""

let
  cardSquares = [26,30,49]
  pieceSquares = [22,40,0,0,0]

echo pieceSquares.covers cardSquares

