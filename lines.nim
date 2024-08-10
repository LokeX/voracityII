from os import walkFiles

var
  total,lineCount:int
  

for f in walkFiles("*.nim"):
  lineCount = 0
  for line in lines f:
    inc lineCount
  total += lineCount
  echo f,": ",lineCount
echo "total: ",total

