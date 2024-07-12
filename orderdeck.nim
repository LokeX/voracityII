import strutils,sequtils,os,sugar,algorithm

let
  deckName = paramStr(1)
  fileName = "decks\\"&deckName&".txt"
  outFile = "decks\\ordered"&deckName&".txt"

type
  CardKind* = enum Event,News,Deed,Plan,Job,Mission
  ProtoCard = tuple[cardKind:CardKind,lines:array[1..4,string]]

func parseCardKindFrom(kind:string):CardKind =
  try: CardKind(CardKind.mapIt(($it).toLower).find kind[0..kind.high-1].toLower) 
  except: raise newException(CatchableError,"Error, parsing CardKind: "&kind)

func parseProtoCards(lines:sink seq[string]):seq[ProtoCard] =
  var 
    cardLine:int
    protoCard:ProtoCard
  for line in lines:
    if line.len > 0:
      inc cardLine
      protocard.lines[cardLine] = line
      if cardLine == 1:
        protoCard.cardKind = parseCardKindFrom line
      elif cardLine == 4:
        result.add protoCard
        cardLine = 0

let cards = fileName.lines.toSeq.parseProtoCards
  .sorted((a,b) => b.cardKind.ord - a.cardKind.ord)
  .mapIt(it.lines.join "\n")
  .join "\n"

echo cards
writeFile(outFile,cards)
echo "wrote to file:"
echo outFile

