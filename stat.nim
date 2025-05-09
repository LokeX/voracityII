import play
import game
import eval
import sequtils
import times
import strutils
import misc
import os

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

const 
  fileName = "dat\\statlog.txt"

let 
  time = cpuTime()
 
proc statsStr:string =
  let stats = getMatchingStats()
  result.add "Time: "&timeFmt(cpuTime()-time)&"\n"
  result.add "Games: "&($stats.games)&"\n"
  result.add "Turns: "&($stats.turns)&"\n"
  result.add "avgTurns: "
  result.add formatFloat(float(stats.turns)/float(stats.games),ffDecimal,2)&"\n"

for i in 0..playerKinds.high:
  playerKinds[i] = Computer

recordStats = false

for i in 1..100:
  setupNewGame()
  startNewGame()
  configState = StatGame
  echo "game nr: ",i
  echo getFreeMem()
  while not gameWon:
    # let p = phase
    # echoStats "phase = "&($p):
      echo phase
      aiTakeTurnPhase()
      # echo turnReport
      soundToPlay.setLen 0
  if recordStats:
    gameStats.add newGameStats()
    addVisits turnReports.reportedVisitsCount 
    addCards reportedCashedCards()
 
if recordStats:
  let
    cards = cashedCardsStr()
    visits = visitsCountStr()
    stats = statsStr()

  writeFile(fileName,cards&visits&stats)

  echo cards
  echo visits
  echo stats

  echo "Wrote to file: "&fileName

