type 
  Test = object
    f1:int
    f2:float

var
  thp = cast[ptr Test](alloc(sizeof Test))
  nhp = cast[ptr Test](alloc(sizeof Test))
thp.f1 = 12
thp.f2 = 2.1

copyMem(nhp,thp,sizeof Test)

var
  hell:seq[pointer]
  nr = cast[ref Test](nhp.addr)


proc t(p:ptr Test) =
  echo p[]

t nhp

thp.dealloc
nhp.dealloc

var
  y = new Test
y.f1 = 12 
y.f2 = 2.0


var
  x = y[]
  z = cast[ref Test](x.addr)
z.f1 = 13
echo z[]
echo y[]




