import play
import game
import sequtils
import times
import strutils
import misc

for i in 0..playerKinds.high:
  playerKinds[i] = Computer
let time = cpuTime()

for _ in 1..2:
  setupNewGame()
  startNewGame()
  configState = StatGame
  while not gameWon:
    aiTakeTurnPhase()
  gameStats.add newGameStats()

proc statsStr:string =
  let stats = getMatchingStats()
  result.add "Time: "&timeFmt(cpuTime()-time)&"\n"
  result.add "Games: "&($stats.games)&"\n"
  result.add "Turns: "&($stats.turns)&"\n"
  result.add "avgTurns: "
  result.add formatFloat(float(stats.turns)/float(stats.games),ffDecimal,2)&"\n"

echo statsStr()

