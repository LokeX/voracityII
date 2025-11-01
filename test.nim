import game
import sequtils
import misc
import strutils

# func covers(pieceSquare,coverSquare:int):bool =
#   if pieceSquare == coverSquare:
#     return true
#   for die in 1..6:
#     if coverSquare in moveToSquares(pieceSquare,die):
#       return true

# func covers(pieces,squares:openArray[int],count:int):int = 
#   var 
#     coverPieces:seq[int]
#     idx:int
#   for i,square in squares:  
#     coverPieces = pieces.filterIt it.covers square
#     if coverPieces.len > 0: idx = i+1; break
#   debugEcho coverPieces
#   if coverPieces.len == 0: 
#     debugEcho count
#     count
#   elif idx == squares.len:
#     debugEcho count+1
#     count+1
#   else: 
#     var maxCovers:int
#     for coverPiece in coverPieces:
#       var pieces = @pieces
#       pieces.del pieces.find coverPiece
#       maxCovers = max(
#         maxCovers,
#         pieces.covers(squares[idx..squares.high],count+1)
#       )
#     maxCovers

# func covers(pieces,squares:openArray[int]):int = 
#   pieces.covers(squares,0)

func covers(pieceSquare,coverSquare:int):int =
  if pieceSquare == coverSquare:
    return 0
  for die in 1..6:
    if coverSquare in moveToSquares(pieceSquare,die):
      return die
  return -1

func remove(pieces:openArray[int],removePiece:int):seq[int] =
  for idx,piece in pieces:
    if piece == removePiece:
      if idx < pieces.high: 
        result.add pieces[idx+1..pieces.high]
      return
    result.add piece

type Cover = tuple[fromSquare,toSquare,die:int]

# proc `==`(a,b:Cover):bool =
#   a.square == b.square and a.die == b.die

func covers(pieces,squares:openArray[int],usedCovers:seq[Cover]):seq[seq[Cover]] = 
  var 
    covers:seq[Cover]
    idx:int
  for i,square in squares:  
    covers = pieces.mapIt((it,square,it.covers square))
    covers = covers.filterIt(it.die != -1)
    if covers.len > 0: 
      idx = i+1
      break
  if covers.len == 0: 
    result.add usedCovers
  elif idx == squares.len:
    result.add (usedCovers&covers[covers.high])
  else: 
    for cover in covers:
      result.add(
        pieces
          .remove(cover.fromSquare)
          .covers(squares[idx..squares.high],usedCovers&cover)
      )

func covers(pieces,squares:openArray[int]):seq[seq[Cover]] = 
  # var 
  #   dice = pieces.covers(squares,@[]).mapIt(it.filterIt(it != 0).deduplicate)
  #   max = dice.mapIt(it.len).max
  # dice.filterIt(it.len == max).flatMap.deduplicate

  pieces.covers(squares,@[]).filterIt(it.len == squares.len)
  # pieces.covers(squares,@[]).mapIt(it.deduplicate)






# func coversOneIn(pieces,squares:openArray[int]):bool = 
#   for piece in pieces:
#     for square in squares:
#       if piece.covers square:
#         return true

let
  pieces = [5,6,10,12,1]

  squares = [6,7,9,11]
  # squares = [8,25,30]
  # squares = [4,4]

echo "covers: "
echo pieces.covers(squares).mapIt($it).join "\n"

# echo pieces.covers(squares)

# echo toseq(1..6).mapit(moveToSquares(0,it)).flatMap.deduplicate

# let 
#   allowedRemoved = 1
#   ps = [10,10,0,0,0]
# var 
#   count = 0
#   result:seq[int]

# for piece in ps:
#   if piece == 0:
#     if count == allowedRemoved:
#       continue
#     inc count
#   result.add piece
# echo result
