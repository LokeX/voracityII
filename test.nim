import std/locks

var
  thr: array[0..4, Thread[tuple[a,b: int]]]
  L: Lock

proc threadFunc(interval: tuple[a,b: int]) {.thread.} =
  for i in interval.a..interval.b:
    acquire(L) # lock stdout
    echo i
    release(L)

initLock(L)

for i in 0..high(thr):
  createThread(thr[i], threadFunc, (i*10, i*10+5))
joinThreads(thr)

deinitLock(L)

type
  Etest = enum Test1,Test2,Test3,Test4,

var 
  et:Etest

while true:
  echo et
  if et == Etest.high:
    et = Etest.low
  else: inc et




# echo et


# for et in Etest:
#   echo et

