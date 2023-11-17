import random
import strutils
randomize()
var 
  randNr = rand 1..100
  guess:int
echo "guess the number between 1..100:"
while guess != randNr:
  if guess != 0:
    if guess < randNr: echo "go higher"
    else: echo "go lower"
  guess = 0
  try: guess = stdin.readLine.parseInt 
  except: echo "not a number - please, type a number"
echo "that's it!"
