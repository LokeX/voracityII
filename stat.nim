import play
import game
# import times
import strutils
import sequtils
import misc
import os
# import algorithm
import sugar
import math

type
  Alias* = array[8,char]
  GameStats*[T,U] = object
    turnCount*:int
    playerKinds*:array[6,U]
    aliases*:array[6,T]
    winner*:T
    cash*:int
  AliasCounts = seq[tuple[alias:string,count:int]]
  KindCounts = array[PlayerKind,int]
  Stats = GameStats[string,PlayerKind]
  MatchingStats* = object
    hasData*:bool
    games*:int
    turns*:int
    avgTurns*:int
    computerWins*:int
    humanWins*:int
    handle*:string
    computerPercent*:string
    humanPercent*:string

const
  visitsFile* = "dat\\visits.txt"
  cashedFile* = "dat\\cashed.txt"
  statsFile* = "dat\\stats.dat"

var
  gameStats*:seq[GameStats[string,PlayerKind]]

proc getLoneAlias:string =
  for i in 0..playerHandles.high:
    if playerKinds[i] == Human and playerHandles[i].len > 0:
      if result.len > 0: 
        if result != playerHandles[i]: 
          return ""
      else: result = playerHandles[i]

proc aliasCounts(aliases:openArray[string]):AliasCounts =
  for i,alias in aliases:
    if playerKinds[i] == Human and alias.len > 0 and result.allIt(it.alias != alias):
      result.add (alias,playerHandles.count alias)

proc kindCounts(kinds:openArray[PlayerKind]):KindCounts =
  for kind in kinds:
    inc result[kind]

proc match(stats:Stats,aliasCounts:AliasCounts):bool =
  for (alias,count) in aliasCounts:
    if stats.aliases.count(alias) != count: 
      return
  true

proc match(stats:Stats,kindCounts:KindCounts):bool =
  for i,count in kindCounts:
    if stats.playerKinds.count(PlayerKind(i)) != count:
      return
  true

template selectWith(selector,selectionCode:untyped) =
  let 
    kindCounts {.inject.} = playerKinds.kindCounts
    aliasCounts {.inject.} = playerHandles.aliasCounts
  for selector in gameStats:
    selectionCode

proc statsMatches:seq[Stats] =
  selectWith stats:
    if stats.match(kindCounts) and stats.match(aliasCounts):
      result.add stats

proc noneMatchingStats*:seq[Stats] =
  selectWith stats:
    if not stats.match(kindCounts) or not stats.match(aliasCounts):
      result.add stats

proc getMatchingStats*:MatchingStats =
  if gameStats.len > 0: 
    let 
      loneAlias = getLoneAlias()
      matches = statsMatches()
    if matches.len > 0:
      result.hasData = true
      result.games = matches.len
      result.turns = matches.mapIt(it.turnCount).sum
      result.avgTurns = result.turns div matches.len
      result.computerWins = matches.countIt it.winner == "computer"
      result.humanWins = matches.len - result.computerWins
      result.handle = if loneAlias.len > 0: loneAlias else: $turnPlayer.kind
      result.computerPercent = ((result.computerWins.toFloat/matches.len.toFloat)*100)
        .formatFloat(ffDecimal,2)
      result.humanPercent = ((result.humanWins.toFloat/matches.len.toFloat)*100)
        .formatFloat(ffDecimal,2)

proc newGameStats*:GameStats[string,PlayerKind] = 
  GameStats[string,PlayerKind](
    turnCount:turnReport.turnNr,
    playerKinds:playerKinds,
    aliases:playerHandles,
    winner:($turnPlayer.kind).toLower,
    cash:cashToWin
  )

proc reportedCashedCards*:CashedCards =
  let titles = collect:
    for report in turnReports:
      for card in report.cards.cashed: card.title
  for title in titles.deduplicate:
    result.add (title,titles.count title)

func reportedVisitsCount*(turnReports:seq[TurnReport]):array[1..60,int] =
  for report in turnReports:
    for move in report.moves:
      if move.toSquare > 0:
        inc result[move.toSquare]

proc readVisitsFile(path:string):array[1..60,int] =
  if fileExists path:
    var square = 1
    for line in lines path:
      try: result[square] = line.split[^1].parseInt except:discard
      inc square

func allSquareVisits(reportVisits,fileVisits:array[1..60,int]):array[1..60,int] =
  for idx in 1..60:
    result[idx] = reportVisits[idx] + fileVisits[idx]
    
proc writeSquareVisitsTo*(path:string) =
  var squareVisits:seq[string]
  for i,visits in allSquareVisits(turnReports.reportedVisitsCount,readVisitsFile path):
    squareVisits.add board[i].name&" Nr."&($i)&": "&($visits)
  writeFile(path,squareVisits.join "\n")

