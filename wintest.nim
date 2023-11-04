import win
import times

var
  frames = 0

proc cycle =
  inc frames

proc timer =
  echo frames
  frames = 0

addCall Call(cycle:cycle,timer:TimerCall(lastTime:cpuTime(),call:timer,secs:1.0))

runWinWith:
  callTimers()
  callCycles()
