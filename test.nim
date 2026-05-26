
var
  c:array[8,char]
  # c = ['a','b','c','d']
  s:string

echo sizeof c[0]
echo sizeof s[0]

s = "test"
copyMem(c[0].addr,s[0].addr,sizeof s)

# echo c

func aliasToChars(alias:string):array[8,char] =
  for i,ch in alias:
    if i < result.len: 
      result[i] = ch
      if i == alias.high and i < result.high:
        result[i+1] = '\n'
    else: return

echo "test".aliasToChars

func strToChars(str:string,res:var openArray[char]) =
  if str.len < res.len:
    copyMem(res[0].addr,str[0].addr,str.len)
    res[str.len] = '\n'
  else: copyMem(res[0].addr,str[0].addr,res.len)

func strToChars(str:string,T:typedesc):T =
  if str.len < result.len:
    copyMem(result[0].addr,str[0].addr,str.len)
    result[str.len] = '\n'
  else: copyMem(result[0].addr,str[0].addr,result.len)

"testttttttttt".strToChars c
echo c

c = "test".strToChars typeof c
echo c
