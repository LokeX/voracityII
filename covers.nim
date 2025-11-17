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

func nrOfcoverPieces*(pieces,squares,squaresOrg:seq[int],depth:int):int = 
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

func covers*(pieces,squares:seq[int]):int = 
  var 
    covers,nextCovers:seq[tuple[pieces,squares,usedPieces:seq[int],idx:int]]
    count:int
    usedPieces:seq[int]
  
  template computeNextCovers(nextPieces,nextSquares:untyped) = 
    for i in 0..nextSquares.high:  
      usedPieces = nextPieces.filterIt it.covers nextSquares[i]
      if usedPieces.len > 0:
        nextCovers.add (@nextPieces,@nextSquares,usedPieces,i)
        break

  covers.setLen 1
  computeNextCovers(pieces,squares)
  while covers.len > 0:
    covers = nextCovers.filterIt it.usedPieces.len > 0
    if covers.len > 0: 
      inc count
      covers = covers.filterIt it.idx < it.squares.high
      nextCovers.setLen 0
      for cover in covers:
        for usedPiece in cover.usedPieces:
          computeNextCovers(
            cover.pieces.remove(usedPiece),
            cover.squares[cover.idx+1..cover.squares.high]
          )
  count

