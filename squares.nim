import algorithm
import strutils
import sugar
import sequtils

let squareVisits =
  readFile("dat\\visits.txt")
  .splitLines
  .mapIt((
    it[0..it.find(":")],
    it.splitWhitespace[^1].parseInt
  ))
  .sorted (a,b) => b[1] - a[1]
for (square,visits) in squareVisits: 
  echo square," ",visits
