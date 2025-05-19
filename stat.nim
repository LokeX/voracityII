import play
import game
import times
import strutils
import misc
import os

proc getParams:seq[int]
proc setSettings(prms:openArray[int]):tuple[nrOfGames,nrOfPlayers:int]

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
  for card in cashedCards:
    result.add card.title&": "&($card.count)&"\n"

proc addVisits(visits:array[1..60,int]) =
  for i in 1..60:
    visitsCount[i] += visits[i]

proc visitsCountStr:string =
  result.add "Square visits:\n"
  for i in 1..60:
    result.add board[i].name&" Nr. "&($i)&": "&($visitsCount[i])&"\n"

proc statsStr(time:float):string =
  let stats = getMatchingStats()
  result.add "Time: "&timeFmt(cpuTime()-time)&"\n"
  result.add "Games: "&($stats.games)&"\n"
  result.add "Turns: "&($stats.turns)&"\n"
  result.add "avgTurns: "
  result.add formatFloat(float(stats.turns)/float(stats.games),ffDecimal,2)&"\n"

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


for i in 0..playerKinds.high:
  if i < settings.nrOfPlayers:
    playerKinds[i] = Computer
  else: playerKinds[i] = None
statGame = true
for i in 1..settings.nrOfGames:
  setupNewGame()
  startNewGame()
  echo "game nr: ",i
  # echo getFreeMem()
  while not gameWon:
      aiTakeTurnPhase()
      # soundToPlay.setLen 0
  if recordStats:
    gameStats.add newGameStats()
    addVisits turnReports.reportedVisitsCount 
    addCards reportedCashedCards()
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

