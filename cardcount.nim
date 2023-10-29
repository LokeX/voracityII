import strutils

type 
  CardKind = enum Deed,Plan,Job,Event,News,Mission

const 
  fileName = "dat\\blues.txt"

var 
  counts:array[CardKind,int]
  total:int

for line in lines fileName:
  if (let colon = line.find ":"; colon != -1):
    for kind in CardKind:
      if line[0..<colon] == ($kind).toLower:
        inc counts[kind]

for i,count in counts:
  total += count
  echo $CardKind(i)&"s: ",count
echo "Total: ",total

