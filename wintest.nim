import win
import dialog

let 
  board = readImage("pics\\engboard.jpg")

addImage("board",board)

proc draw(b:var Boxy) =
  b.drawImage("board",vec2(22,22))

addCall Call(draw:draw)

let entries = @[
  "test1\n",
  "test2\n",
  "test3\n",
]

proc answer(s:string) =
  echo s

startDialog(entries,0..entries.high,answer)

runWin
