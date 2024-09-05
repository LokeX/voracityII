import win except align,split,strip
import batch
import colors
import sequtils
import strutils
import game
import deck
import board
import eval
import misc
import os
import sugar

type 
  CashedCards = seq[tuple[title:string,count:int]]  
  KillMatrix = array[PlayerColor,array[PlayerColor,int]]
  PlayedCard* = enum Drawn,Played,Cashed,Discarded
  ReportBatches = array[PlayerColor,Batch]
  Alias = array[8,char]
  GameStats[T,U] = object
    turnCount:int
    playerKinds:array[6,U]
    aliases:array[6,T]
    winner:T
    cash:int
  TurnReport = object
    turnNr:int
    playerBatch:tuple[color:PlayerColor,kind:PlayerKind]
    diceRolls*:seq[Dice]
    moves*:seq[Move]
    cards*:tuple[drawn,played,cashed,discarded,hand:seq[BlueCard]]
    kills:seq[PlayerColor]

const
  robotoRegular* = "fonts\\Roboto-Regular_1.ttf"
  killMatrixFont = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  reportFont = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  visitsFile = "dat\\visits.txt"
  cashedFile = "dat\\cashed.txt"
  statsFile = "dat\\stats.dat"
  (rbx,rby) = (450,280)

  statsBatchInit = BatchInit(
    kind:TextBatch,
    name:"stats",
    pos:(460,530),
    padding:(15,75,8,15),
    font:(robotoRegular,20.0,color(1,1,1)),
    bgColor:color(0,0,0),
    opacity:25,
    shadow:(10,1.5,color(255,255,255,150))
  )

let
  plainFont = setNewFont(reportFont,18,contrastColors[turnPlayer.color])
  matrixFont = setNewFont(killMatrixFont,size = 16.0)
  roboto = setNewFont(robotoRegular,size = 15.0)

var
  statsBatch = newBatch statsBatchInit
  reportBatches:ReportBatches
  selectedBatch:int
  turnReports:seq[TurnReport]
  turnReport*:TurnReport
  gameStats:seq[GameStats[string,PlayerKind]]

proc victims(killer:PlayerColor):seq[PlayerColor] =
  for report in turnReports:
    if report.playerBatch.color == killer:
      result.add report.kills
  if killer == turnPlayer.color:
    result.add turnReport.kills

proc killMatrix:KillMatrix =
  for killer in PlayerColor:
    for victim in PlayerColor:
      result[victim][killer] = killer.victims.count victim

proc typesetKillMatrix(width,height:float):Arrangement =
  var 
    spans:seq[Span]
    font:Font
    playerKills:array[PlayerColor,tuple[font:Font,kills:int]]
  for player,row in killMatrix():
    font = matrixFont.copy
    font.paint = playerColors[PlayerColor(player)]
    playerKills[player].font = font
    for playerColumn,value in row:
      spans.add newSpan(($value).align(8),font)
      playerKills[playerColumn].kills += value
      if playerColumn == row.high: 
        spans.add newSpan(($row.sum).align(8)&"\n",font) 
  spans.add playerKills.mapIt(newSpan(($it.kills).align(8),it.font))
  spans.add newSpan("\U2211".align 8,font)
  spans.typeset(bounds = vec2(width,height))

proc paintMatrixShadow(img:Image):Image =
  var ctx = newImage(img.width+5,img.height+5).newContext
  ctx.fillStyle = color(0,0,0,100)
  ctx.fillRect(Rect(x:5,y:5,w:img.width.toFloat,h:img.height.toFloat))
  ctx.image.draw(img,translate vec2(0,0))
  ctx.image

proc paintKillMatrix:Image =
  let (width,height) = (250,210)
  result = newImage(width,height)
  result.fill color(0,100,100)
  var 
    ctx = result.newContext
    xPos:int
  for color in playerColors:
    ctx.fillStyle = color
    ctx.fillRect(Rect(x:(20+(xPos*32)).toFloat,y:15,w:20,h:20))
    inc xPos
  ctx.image.fillText(typesetKillMatrix(width.toFloat,height.toFloat/2),translate vec2(0,50))
  result = ctx.image.paintMatrixShadow
  result.applyOpacity 25

var 
  killMatrixPainter = DynamicImage[void](
    name:"killMatrix",
    area:(250+bx.toInt,250+by.toInt,0,0),
    updateImage:paintKillMatrix,
    update:true
  )