proc readCashedCardsFrom(path:string):CashedCards =
  if fileExists path:
    for line in lines path:
      let lineSplit = line.split ':'
      try: result.add (lineSplit[0],lineSplit[^1].strip.parseInt)
      except:discard

proc allCashedCards(path:string):CashedCards =
  result = readCashedCardsFrom path
  for card in reportedCashedCards():
    if (let idx = result.mapIt(it.title).find card.title; idx != -1):
      result[idx].count = card.count+result[idx].count
    else: result.add card
  
proc writeCashedCardsTo*(path:string) =
  writeFile(
    path,allCashedCards(path)
    .mapIt(it.title&": "&($it.count))
    .join "\n"
  )

func aliasToChars(alias:string):Alias =
  for i,ch in alias:
    if i < result.len: 
      result[i] = ch
      if i == alias.high and i < result.high:
        result[i+1] = '\n'
    else: return

func kindToOrd(kinds:array[6,PlayerKind]):array[6,int] =
  for i,kind in kinds:
    result[i] = kind.ord

func toChars(aliases:array[6,string]):array[6,Alias] =
  for i,alias in aliases:
    result[i] = alias.aliasToChars

proc toFileStats*(stats:GameStats[string,PlayerKind]):GameStats[Alias,int] =
  GameStats[Alias,int](
    turnCount:stats.turnCount,
    cash:stats.cash,
    playerKinds:stats.playerKinds.kindToOrd,
    aliases:stats.aliases.toChars,
    winner:stats.winner.aliasToChars
  )

func aliasToString(alias:Alias):string =
  for ch in alias: 
    if ch != '\n': result.add ch
    else: return

func ordToKind(ks:array[6,int]):array[6,PlayerKind] =
  for i,kind in ks: 
    result[i] = PlayerKind(kind)

func toStrings(aliases:array[6,Alias]):array[6,string] =
  for i,alias in aliases:
    result[i] = alias.aliasToString

proc toGameStats*(stats:GameStats[Alias,int]):GameStats[string,PlayerKind] =
  GameStats[string,PlayerKind](
    turnCount:stats.turnCount,
    cash:stats.cash,
    playerKinds:stats.playerKinds.ordToKind,
    aliases:stats.aliases.toStrings,
    winner:stats.winner.aliasToString
  )

proc writeGameStatsTo(path:string) =
  seqToFile(gameStats.mapIt it.toFileStats,path)

proc readGameStatsFrom*(path:string) =
  if fileExists path:
    gameStats = fileToSeq(path,GameStats[Alias,int]).mapIt it.toGameStats

proc writeGamestats* =
  writeSquareVisitsTo visitsFile
  writeCashedCardsTo cashedFile
  if players.anyHuman and players.anyComputer:
    echo "nr of stat games: ",gameStats.len
    gameStats.add newGameStats()
    echo "nr of stat games: ",gameStats.len
    # updateStatsBatch()
    writeGameStatsTo statsFile

proc resetMatchingStats* =
  gameStats = noneMatchingStats()
  writeGameStatsTo statsFile
  # updateStatsBatch()

when isMainModule:
  import times
  import algorithm

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
    agroRanches:array[20,int]

  proc addAgroRanches =
    for rep in turnReports:
      if rep.cash >= cashToWin:
        inc agroRanches[rep.agro div 5]

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
    for i in 1..60:
      result.add board[i].name&" Nr. "&($i)&": "&($visitsCount[i])&"\n"

  proc statsStr(time:float):string =
    let stats = getMatchingStats()
    result.add "Time: "&timeFmt(cpuTime()-time)&"\n"
    result.add "Games: "&($stats.games)&"\n"
    result.add "Turns: "&($stats.turns)&"\n"
    result.add "avgTurns: "
    result.add formatFloat(float(stats.turns)/float(stats.games),ffDecimal,2)&"\n"

  initGame()
  for i in 0..playerKinds.high:
    if i < settings.nrOfPlayers:
      playerKinds[i] = Computer
    else: playerKinds[i] = None
  statGame = true

  for i in 1..settings.nrOfGames:
    setupNewGame()
    startNewGame()
    echo "game nr: ",i
    while not gameWon:
        aiTakeTurnPhase()
    endGame()
    if recordStats:
      gameStats.add newGameStats()
      addVisits turnReports.reportedVisitsCount 
      addCards reportedCashedCards()
      addAgroRanches()

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

    for i,agro in agroRanches:
      echo $(i*5),"..",$(((i+1)*5)-1),": ",agro
