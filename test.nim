import game
import sequtils
import misc

func covers(pieceSquare,coverSquare:int):bool =
  if pieceSquare == coverSquare:
    return true
  for die in 1..6:
    if coverSquare in moveToSquares(pieceSquare,die):
      return true

func covers(pieces,squares:openArray[int],count:int):int = 
  var 
    coverPieces:seq[int]
    idx:int
  for i,square in squares:  
    coverPieces = pieces.filterIt it.covers square
    if coverPieces.len > 0: idx = i+1; break
  debugEcho coverPieces
  if coverPieces.len == 0: 
    debugEcho count
    count
  elif idx == squares.len:
    debugEcho count+1
    count+1
  else: 
    var maxCovers:int
    for coverPiece in coverPieces:
      var pieces = @pieces
      pieces.del pieces.find coverPiece
      maxCovers = max(
        maxCovers,
        pieces.covers(squares[idx..squares.high],count+1)
      )
    maxCovers

func covers(pieces,squares:openArray[int]):int = 
  pieces.covers(squares,0)


func coversOneIn(pieces,squares:openArray[int]):bool = 
  for piece in pieces:
    for square in squares:
      if piece.covers square:
        return true

let
  pieces = [51,54,10,0,0]
  squares = [6,7,9,11]
  # squares = [8,25,30]

echo "covers: ",pieces.covers squares

echo toseq(1..6).mapit(moveToSquares(0,it)).flatMap.deduplicate
