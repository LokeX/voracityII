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

import algorithm
import sugar

var dice = [2,1,4,3,5,6]
# for die in 1..6:
#   dice[die] = die

dice.sort
echo dice




# echo et


# for et in Etest:
#   echo et

