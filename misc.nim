import sequtils
import strutils
import sugar
import os
import taskpools,cpuinfo
export spawn

template taskPoolsAs*(pool,codeBlock:untyped) =
  var pool = Taskpool.new(num_threads = countProcessors())
  codeBlock
  pool.syncAll
  pool.shutdown

proc seqToFile*[T](list:seq[T],path:string) =
  let file = open(path,fmWrite)
  for l in list:
    discard file.writeBuffer(l.addr,sizeof T)
  file.close

iterator readType*(path:string,T:typedesc):T =
  let file = open(path,fmread)
  while not file.endOfFile:
    var ft = default T
    discard file.readBuffer(ft.addr,sizeof T)
    yield ft
  file.close

proc fileToSeq*[T](path:string,s:var seq[T]) =
  s = readType(path,T).toSeq

proc fileToSeq*(path:string,T:typedesc):seq[T] =
  readType(path,T).toSeq

template writeIt*(file,data:untyped) =
  discard file.writeBuffer(data.addr,sizeof data)

template readIt*(file,data:untyped) =
  discard file.readBuffer(data.addr,sizeof data)

func reduce*[T](list:openArray[T],fn:(T,T) -> T):T {.effectsOf:fn.} =
  if list.len > 0:
    result = list[list.low]
  if list.len > 1:
    for idx in list.low+1..list.high:
      result = fn(result,list[idx])

template parameter*(param,defaultResult,body:untyped):auto =
  var result {.inject.} = defaultResult
  for param in commandLineParams():
    body
    if result != defaultResult: 
      break
  result

proc consoleChoice*(choices:openArray[string]):int =
  var chosen = -2
  while chosen < choices.low or chosen > choices.high:
    if chosen == -1: echo "Not a choice - try again\n"
    echo "Choose: "
    for i,choice in choices: echo i,") ",choice
    chosen = try: stdin.readLine.parseInt except: -1
  chosen

template init*(t:untyped) = t = default typeof t

iterator enum_mitems*[T](x:var openArray[T]):(int,var T) =
  var idx = x.low
  while idx <= x.high:
    yield (idx,x[idx])
    inc idx

iterator fiMap*[T,U](a:openArray[T],f:T -> bool,m:T -> U):U =
  for b in a:
    if f(b): yield m(b)

proc fiMapSeq*[T,U](x:openArray[T],f:T -> bool,m:T -> U):seq[U] =
  # for y in x.fiMap(f,m): result.add y
  x.fimap(f,m).toSeq
  
proc muMap*[T,U](x:var openArray[T],m:T -> U) =
  var idx = 0
  while idx <= x.high:
    x[idx] = m(x[idx])
    inc idx

iterator select*[T](x:openArray[T],select:T -> bool):T =
  var idx = 0
  while idx <= x.high:
    if select x[idx]:
      yield x[idx]
    inc idx

iterator reversed*[T](x:openArray[T]):T =
  var idx = x.high
  while idx >= x.low:
    yield x[idx]
    dec idx

iterator zipem*[T,U](x:openArray[T],y:openArray[U]):(T,U) =
  var idx = 0
  let idxEnd = min(x.high,y.high)
  while idx <= idxEnd:
    yield (x[idx],y[idx])
    inc idx

func zipTuple*[T,U](x:(seq[T],seq[U])):seq[(T,U)] = zip(x[0],x[1])

func flatMap*[T](x:seq[seq[T]]):seq[T] =
  for y in x:
    for z in y:
      result.add z

when isMainModule:
  var 
    test = @[1,2,3,4,5,6,7,8]
    test2 = test
  for t in test.select(n => n mod 2 == 0): echo t
  echo test.reversed.toSeq
  for t in zipem(test,test2): echo t
  test.muMap(x => x*3)
  echo test
  echo zipTuple (test,test2)
  echo test.fiMapSeq((y:int) => y mod 2 == 0, x => (x*2).toFloat)
  for t in test.fiMap((y:int) => y mod 2 == 0, x => x*2): echo t
  let help = parameter(param,false):
    if param.toLower == "help": result = true
  echo help
  type Menu = enum Choice1, Choice2, Choice3
  let choice = Menu.mapIt($it).consoleChoice
  echo "choice: ",Menu(choice)


