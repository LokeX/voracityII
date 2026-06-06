
type
  Win = ref object of RootObj
    test:int
  Ext = ref object of Win
    test2:int

var
  # win = Win(test:1)
  ext = Ext(test2:2)
  win = ext

echo win[]
echo ext[]

# win[] = ext[]

ext.test = 5

echo win[]

