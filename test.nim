# playing with pointers
proc write[T](p:pointer,i:int,val:T) =
  cast[ptr T](cast[int](p)+(sizeof(T)*i))[] = val

func to[T:typedesc](p:pointer,i:int,y:T):ptr y =
  cast[ptr y](cast[int](p)+(sizeof(y)*i))

func too[U](p:openArray[U],i:int):ptr U =
  cast[ptr U](cast[int](p.addr)+(sizeof(U)*i))

var 
  t = [1,2,4]
  p = t.addr
  # o = cast[ptr int](cast[int](p)+(sizeof(int)*2))
# o[] = 3

p.write(2,3)
p.to(0,int)[] = 0
t.too(1)[] = 1
echo t

proc pr(rt:typedesc):proc:rt = 
  proc:rt = default rt

let ty = pr(typeof t)

echo $(typeof ty())
# let b = pr cast[typedesc]("int")

func addd[T](l:var seq[T],i:sink T) =
  i += 1
  l.add move i

var
  l = @[1,2,3]
  u:int = 12

echo u
l.addd move u
echo l


import typeinfo

type
  RefTest = ref Test
  Test = object
    i:int
    f:float

var 
  sr:seq[Any]
  kl = Test(i:12,f:2.3)
  hj = kl.addr
  vb = new RefTest

vb[] = hj[]

sr.add hj.toAny
let df = sr[^1][]
echo vb[]

let po = (y:300,x:4.0)

echo po.y

var 
  a = @[1,2,3]
  b = @[1,2,3]

a.add b
import sugar
let lam = (a,b:int) => a+b

# echo df.

  # sg:int

# sr.add sg.toAny

# echo sr[^1].kind

# echo cast[any](sr[^1][]).getInt

