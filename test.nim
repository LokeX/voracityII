import sequtils

func requiredOk*(pieces:openArray[int],squares:openArray[int]):bool =
  squares.deduplicate
    .allIt pieces.count(it) >= squares.count it

# func requiredSquaresAndPieces*(plan:BlueCard):tuple[squares,nrOfPieces:seq[int]] =
#   let squares = plan.squares.required.deduplicate
#   (squares,squares.mapIt plan.squares.required.count it)

let
  pieces = [1,2,3,4,0]
  squares = [60,5]

echo pieces.requiredOk squares


proc t(pieces:seq[int]) =
  var p = pieces
  p[0] = 60
  echo pieces
  echo p

t @[1,2,3,4,5]

import eval,game

var hypo:Hypothetic

hypo.pieces = [2,6,7,60,0]
hypo.cards = @[blueDeck.fullDeck[blueDeck.fullDeck.mapIt(it.title).find("Bodyguard")]]
hypo.cash = 440000

echo hypo.cards
echo hypo.winningMove [4,2]
