import game
import sequtils

func covers(pieceSquare,coverSquare:int):bool =
  if pieceSquare == coverSquare:
    return true
  for die in 1..6:
    if coverSquare in moveToSquares(pieceSquare,die):
      return true

func remove(pieces:seq[int],removePiece:int):seq[int] =
  for idx,piece in pieces:
    if piece == removePiece:
      if idx < pieces.high:
        result.add pieces[idx+1..pieces.high]
      return
    else: result.add piece

func nrOfcoverPieces(pieces,squares,squaresOrg:seq[int],depth:int):int = 
  var 
    coverPieces:seq[int]
    idx:int
  for i,square in squares:  
    coverPieces = pieces.filterIt it.covers square
    if coverPieces.len > 0: idx = i+1; break
  if coverPieces.len == 0: 
    depth
  else: 
    var 
      squares = squares
      coverDepth:int
    if idx == squares.len:
      squares = squaresOrg
      idx = 0
    for coverPiece in coverPieces:
      coverDepth = max(
        coverDepth,
        pieces
          .remove(coverPiece)
          .nrOfcoverPieces(
            squares[idx..squares.high],
            squaresOrg,
            depth+1
          )
      )
    coverDepth

let
  pieces = @[7,8,17,16,13]
  squares = @[8,18]

echo nrOfcoverPieces(pieces,squares,squares,0)

let t = "test"

case t
of "test":echo "1"

