import strutils,algorithm,sequtils,sugar

const
  path = "dat\\visits.txt"

type 
  Item = tuple[adress:string,visits:int]

echo path.lines.toseq
  .mapIt(it.split(':'))
  .mapIt((Item)((it[0],it[1][1..it[1].high].parseInt)))
  .sorted((a,b) => b.visits-a.visits)
  .mapIt(it.adress&": "&($it.visits))
  .join "\n"

