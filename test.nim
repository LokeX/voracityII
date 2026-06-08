import std/typedthreads
import random

randomize()

type
  Win = ref object of RootObj
    test:int
  Ext = ref object of Win
    test2:int
  # Test = object
  #   o:int

var
  ext = Ext(test2:2,test:2)
  win = Win(test:1)
  # test = Test(o:3)

win = ext
echo win.test
ext.test = 1
echo win.test
# echo ext.test2

var
  may:array[2,int]
  extsOut:array[2,ptr Ext]
  extsIn:array[2,Ext]

proc nerves(inp:Ext,nr:int) =
  inp.test2 = nr+1

proc t(inp:ptr Ext) {.thread, nimcall.} =
  for i in 0..<1000:
    inp[].nerves i
    may[inp.test] += 1
    # inp.test2 = i
  extsOut[inp.test] = inp

var
  thrs:array[2,Thread[ptr Ext]]

for i in 0..thrs.high:
  extsIn[i].new
  extsIn[i].test = i
  createThread(thrs[i],t,extsIn[i].addr)
joinThreads thrs

for e in extsOut:
  echo e.repr
for e in extsIn:
  echo e.repr
# win[] = ext[]
echo may.repr

var
  writeTest2 = Ext.new
  writeTest = Win.new

writeTest = writeTest2
writeTest2.test = 1
echo writeTest.repr
echo writeTest2.repr


