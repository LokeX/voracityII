import sequtils
import sugar

type
  DieFace* = enum 
    DieFace1 = 1,DieFace2 = 2,DieFace3 = 3,
    DieFace4 = 4,DieFace5 = 5,DieFace6 = 6
  DiceMoves* = array[DieFace,tuple[moves:seq[Move],bestMove:Move,isWinningMove:bool]]
  Move* = tuple[pieceNr,die,fromSquare,toSquare,eval:int]

func isBestDieIn(dieQuery:DieFace,diceMoves:DiceMoves):bool =
  if diceMoves[dieQuery].isWinningMove: 
    true
  elif diceMoves.anyIt it.isWinningMove: 
    false
  else:
    let t = diceMoves.maxIndex (a,b) => a.bestMove.eval - b.bestMove.eval
    var bestDie = DieFace1
    for die in DieFace2..DieFace6:
      if diceMoves[die].bestMove.eval > diceMoves[bestDie].bestMove.eval:
        bestDie = die
    dieQuery == bestDie

var
  moves:array[DieFace,Move]

for i in DieFace:
  moves[i].eval = i.ord
  echo moves[i]

echo DieFace(moves.maxIndex (a,b) => a.eval-b.eval)

