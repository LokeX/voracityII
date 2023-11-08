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

type 
  Stat = tuple[name:string,count:int]
  Stats = tuple[game,won,lost:seq[Stat]]
  CashedCards = seq[tuple[title:string,count:int]]  
  KillMatrix = array[PlayerColor,array[PlayerColor,int]]
  PlayedCard* = enum Drawn,Played,Cashed,Discarded
  ReportBatches = array[PlayerColor,Batch]
  TurnReport* = object
    turnNr:int
    playerBatch:tuple[color:PlayerColor,kind:PlayerKind]
    diceRolls*:seq[Dice]
    moves*:seq[Move]
    cards*:tuple[drawn,played,cashed,discarded:seq[BlueCard]]
    kills:seq[PlayerColor]

const
  robotoRegular* = "fonts\\Roboto-Regular_1.ttf"
  killMatrixFont = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  reportFont = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  visitsFile = "dat\\visits.txt"
  cashedFile = "dat\\cashed.txt"
  gamesFile = "dat\\games.txt"
  (rbx,rby) = (450,280)

  condensedRegular = "fonts\\AsapCondensed-Regular.ttf"
  statsBatchInit = BatchInit(
    kind:InputBatch,
    name:"stats",
    pos:(450,550),
    padding:(20,20,10,10),
    # entries:inputEntries,
    font:(condensedRegular,20.0,color(1,1,1)),
    bgColor:color(0,0,0),
    # blur:2,
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
  gameStats:seq[Stat]

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
  let matrix = killMatrix()
  var spans:seq[Span]
  for rowColor,row in matrix:
    var font = matrixFont.copy
    font.paint = playerColors[PlayerColor(rowColor)]
    for column,value in row:
      spans.add newSpan(($value).align(8),font)
      if column == row.high: spans[^1].text.add "\n"
  spans.typeset(bounds = vec2(width,height))

proc paintMatrixShadow(img:Image):Image =
  var ctx = newImage(225,205).newContext
  ctx.fillStyle = color(0,0,0,100)
  ctx.fillRect(Rect(x:5,y:5,w:220,h:200))
  ctx.image.draw(img,translate vec2(0,0))
  ctx.image

proc paintKillMatrix:Image =
  result = newImage(220,200)
  result.fill color(0,100,100)
  var 
    ctx = result.newContext
    xPos:int
  for color in playerColors:
    ctx.fillStyle = color
    ctx.fillRect(Rect(x:(20+(xPos*32)).toFloat,y:10,w:20,h:20))
    inc xPos
  ctx.image.fillText(typesetKillMatrix(200,100),translate vec2(0,50))
  result = ctx.image.paintMatrixShadow
  result.applyOpacity 25

var 
  killMatrixPainter = DynamicImage[void](
    name:"killMatrix",
    area:(300+bx.toInt,300+by.toInt,0,0),
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

proc recordTurnReport* =
  turnReports.add turnReport

proc writeEndOfGameReports =
  for player in players:
    let report = if player.color == turnPlayer.color: turnReport else:
      turnReports.filterIt(it.playerBatch.color == player.color)[^1]
    var reportLines = report.reportLines
    reportLines.add @[
      "Hand: "&player.hand.mapIt(it.title).join(","),
      "Drawn: "&report.cards.drawn.mapIt(it.title).join(","),
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

proc updateStats* =
  if gameStats.len > 0:
    var rob = roboto.copy
    rob.lineHeight = 24
    var 
      robotoYellow = rob.copy
      robotoPurple = rob.copy
    robotoPurple.paint = color(25,0,25)
    robotoYellow.paint = color(25,25,0)
    let 
      human = $((gameStats[3].count.toFloat/gameStats[1].count.toFloat)*100)
        .formatFloat(ffDecimal,2)
      computer = $((gameStats[2].count.toFloat/gameStats[1].count.toFloat)*100)
        .formatFloat(ffDecimal,2)
      spans = @[
        newSpan("Games: ",robotoPurple),
        newSpan($(gameStats[1].count),robotoYellow),
        newSpan("  |  Turns: ",robotoPurple),
        newSpan($gameStats[0].count,robotoYellow),
        newSpan("  |  Avg turns: ",robotoPurple),
        newSpan($(gameStats[0].count div gameStats[1].count)&"\n",robotoYellow),
        newSpan("Human wins: ",robotoPurple),
        newSpan($gameStats[3].count&"  |  ",robotoYellow),
        newSpan(human&"%\n",robotoYellow),
        newSpan("Computer wins: ",robotoPurple),
        newSpan($gameStats[2].count&"  |  ",robotoYellow),
        newSpan(computer&"%",robotoYellow),
      ]
    statsBatch.setSpans spans
    statsBatch.update = true

proc drawStats*(b:var Boxy) =
  if gameStats.len > 0:
    b.drawDynamicImage statsBatch

proc readReportedVisits:array[1..60,int] =
  for square in turnReports.mapIt(it.moves.mapIt(it.toSquare)).flatMap.filterIt(it != 0):
    inc result[square]

proc readVisitsFile(path:string):array[1..60,int] =
  if fileExists path:
    var square = 1
    for line in lines path:
      try: result[square] = line.split[^1].parseInt except:discard
      inc square
 
proc allSquareVisits(path:string):array[1..60,int] =
  let
    reportVisits = readReportedVisits()
    fileVisits = readVisitsFile path
  var idx = 1
  for visitCount in result.mitems:
    visitCount = reportVisits[idx] + fileVisits[idx]
    inc idx
  
proc writeSquareVisitsTo(path:string) =
  var squareVisits:seq[string]
  for i,visits in allSquareVisits path:
    squareVisits.add squares[i].name&" Nr."&($i)&": "&($visits)
  writeFile(path,squareVisits.join "\n")

proc reportedCashedCards:CashedCards =
  let titles = turnReports.mapIt(it.cards.cashed.mapIt(it.title)).flatMap
  for title in titles:
    if title notin result.mapIt it.title:
      result.add (title,titles.count title)

proc readCashedCardsFrom(path:string):CashedCards =
  if fileExists path:
    for line in lines path:
      let lineSplit = line.split
      try: 
        result.add (lineSplit[0],lineSplit[^1].parseInt)
      except:discard

proc allCashedCards(path:string):CashedCards =
  let cardsOnFile = readCashedCardsFrom path
  for card in reportedCashedCards():
    if (let idx = cardsOnFile.mapIt(it.title).find card.title; idx != -1):
      result.add (card.title,card.count+cardsOnFile[idx].count)
    else: result.add card
  
proc writeCashedCardsTo(path:string) =
  writeFile(path,allCashedCards(path).mapIt(it.title&": "&($it.count)).join "\n")

func parseGameStats(gameStatsLines:seq[string]):seq[Stat] =
  for line in gameStatsLines:
    let splitLine = line.split
    try: result.add (splitLine[0].strip,splitLine[^1].parseInt)
    except:discard

proc readGameStatsFrom(path:string):seq[Stat] =
  if fileExists path: 
    result = readFile(path).splitLines.parseGameStats

proc handleStats(path:string):seq[Stat] =
  let handle = playerHandles[turnReport.playerBatch.color.ord].toLower
  var propIdx = -1
  if turnReport.playerBatch.kind == Human:
    let prop = if handle.len > 0: handle else: "human"
    propIdx = gameStats.mapIt(it.name).find prop
    result.add (prop,(if propIdx == -1: 1 else: gameStats[propIdx].count+1))
  for idx in 3..gameStats.high:
    if idx != propIdx: result.add (gameStats[idx].name,gameStats[idx].count)

proc newGameStats:seq[Stat] =
  if gameStats.len == 0: 
    result.add ("turns",turnReport.turnNr)
    result.add ("games",1)
    result.add ("computer",(if turnReport.playerBatch.kind == Computer: 1 else: 0))
    result.add ("human",(if turnReport.playerBatch.kind == Human: 1 else: 0))
  else:
    result.add ("turns",gameStats[0].count+turnReport.turnNr)
    result.add ("games",gameStats[1].count+1)
    result.add ("computer",
      gameStats[2].count+(if turnReport.playerBatch.kind == Computer: 1 else: 0)
    )
    result.add ("human",
      gameStats[2].count+(if turnReport.playerBatch.kind == Human: 1 else: 0)
    )

proc writeGameStatsTo(path:string) =
  writeFile path,gameStats.mapIt(it.name&" = " & $it.count).join "\n"

proc writeGamestats* =
  writeSquareVisitsTo visitsFile
  writeCashedCardsTo cashedFile
  if players.anyHuman and players.anyComputer:
    gameStats = newGameStats()
    writeGameStatsTo gamesFile
    updateStats()

reportBatches = initReportBatches()
gameStats = readGameStatsFrom gamesFile
updateStats()
