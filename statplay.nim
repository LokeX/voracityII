# import std/typedthreads,locks
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

type
  Stats = object
    visitsCounts:array[1..60,int]
    cashedCards:CountTable[string]
    nrOfTurns:int
    hasData:bool
  Process = object
    id,nrOfGames:int
    deck:Deck
    kinds:array[6,PlayerKind]

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

proc cashedCardsToStr(cashedCards:CountTable[string]):string =
  result.add "Cashed cards:\n"
  let cashedCards:CashedCards = cashedCards.pairs.toSeq
  for (title,count) in cashedCards.sorted (a,b) => b.count - a.count:
    result.add title&": "&($count)&"\n"

proc addVisits(visits:var Visits,addVisits:Visits) =
  for i in 1..60:
    visits[i] += addVisits[i]

proc visitsCountsToStr(visits:Visits):string =
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

proc add(stats:var Stats,nrOfTurns:int,cashedCards:CountTable[string],visits:Visits) =
  stats.nrOfTurns += nrOfTurns
  stats.visitsCounts.addVisits visits
  stats.cashedCards.merge cashedCards
  stats.hasData = true

proc newProcess(id,nrOfGames:int,deck:Deck,kinds:array[6,PlayerKind]):Process = 
  Process(
    id:id,
    nrOfGames:nrOfGames,
    deck:deck,
    kinds:kinds
  )

proc reduceOutputs(output:array[10,Stats]):Stats =
  for stats in output:
    if stats.hasData:
      result.add(
        stats.nrOfTurns,
        stats.cashedCards,
        stats.visitsCounts,
      )

proc outputStats(results:Stats) =
  let
    cards = cashedCardsToStr(results.cashedCards)
    visits = visitsCountsToStr(results.visitsCounts)
    stats = statsToStr(settings.nrOfGames,results.nrOfTurns,time)
  writeFile(fileName,cards&visits&stats)
  echo cards
  echo visits
  echo stats
  echo "Wrote to file: "&fileName

template initRun = 
  randomize()
  statGame = true
  recordStats = true
  verbose = commandLineParams().anyIt it.toLower == "-v"
  board = newBoard "dat\\board.txt"

proc playStatGames:Stats =
  var
    # threads:array[10,Thread[Process]]
    # lock:Lock
    outputs:array[10,Stats]
  # proc playGames(process:Process) {.thread,nimCall,gcsafe.} =
  proc playGames(process:Process) =
    template turnPlayer:untyped = statPlay.players[statPlay.turn.playerNr]
    template report:untyped = statPlay.report
    template turnReports:untyped = statPlay.report.turns
    var 
      statPlay = newStatPlay("stat",process.deck,process.kinds)
      stats:Stats
    for i in 1..process.nrOfGames:
      setupGame(statPlay)
      startGame(statPlay)
      echo "game nr: ",i
      while not gameWon:
          aiTakeTurn(statPlay)
      if recordStats:
        report.recordTurn(turnPlayer)
        stats.add(
          statPlay.turn.nr,
          turnReports.reportedCashedCards(),
          turnReports.reportedVisitsCount(),
        )
        # lock.acquire
        outputs[process.id] = stats
        # lock.release
  let
    # nrOfGames = settings.nrOfGames div 10
    deck = newDeck "decks\\blues.txt"
    kinds = newPlayerKinds settings.nrOfPlayers
  # for i in 0..threads.high:
  #   createThread(threads[i],playGames,newProcess(i,nrOfGames,deck,kinds))
  # initLock(lock)
  playGames newProcess(0,settings.nrOfGames,deck,kinds)
  # deinitLock(lock)
  reduceOutputs outputs

if settings.nrOfGames mod 10 == 0:
  initRun()
  let statResults = playStatGames()
  if recordStats: outputStats statResults
else: echo "nrOfGames must be in orders of magnitude"
