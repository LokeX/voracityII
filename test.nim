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

