template exclude(things,excludeThing:untyped):untyped =
  case (let index = things.find excludeThing; index)
  of -1: 
    when typeof(things) is not seq: @things else: things
  of things.low: things[things.low+1..things.high]
  of things.high: things[things.low..things.high-1]
  else: things[things.low..index-1] & things[index+1..things.high]

echo [3,4,5].exclude 3

for x in 'a'..'z': echo x

