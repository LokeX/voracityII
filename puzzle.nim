import strutils

var
  stacks:seq[seq[string]]
  instruction: seq[array[3,int]]

proc parseStacks(line:string) =
  var
    indexes:array[1..3,int]
    idx = 1

  for i,ch in line:
    if $idx == $ch:
      inc idx
      indexes[idx] = i

proc parseInstructions(line:string) =
  discard

proc parseFile =
  var count = 0
  for line in readFile("puzzle.txt").splitLines:
    if count < 4: 
      line.parseStacks
    elif count > 4:
      line.parseInstructions
    inc count

#     [D]
# [N] [C]
# [Z] [M] [P]
#  1   2   3

#  move 1 from 2 to 1
#  move 3 from 1 to 3
#  move 2 from 2 to 1
#  move 1 from 1 to 2
 