proc drawKillMatrix*(b:var Boxy) =
  b.drawDynamicImage killMatrixPainter

proc initReportBatch:Batch = 
  newBatch BatchInit(
    kind:TextBatch,
    name:"aireport",
    pos:(rbx,rby),
    padding:(20,20,20,20),
    font:(reportFont,24,color(1,1,1)),
    border:(5,15,color(0,0,0)),
    bgColor:color(245,0,0),
    blur:2,
    opacity:25,
    shadow:(10,1.75,color(255,255,255,100))
  )

proc initReportBatches:ReportBatches =
  for i,batch in reportBatches.enum_mitems:
    batch = initReportBatch()
    batch.commands: batch.border.color = playerColors[PlayerColor(i)]
    result[PlayerColor(i)] = batch

proc reports*(playerColor:PlayerColor):seq[TurnReport] =
  turnReports.filterIt(it.playerBatch.color == playerColor)

func reportLines(report:TurnReport):seq[string] = @[
  "Turn nr: "&($report.turnNr),
  "Player: "&($report.playerBatch),
  "Dice Rolls:\n"&report.diceRolls.mapIt($it).join("\n"),
  "Moves:\n"&report.moves.mapIt($it).join("\n"),
  "Kills: "&($report.kills),
  "Cards:\n",
  "Played: "&report.cards.played.mapIt(it.title).join(","),
  "Cashed: "&report.cards.cashed.mapIt(it.title).join(","),
  "Discarded: "&report.cards.discarded.mapIt(it.title).join(","),
]

proc reportSpansFrom(turnReport:TurnReport):seq[Span] =
  for line in reportLines turnReport:
    result.add newSpan(line&"\n",plainFont)

proc echoTurn(report:TurnReport) =
  for fn,item in turnReport.fieldPairs:
    when typeOf(item) is tuple:
      for n,i in item.fieldPairs: 
        echo n,": ",$i
    else: 
      echo fn,": ",$item

proc recordTurnReport* =
  turnReport.cards.hand = turnPlayer.hand
  echoTurn turnReport
  turnReports.add turnReport

proc writeEndOfGameReports =
  for player in players:
    let report = if player.color == turnPlayer.color: turnReport else:
      turnReports.filterIt(it.playerBatch.color == player.color)[^1]
    var reportLines = report.reportLines
    reportLines.add @[
      "Drawn: "&report.cards.drawn.mapIt(it.title).join(","),
      "Hand: "&player.hand.mapIt(it.title).join(","),
      "Press and hold alt-key to view players hand"
    ]
    reportBatches[player.color].setSpans reportLines.mapIt newSpan(it&"\n",plainFont)

proc initTurnReport* =
  turnReport = TurnReport()
  turnReport.turnNr = turnPlayer.turnNr+1
  turnReport.playerBatch.color = turnPlayer.color
  turnReport.playerBatch.kind = turnPlayer.kind
  reportBatches[turnPlayer.color].setSpans reportSpansFrom turnReport
  reportBatches[turnPlayer.color].update = true

proc writeUpdate =
  reportBatches[turnPlayer.color].setSpans reportSpansFrom turnReport
  if turnPlayer.cash >= cashToWin:
    writeEndOfGameReports()
  reportBatches[turnPlayer.color].update = true

proc updateTurnReport*[T](item:T) =
  when typeOf(T) is Move: 
    turnReport.moves.add item
  when typeof(T) is Dice: 
    turnReport.diceRolls.add item
  when typeof(T) is PlayerColor: 
    turnReport.kills.add item
    killMatrixPainter.update = true
  writeUpdate()
  
proc updateTurnReportCards*(blues:seq[BlueCard],playedCard:PlayedCard) =
  case playedCard
  of Drawn: turnReport.cards.drawn.add blues
  of Played: turnReport.cards.played.add blues
  of Cashed: turnReport.cards.cashed.add blues
  of Discarded: turnReport.cards.discarded.add blues
  writeUpdate()

proc resetReports* =
  for batch in reportBatches.mitems:
    batch.setSpans @[]
  initTurnReport()
  turnReports.setLen 0
  selectedBatch = -1
  killMatrixPainter.update = true

template gotReport*(player:PlayerColor):bool =
  reportBatches[player].spansLength > 0

proc startAnimation(batch:var Batch) =
  batch.setShallowPos(
    batch.rect.x.toInt,
    (batch.rect.y-batch.rect.h).toInt
  )

