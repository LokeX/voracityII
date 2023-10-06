import strutils
var 
  accum = 0
  elfs:seq[int]
for line in readFile("elf.txt").splitLines:  
  if (let amount = try:line.parseInt except:0; amount > 0):
    accum += amount
  else: 
    echo "elf ",elfs.len+1,": ",accum
    elfs.add accum
    accum = 0
echo "max elfs: ",max elfs

# output ->
# elf 1: 6000
# elf 2: 4000
# elf 3: 11000
# elf 4: 24000
# elf 5: 10000
# max elfs: 24000

