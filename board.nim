import win

let 
  boardImg = readImage "pics\\engboard.jpg"

proc drawBoard*(b:var Boxy) =
  b.drawImage("board",vec2(225,50))

addImage("board",boardImg)

