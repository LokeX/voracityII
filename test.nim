
import test2

proc t(test:var Test) = 
  echo test.a
  a += 1
  test.a += 1
  echo test.a

var 
  tes,te:Test

tes.a = 3
tes.t
te.a = 1
echo test2.test.a

proc g(t:var Test = tes) =
  var a = t.a.addr
  a[] += 1
  echo t

g(te)

var 
  arr = [1,2,3]
  # p = arr.addr
  p2 = cast[ptr int](cast[int](arr.addr)+sizeof(arr[0])*2)

echo p2[]


