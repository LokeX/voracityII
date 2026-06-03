type 
  Test* = object
    a*:int

var
  test*:Test

test.a = 1

template a*:untyped = test.a
