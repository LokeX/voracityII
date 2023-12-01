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
import jsony
import sugar

type 
  CashedCards = seq[tuple[title:string,count:int]]  
  KillMatrix = array[PlayerColor,array[PlayerColor,int]]
  PlayedCard* = enum Drawn,Played,Cashed,Discarded
  ReportBatches = array[PlayerColor,Batch]
  GameStats = object
    turnCount:int
    playerKinds:array[6,PlayerKind]
    aliases:array[6,string]
    winner:string
    cash:int
  TurnReport = object
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
  jsonStatsFile = "dat\\jsonstats.txt"
  (rbx,rby) = (450,280)

  statsBatchInit = BatchInit(
    kind:TextBatch,
    name:"stats",
    pos:(450,550),
    padding:(20,20,10,10),
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
  gameStats:seq[GameStats]

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
  var spans:seq[Span]
  for rowColor,row in killMatrix():
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

let (robotoPurple,robotoYellow) = block:
  var rob = roboto.copy
  rob.lineHeight = 24
  var 
    robotoYellow = rob.copy
    robotoPurple = rob.copy
  robotoPurple.paint = color(25,0,25)
  robotoYellow.paint = color(25,25,0)
  (robotoPurple,robotoYellow)

func getLoneAlias(playerHandles:openArray[string]):string =
  for handle in playerHandles:
    if handle.len > 0: return handle

proc matchingGames(stats:seq[GameStats]):tuple[alias:string,matches:seq[GameStats]] =
  let 
    humanCount = playerKinds.count Human
    computerCount = playerKinds.count Computer
    kindMatches = stats.filterIt(
      it.playerKinds.count(Human) == humanCount and 
      it.playerKinds.count(Computer) == computerCount
    )
  if humanCount == 1 and (let alias = playerHandles.getLoneAlias(); alias.len > 0): 
    (alias,kindMatches.filterIt(alias in it.aliases))
  else: ("",kindMatches)

proc statsBatchSpans:seq[Span] =
  if gameStats.len > 0 and (let stats = gameStats.matchingGames(); stats.matches.len > 0):
    let 
      turns = stats.matches.mapIt(it.turnCount).sum
      avgTurns = turns div stats.matches.len
      computerWins = stats.matches.countIt it.winner == "computer"
      humanWins = stats.matches.len - computerWins
      handle = if stats.alias.len > 0: stats.alias else: "Human"
      computerPercent = ((computerWins.toFloat/stats.matches.len.toFloat)*100)
        .formatFloat(ffDecimal,2)
      humanPercent = ((humanWins.toFloat/stats.matches.len.toFloat)*100)
        .formatFloat(ffDecimal,2)
    result = @[
        newSpan("Games: ",robotoPurple),
        newSpan($(stats.matches.len),robotoYellow),
        newSpan("  |  Turns: ",robotoPurple),
        newSpan($turns,robotoYellow),
        newSpan("  |  Avg turns: ",robotoPurple),
        newSpan($avgTurns&"\n",robotoYellow),
        newSpan(handle&" wins: ",robotoPurple),
        newSpan($humanWins&"  |  ",robotoYellow),
        newSpan(humanPercent&"%\n",robotoYellow),
        newSpan("Computer wins: ",robotoPurple),
        newSpan($computerWins&"  |  ",robotoYellow),
        newSpan(computerPercent&"%",robotoYellow),
      ]

proc drawStats*(b:var Boxy) =
  if statsBatch.spansLength > 0:
    b.drawDynamicImage statsBatch

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
  echo "cashed cards reported:"
  for title in titles:
    if title notin result.mapIt it.title:
      result.add (title,titles.count title)
      echo title

proc readCashedCardsFrom(path:string):CashedCards =
  if fileExists path:
    echo "cashed cards on file:"
    for line in lines path:
      let lineSplit = line.split ':'
      try: 
        result.add (lineSplit[0],lineSplit[^1].strip.parseInt)
        echo result[^1]
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
  elif playerHandles[turnReport.playerBatch.color.ord].len > 0:
    playerHandles[turnReport.playerBatch.color.ord]
  else: "human"

proc newGameStats:GameStats = GameStats(
  turnCount:turnReport.turnNr,
  playerKinds:playerKinds,
  aliases:playerHandles,
  winner:winner,
  cash:cashToWin
)

proc updateStatsBatch* =
  statsBatch.setSpans statsBatchSpans()
  statsBatch.update = true

proc writeGameStatsTo(path:string) =
  writeFile(path,gameStats.toJson)

proc readGameStatsFrom(path:string) =
  if fileExists path:
    gameStats = readFile(path).fromJson seq[GameStats]

proc writeGamestats* =
  writeSquareVisitsTo visitsFile
  writeCashedCardsTo cashedFile
  if players.anyHuman and players.anyComputer:
    gameStats.add newGameStats()
    updateStatsBatch()
    writeGameStatsTo jsonStatsFile

reportBatches = initReportBatches()
readGameStatsFrom jsonStatsFile
updateStatsBatch()
