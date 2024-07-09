import strutils,algorithm,sequtils,sugar

const
  path = "dat\\visits.txt"

type 
  Index = enum Adress,Visits
  Item = tuple[adress:string,visits:int]

echo path.lines.toseq
  .map(line => line.split ':')
  .map(item => (Item)((item[Adress.ord],item[Visits.ord].strip.parseInt)))
  .sorted((a,b) => b.visits-a.visits)
  .map(item => item.adress.align(20)&": "&($item.visits).align 4)
  .join "\n"

