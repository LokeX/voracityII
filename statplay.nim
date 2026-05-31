import play
import game
import times
import algorithm
import os
import stat
import strutils
import sequtils
import misc

proc getParams:seq[int] =
  for prm in commandLineParams():
    try: result.add prm.parseInt
    except:discard
    if result.len == 2:
      break

proc setSettings(prms:openArray[int]):tuple[nrOfGames,nrOfPlayers:int] =
  (result.nrOfGames,result.nrOfPlayers) = (100,6)
  if prms.len == 1:
    result.nrOfGames = prms[0]
  elif prms.len > 1: (result.nrOfGames,result.nrOfPlayers) = (prms[0],prms[1])

const
  fileName = "dat\\statlog.txt"

let
  time = cpuTime()
  settings = setSettings getParams()

var
  visitsCount:array[1..60,int]
  cashedCards:CashedCards

func indexOf(cards:CashedCards,title:string):int =
  for i,card in cards:
    if card.title == title:
      return i
  -1

proc addCards(cards:CashedCards) =
  for card in cards:
    if (let idx = cashedCards.indexOf(card.title); idx > -1):
      cashedCards[idx].count += card.count
    else: cashedCards.add card

proc cashedCardsStr:string =
  result.add "Cashed cards:\n"
  for card in cashedCards.sortedByIt it.count:
    result.add card.title&": "&($card.count)&"\n"

proc addVisits(visits:array[1..60,int]) =
  for i in 1..60:
    visitsCount[i] += visits[i]

proc visitsCountStr:string =
  result.add "Square visits:\n"
  result.add(
    toSeq(1..60)
    .mapIt((it,board[it].name,visitsCount[it]))
    .sortedByIt(it[2])
    .mapIt(it[1]&" Nr. "&($it[0])&": "&($it[2]))
    .join "\n"
  )

proc statsStr(time:float):string =
  let stats = getMatchingStats()
  result.add "Time: "&timeFmt(cpuTime()-time)&"\n"
  result.add "Games: "&($stats.games)&"\n"
  result.add "Turns: "&($stats.turns)&"\n"
  result.add "avgTurns: "
  result.add formatFloat(float(stats.turns)/float(stats.games),ffDecimal,2)&"\n"

initGame()
statGame = true
verbose = commandLineParams().anyIt it.toLower == "-v"
for i in 0..playerKinds.high:
  if i < settings.nrOfPlayers:
    playerKinds[i] = Computer
  else: playerKinds[i] = None

for i in 1..settings.nrOfGames:
  setupGame()
  startGame()
  echo "game nr: ",i
  while not gameWon:
      aiTakeTurn()
  endGame()
  if recordStats:
    gameStats.add newGameStats()
    addVisits turnReports.reportedVisitsCount
    addCards reportedCashedCards()
  # if turnReports[^1].turnNr < 10:
  #   for turnReport in turnReports:
  #     dumpTurnReport(turnReport)

if recordStats:
  let
    cards = cashedCardsStr()
    visits = visitsCountStr()
    stats = statsStr time
  writeFile(fileName,cards&visits&stats)
  echo cards
  echo visits
  echo stats
  echo "Wrote to file: "&fileName
