import sequtils
import strutils
import sugar
import os

template parameter*(param,defaultResult,body:untyped):auto =
  block:
    var result {.inject.} = defaultResult
    for param in commandLineParams():
      body
      if result != defaultResult: break
    result

proc consoleChoice*[T:enum](menuItems:T):T =
  let choices = menuItems.mapIt ord it
  var chosen = 4
  while chosen notIn choices:
    if chosen == -1: echo "Not a choice - try again\n"
    echo "Choose: "
    for choice in choices: echo $choice,") ",$menuItems choice
    chosen = try: stdin.readLine.parseInt except: -1
  menuItems chosen

template init*[T](t:var T) = t = default typeof T

iterator enum_mitems*[T](x:var openArray[T]):(int,var T) =
  var idx = 0
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

