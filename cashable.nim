import strutils
import sequtils
import algorithm
import misc

type
  ProtoCard = array[4,string]
  CardKind* = enum Deed,Plan,Job,Event,News,Talent,Mission

func parseProtoCards(lines:sink seq[string]):seq[ProtoCard] =
  var 
    cardLine:int
    protoCard:ProtoCard 
  for line in lines:
    protocard[cardLine] = line
    if cardLine == 3:
      result.add protoCard
      cardLine = 0
    else: inc cardLine

func parseCardSquares(str:string,brackets:array[2,char]):seq[int] =
  let (f,l) = (str.find(brackets[0]),str.find(brackets[1]))
  if -1 in [f,l]: result = @[] else:
    result = str[f+1..l-1].split(',').mapIt it.parseInt

func parseCardKindFrom(kind:string):CardKind =
  try: CardKind(CardKind.mapIt(($it).toLower).find kind[0..kind.high-1].toLower) 
  except: raise newException(CatchableError,"Error, parsing CardKind: "&kind)

let 
  protoCards = readFile("dat\\blues.txt").splitLines.parseProtoCards
  squares = zip(protoCards.mapIt it[2],protoCards.mapIt parseCardKindFrom it[0])
    .filterIt(it[1] notin [News,Event])
    .mapIt(it[0].parseCardSquares ['{','}'])
    .flatMap
  squareCount = toSeq(1..60).mapit (it,squares.count it)
  squareNames = readFile("dat\\board.txt").splitLines
for (squareNr,count) in squareCount.filterIt(it[1] > 0).sortedByIt(it[1]).reversed:
  echo squareNames[squareNr-1]," Nr. ",squareNr,": ",count

