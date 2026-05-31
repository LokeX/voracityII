import game
import strutils
import sequtils
import misc
import os
import sugar
import math

type
  TurnReport* = object
    turnNr*:int
    player*:tuple[color:PlayerColor,kind:PlayerKind]
    diceRolls*:seq[Dice]
    moves*:seq[Move]
    cards*:tuple[played:array[PlayedKind,seq[BlueCard]],hand:seq[BlueCard]]
    kills*:seq[PlayerColor]
    pieces:array[5,int]
    cash*:int
  CashedCards* = seq[tuple[title:string,count:int]]  
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
    avgTurns*:float
    computerWins*:int
    humanWins*:int
    handle*:string
    computerPercent*:string
    humanPercent*:string

const
  handlesFile = "dat\\handles.txt"
  visitsFile* = "dat\\visits.txt"
  cashedFile* = "dat\\cashed.txt"
  statsFile* = "dat\\stats.dat"

var
  turnReports*:seq[TurnReport]
  turnReport*:TurnReport
  gameStats*:seq[GameStats[string,PlayerKind]]
  playerHandles*:array[6,string]
  verbose* = false
  recordStats* = true

  #interface control
  reportBatchesUpdate*:proc()

template updateTurnReportBatches =
  if reportBatchesUpdate != nil:
    reportBatchesUpdate()

proc initTurnReport* =
  if recordStats:
    turnReport = TurnReport()
    turnReport.turnNr = turnPlayer.turnNr
    turnReport.player.color = turnPlayer.color
    turnReport.player.kind = turnPlayer.kind
    updateTurnReportBatches()

proc updateTurnReport*[T](item:T,playKind:PlayedKind = Drawn) =
  if recordStats:
    when typeOf(T) is Move:
      turnReport.moves.add item
    when typeOf(T) is Dice:
      turnReport.diceRolls.add item
    when typeof(T) is PlayerColor:
      turnReport.kills.add item
      killMatrixUpdate()
    when typeof(T) is BlueCard | seq[BlueCard]:
      turnReport.cards.played[playKind].add item
    updateTurnReportBatches()

proc dumpTurnReport*(turnReport:TurnReport) =
  proc moveStr(fromSquare,toSquare,die:int):string =
    "    Die: " & $die &
    ", from: "&board[fromSquare].name&" Nr. " & $board[fromSquare].nr &
    ", to: "&board[toSquare].name&" Nr. " & $board[toSquare].nr
  echo ""
  echo $turnReport.player.color
  echo "Turn: ",turnReport.turnNr
  echo "  DiceRolls:"
  echo turnReport.diceRolls.mapIt("    " & $it).join "\n"
  echo "  Moves:"
  echo turnReport.moves.mapIt(moveStr(it.fromSquare,it.toSquare,it.die)).join "\n"
  echo "  Cards:"
  let playedCards = turnReport.cards.played
  for playKind in PlayedKind:
    echo "    " & $playKind,": ",playedCards[playKind].mapIt(it.title).join ","
  echo "    Hand: ",turnReport.cards.hand.mapIt(it.title).join ","
  echo "  Pieces:"
  for square in turnReport.pieces:
    echo "    "&board[square].name&" Nr. " & $board[square].nr
  echo "  Cash: ",turnReport.cash
  if turnReport.cash >= cashToWin:
    echo ""
    echo "Gameover"
    echo ""

proc recordTurnReport* =
  if recordStats:
    turnReport.cards.hand = turnPlayer.hand
    turnReport.cash = turnPlayer.cash
    turnReport.pieces = turnPlayer.pieces
    turnReports.add turnReport
    if verbose: dumpTurnReport(turnReport)

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
      result.avgTurns = result.turns/matches.len
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
      for card in report.cards.played[Cashed]: card.title
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
    writeGameStatsTo statsFile

proc resetMatchingStats* =
  gameStats = noneMatchingStats()
  writeGameStatsTo statsFile

proc playerHandlesToFile*(playerHandles:openArray[string]) =
  writeFile(handlesFile,playerHandles.mapIt(if it.len > 0: it else: "n/a").join "\n")

proc playerHandlesFromFile:array[6,string] =
  if fileExists handlesFile:
    var count = 0
    for line in lines handlesFile:
      let lineStrip = line.strip
      if lineStrip != "n/a":
        result[count] = lineStrip
      inc count

template initStats* =
  playerHandles = playerHandlesFromFile()
