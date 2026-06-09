import sugar
import tables
import play
import game
import times
import algorithm
import os
import stat
import strutils
import sequtils
import misc
import random

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

template turnPlayer:untyped = 
  statPlay.players[statPlay.turn.playerNr]

template report:untyped =
  statPlay.report

template turnReports:untyped =
  statPlay.report.turns

proc cashedCardsToStr(cashedCards:CountTable[string]):string =
  result.add "Cashed cards:\n"
  let cashedCards:CashedCards = cashedCards.pairs.toSeq
  for (title,count) in cashedCards.sorted (a,b) => b.count - a.count:
    result.add title&": "&($count)&"\n"

proc addVisits(visits:var Visits,addVisits:Visits) =
  for i in 1..60:
    visits[i] += addVisits[i]

proc visitsCountToStr(visits:Visits):string =
  result.add "Square visits:\n"
  result.add(
    toSeq(1..60)
    .mapIt((it,board[it].name,visits[it]))
    .sortedByIt(it[2])
    .mapIt(it[1]&" Nr. "&($it[0])&": "&($it[2]))
    .join "\n"
  )

proc statsToStr(nrOfGames,nrOfTurns:int,time:float):string =
  result.add "Time: "&timeFmt(cpuTime()-time)&"\n"
  result.add "Games: "&($settings.nrOfGames)&"\n"
  result.add "Turns: "&($nrOfturns)&"\n"
  result.add "avgTurns: "
  result.add formatFloat(float(nrOfturns)/float(settings.nrOfGames),ffDecimal,2)&"\n"

proc newPlayerKinds(nrOfPlayers:int):array[6,PlayerKind] =
  for i in 0..result.high:
    if i < nrOfPlayers:
      result[i] = Computer
    else: result[i] = None

proc newStatPlay(id:string,deck:Deck,kinds:array[6,PlayerKind]):Play = Play(
  gameId:id,
  blueDeck:deck,
  playerKinds:kinds
)

randomize()
statGame = true
recordStats = true
verbose = commandLineParams().anyIt it.toLower == "-v"
board = newBoard "dat\\board.txt"

let
  deck = newDeck "decks\\blues.txt"
  kinds = newPlayerKinds settings.nrOfPlayers

var 
  statPlay = newStatPlay("stat",deck,kinds)
  visitsCounts:array[1..60,int]
  cashedCards:CountTable[string]
  nrOfTurns = 0

for i in 1..settings.nrOfGames:
  setupGame(statPlay)
  startGame(statPlay)
  echo "game nr: ",i
  while not gameWon:
      aiTakeTurn(statPlay)
  if recordStats:
    nrOfTurns += statPlay.turn.nr
    report.recordTurn(turnPlayer)
    visitsCounts.addVisits turnReports.reportedVisitsCount()
    cashedCards.merge turnReports.reportedCashedCards()

if recordStats:
  let
    cards = cashedCardsToStr(cashedCards)
    visits = visitsCountToStr(visitsCounts)
    stats = statsToStr(settings.nrOfGames,nrOfTurns,time)
  writeFile(fileName,cards&visits&stats)
  echo cards
  echo visits
  echo stats
  echo "Wrote to file: "&fileName