proc animate(batch:var Batch) =
  if batch.rect.y.toInt < rby:
    batch.setShallowPos(rbx,(batch.rect.y+30).toInt)
    batch.update = true
  elif batch.rect.y.toInt > rby:
    batch.setPos(rbx,rby)
    batch.update = true

proc drawReport*(b:var Boxy,playerColor:PlayerColor) =
  if selectedBatch == -1 or playerColor != PlayerColor(selectedBatch):
    selectedBatch = playerColor.ord
    reportBatches[playerColor].startAnimation
  if reportBatches[playerColor].rect.y.toInt != rby:
    animate reportBatches[playerColor]
  b.drawDynamicImage reportBatches[playerColor]

let (robotoPurple,robotoYellow,robotoGreen,robotoWhite,robotolh7) = block:
  var rob = roboto.copy
  rob.lineHeight = 24
  var 
    robotoYellow = rob.copy
    robotoPurple = rob.copy
    robotoGreen = rob.copy
    robotoWhite = rob.copy
    robotolh7 = rob.copy
  robotoGreen.size = 22
  robotoWhite.size = 18
  robotolh7.lineHeight = 7
  robotoPurple.paint = color(25,0,25)
  robotoYellow.paint = color(25,25,0)
  robotoGreen.paint = color(0,25,0)
  robotoWhite.paint = color(25,25,25)
  (robotoPurple,robotoYellow,robotoGreen,robotoWhite,robotolh7)

proc getLoneAlias:string =
  if (let aliases = playerHandles.filterIt(it.isAlpha).deduplicate; aliases.len > 0):
    if aliases.count(aliases[0]) == aliases.len:
      result = aliases[0]

func aliasCounts(handles:openArray[string]):seq[(string,int)] =
  handles.filterIt(it.isAlpha).deduplicate.mapIt (it,handles.count it)

proc playerHandlesMatch(aliases:openArray[string]):bool =
  for (alias,count) in aliases.aliasCounts:
    if count != playerHandles.count alias:
      return false
  true

proc countKinds:(int,int) =
  for kind in playerKinds:
    if kind == Human:
      inc result[0]
    elif kind == Computer:
      inc result[1]

template matchStats(statsMatching,aliasMatching:untyped):untyped =
  let 
    (humanCount {.inject.},computerCount {.inject.}) = countKinds()
    kindMatches {.inject.} = statsMatching
    playerHandleMatches = aliasMatching
  # echo kindMatches
  # echo playerHandleMatches
  if playerHandleMatches.len > 0: playerHandleMatches else: kindMatches

proc matchingStats:seq[GameStats[string,PlayerKind]] =
  matchStats(
    gameStats.filterIt(
      it.playerKinds.count(Human) == humanCount and 
      it.playerKinds.count(Computer) == computerCount),
    kindMatches.filterIt(playerHandlesMatch it.aliases))

proc noneMatchingStats:seq[GameStats[string,PlayerKind]] =
  matchStats(
    gameStats.filterIt(
      it.playerKinds.count(Human) != humanCount or 
      it.playerKinds.count(Computer) != computerCount),
    kindMatches.filterIt(not playerHandlesMatch it.aliases))

proc statsBatchSpans:seq[Span] =
  let (loneAlias,matches) = (getLoneAlias(),matchingStats())
  if gameStats.len > 0 and matches.len > 0:
    let 
      turns = matches.mapIt(it.turnCount).sum
      avgTurns = turns div matches.len
      computerWins = matches.countIt it.winner == "computer"
      humanWins = matches.len - computerWins
      handle = if loneAlias.len > 0: loneAlias else: "Human"
      computerPercent = ((computerWins.toFloat/matches.len.toFloat)*100)
        .formatFloat(ffDecimal,2)
      humanPercent = ((humanWins.toFloat/matches.len.toFloat)*100)
        .formatFloat(ffDecimal,2)
    result = @[
      newSpan("Statistics ",robotoGreen),
      newSpan(if mouseOn statsBatch: "  -   click to reset\n" else: "\n",robotoWhite),
      newSpan("\n",robotolh7),
      newSpan("Games: ",robotoPurple),
      newSpan($(matches.len),robotoYellow),
      newSpan("  |  Turns: ",robotoPurple),
      newSpan($turns,robotoYellow),
      newSpan("  |  Avg turns: ",robotoPurple),
      newSpan($avgTurns&"\n",robotoYellow),
      newSpan(handle&" wins: ",robotoPurple),
      newSpan($humanWins,robotoYellow),
      newSpan("  |  ",robotoPurple),
      newSpan(humanPercent&"%\n",robotoYellow),
      newSpan("Computer wins: ",robotoPurple),
      newSpan($computerWins,robotoYellow),
      newSpan("  |  ",robotoPurple),
      newSpan(computerPercent&"%",robotoYellow),
    ]

