import strutils,algorithm,sequtils,sugar

const
  fileName = "dat\\cashed.txt"

type 
  Card = tuple[title:string,nr:int]

echo fileName.lines.toSeq
  .mapIt((Card) (it[0..it.find(':')],it.splitWhitespace[^1].parseInt))
  .sorted((a,b) => b.nr - a.nr)
  .mapIt(it.title&" "&($it.nr))
  .join "\n"

