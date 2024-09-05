import sequtils,sugar

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
      if pieces.filterIt(it != piece).covers squares[1..squares.high]:
        return true
      
  # debugEcho "squares: ",squares
  # debugEcho "pieces: ",pieces
  # debugEcho "coverPieces: ",coverPieces
  # debugEcho ""

let
  cardSquares = [6,7,9,11]
  pieceSquares = [11,5,29,41,53]

echo pieceSquares.covers cardSquares

