# import strutils
# for line in lines "temps.txt":
#   try: 
#     echo(
#       if line[^1] == 'F':
#         $((line[0..line.high-2].parseFloat-32)*5.0/9.0).formatFloat(ffDecimal,1)&" F"
#       else: line
#     )
#   except:discard

import algorithm,sugar
const
  a = [2,1,7,5,9,8]
  b = a.sorted Ascending
  c = a.sorted (d,e) => d-e

static: 
  echo b
  echo c
# a.sortedByIt(proc(b,c:int) = b-c)