proc updateStatsBatch* =
  statsBatch.setSpans statsBatchSpans()
  statsBatch.update = true

template statsBatchVisible*: untyped =
  statsBatch.spansLength > 0
  
proc drawStats*(b:var Boxy) =
  if statsBatch.spansLength > 0:
    let (mouseOver,spanEmpty) = (mouseOn(statsBatch),statsBatch.getSpanText(1).len == 1)
    if (mouseOver and spanEmpty) or (not mouseOver and not spanEmpty):
      statsBatch.setSpanText(if mouseOn statsBatch: "  -   click to reset\n" else: "\n",1)
      statsBatch.update = true
      # updateStatsBatch()
    b.drawDynamicImage statsBatch

template mouseOnStatsBatch*:bool =
  mouseOn statsBatch

func readReportedVisits(turnReports:seq[TurnReport]):array[1..60,int] =
  for square in turnReports.mapIt(it.moves.mapIt(it.toSquare)).flatMap.filterIt(it != 0):
    inc result[square]

proc readVisitsFile(path:string):array[1..60,int] =
  if fileExists path:
    var square = 1
    for line in lines path:
      try: result[square] = line.split[^1].parseInt except:discard
      inc square

func allSquareVisits(reportVisits,fileVisits:array[1..60,int]):array[1..60,int] =
  for idx in 1..60:
    result[idx] = reportVisits[idx] + fileVisits[idx]
    
proc writeSquareVisitsTo(path:string) =
  var squareVisits:seq[string]
  for i,visits in allSquareVisits(turnReports.readReportedVisits,readVisitsFile path):
    squareVisits.add squares[i].name&" Nr."&($i)&": "&($visits)
  writeFile(path,squareVisits.join "\n")

proc reportedCashedCards:CashedCards =
  let titles = collect:
    for report in turnReports:
      for card in report.cards.cashed: card.title
  for title in titles:
    if title notin result.mapIt it.title:
      result.add (title,titles.count title)

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
  
proc writeCashedCardsTo(path:string) =
  writeFile(path,
    allCashedCards(path)
    .mapIt(it.title&": "&($it.count))
    .join "\n"
  )

template winner:untyped =
  if turnReport.playerBatch.kind == Computer: "computer"
  elif playerHandles[turnReport.playerBatch.color.ord].isAlpha:
    playerHandles[turnReport.playerBatch.color.ord]
  else: "human"

proc newGameStats:GameStats[string,PlayerKind] = 
  GameStats[string,PlayerKind](
    turnCount:turnReport.turnNr,
    playerKinds:playerKinds,
    aliases:playerHandles,
    winner:winner,
    cash:cashToWin
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

proc toFileStats(stats:GameStats[string,PlayerKind]):GameStats[Alias,int] =
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

proc toGameStats(stats:GameStats[Alias,int]):GameStats[string,PlayerKind] =
  GameStats[string,PlayerKind](
    turnCount:stats.turnCount,
    cash:stats.cash,
    playerKinds:stats.playerKinds.ordToKind,
    aliases:stats.aliases.toStrings,
    winner:stats.winner.aliasToString
  )

proc writeGameStatsTo(path:string) =
  seqToFile(gameStats.mapIt it.toFileStats,path)

proc readGameStatsFrom(path:string) =
  if fileExists path:
    gameStats = fileToSeq(path,GameStats[Alias,int]).mapIt it.toGameStats

proc writeGamestats* =
  writeSquareVisitsTo visitsFile
  writeCashedCardsTo cashedFile
  if players.anyHuman and players.anyComputer:
    gameStats.add newGameStats()
    updateStatsBatch()
    writeGameStatsTo statsFile

proc resetMatchingStats* =
  gameStats = noneMatchingStats()
  writeGameStatsTo statsFile
  updateStatsBatch()

reportBatches = initReportBatches()
readGameStatsFrom statsFile
updateStatsBatch()
