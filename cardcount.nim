import strutils

const fileName = "dat\\blues.txt"

var plans,missions,jobs,events,news:int
for line in lines fileName:
  let colon = line.find ":"
  if colon != -1:
    case line[0..<colon]
    of "plan": inc plans
    of "mission": inc missions
    of "job": inc jobs
    of "event": inc events
    of "news": inc news
    else: discard

echo "plans: "&($plans)
echo "missions: "&($missions)
echo "jobs: "&($jobs)
echo "events: "&($events)
echo "news: "&($news)

