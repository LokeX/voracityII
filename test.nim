import game
import sequtils
# import sugar
import misc

func covers(pieceSquare,coverSquare:int):bool =
  if pieceSquare == coverSquare:
    return true
  for die in 1..6:
    if coverSquare in moveToSquares(pieceSquare,die):
      return true
  # toSeq(1..6).anyIt coverSquare in moveToSquares(pieceSquare,it)

# func covers(pieces,squares:openArray[int],count:int):int = 
#   debugEcho "pieces: ",pieces
#   debugEcho "squares: ",squares
#   var 
#     coverPieces:seq[int]
#     idx = -1
#   for i,square in squares:  
#     coverPieces = pieces.filterIt it.covers square
#     if coverPieces.len > 0:
#       idx = i
#       break
#   if idx == -1:
#     return count
#   if idx < squares.len:
#     debugEcho "pieces: ",coverPieces
#     debugEcho "covers: ",squares[idx]
#   if coverPieces.len == 0:
#       debugEcho "cs: ",count+1
#       return count+1
#   if idx == squares.high:
#       debugEcho "sc: ",count+1
#       return count+1
#   coverPieces
#   .mapIt(pieces.exclude(it).covers(squares[idx+1..squares.high],count+1))
#   .max




# func coversClosure(pieces,squares:openArray[int]):proc:int = 
#   var 
#     coverPieces:seq[int]
#     idx:int
#   return func:int =
#     for i,square in squares:  
#       coverPieces = pieces.filterIt it.covers square
#       if coverPieces.len > 0:
#         idx = i; break

# type Covers = tuple[pieces,squares,usedPieces:seq[int],idx:int]

# proc getCovers(pieces,squares:openArray[int]):Covers =
#   var 
#     usedPieces:seq[int]
#     idx:int
#   for i,square in squares:  
#     usedPieces = pieces.filterIt it.covers square
#     if usedPieces.len > 0:
#       idx = i; break
#   (@pieces,@squares,usedPieces,idx)

# func covers(pieces,squares:openArray[int]):int = 
#   var 
#     covers,nextCovers:seq[Covers]
#     count:int
#   covers.setLen 1
#   nextCovers.add getCovers(pieces,squares)
#   while covers.len > 0:
#     covers = nextCovers.filterIt it.usedPieces.len > 0
#     if covers.len > 0: 
#       inc count
#       covers = covers.filterIt it.idx < it.squares.high
#       nextCovers.setLen 0
#       for cover in covers:
#         for usedPiece in cover.usedPieces:
#           nextCovers.add getCovers(
#             cover.pieces.filterIt(it != usedPiece),
#             cover.squares[cover.idx+1..cover.squares.high]
#           )
#   count

func covers(pieces,squares:openArray[int]):int = 
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
            cover.pieces.filterIt(it != usedPiece),
            cover.squares[cover.idx+1..cover.squares.high]
          )
  count


func covers(pieces,squares:openArray[int],count:int):int = 
  var 
    coverPieces:seq[int]
    idx:int
  for i,square in squares:  
    coverPieces = pieces.filterIt it.covers square
    if coverPieces.len > 0:
      idx = i; break
  if coverPieces.len == 0: 
    count
  elif idx == squares.high: 
    count+1
  else: 
    var maxVal:int
    for coverPiece in coverPieces:
      maxVal = max(maxVal,
        pieces.filterIt(it != coverPiece)
        .covers(squares[idx+1..squares.high],count+1))
    maxVal

# func covers(pieces,squares:openArray[int]):int = 
#   pieces.covers(squares,0)


func coversOneIn(pieces,squares:openArray[int]):bool = 
  for piece in pieces:
    for square in squares:
      if piece.covers square:
        return true

import os,strutils
proc getParams:seq[int] =
  for prm in commandLineParams():
    try: result.add prm.parseInt
    except:discard
    if result.len == 2:
      break
  
echo "params:"
echo getParams()

let
  pieces = highways
  squares = [13,60,11,56]
var test = [5,3,9,1]

import algorithm
import sugar
test.sort (a,b) => a-b
echo test
echo test.sortedByIt it
# while true:
echo GC_getStatistics()
echo pieces.covers squares
echo GC_getStatistics()


var
  i:ptr array[10,int]

i = cast[ptr array[10,int]](alloc0(10*sizeof int))

i[][0] = 7
echo i[]

echo (10*sizeof int)
echo getOccupiedMem()
dealloc i
echo getOccupiedMem()

# i[] = 1

type Eq = object
  x,y:int
  s:string

var
  a = Eq(x:30,y:30,s:"yes")
  b= Eq(x:30,y:30,s:"no")

echo a == b

