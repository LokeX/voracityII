import win except align,split,strip
import batch
import sequtils
import strutils
import game
import graphics
import misc
import play
import stat

type 
  KillMatrix = array[PlayerColor,array[PlayerColor,int]]
  ReportBatches* = array[PlayerColor,Batch]

const
  robotoRegular* = "fonts\\Roboto-Regular_1.ttf"
  killMatrixFont = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  reportFont = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  (rbx,rby) = (450,280)
  statsBatchInit = BatchInit(
    kind:TextBatch,
    name:"stats",
    pos:(460,530),
    padding:(15,75,8,15),
    border:(2,0,color(1,1,1)),
    font:(robotoRegular,20.0,color(1,1,1)),
    bgColor:color(0,0,0),
    opacity:25,
    shadow:(10,1.5,color(255,255,255,150))
  )

let
  plainFont = setNewFont(reportFont,18,color(1,1,1,1))
  matrixFont = setNewFont(killMatrixFont,size = 16.0)
  roboto = setNewFont(robotoRegular,size = 15.0)

var
  statsBatch = newBatch statsBatchInit
  reportBatches*:ReportBatches
  selectedBatch*:int

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
  killMatrixPainter* = DynamicImage[void](
    name:"killMatrix",
    rect:Rect(x:250+bx,y:250+by),
    updateImage:paintKillMatrix,
    update:true
  )

proc killMatrixUpdate* =
  killMatrixPainter.update = true

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

proc initReportBatches*:ReportBatches =
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

proc initReportBatchesTurn* =
  turnReport.playerBatch.color = turnPlayer.color
  turnReport.playerBatch.kind = turnPlayer.kind
  reportBatches[turnPlayer.color].setSpans reportSpansFrom turnReport
  reportBatches[turnPlayer.color].update = true

proc writeTurnReportUpdate* =
  reportBatches[turnPlayer.color].setSpans reportSpansFrom turnReport
  if turnPlayer.cash >= cashToWin:
    writeEndOfGameReports()
  reportBatches[turnPlayer.color].update = true

template gotReport*(player:PlayerColor):bool =
  reportBatches[player].spansLength > 0

proc drawReport*(b:var Boxy,playerColor:PlayerColor) =
  if selectedBatch == -1 or playerColor != PlayerColor(selectedBatch):
    selectedBatch = playerColor.ord
    reportBatches[playerColor].dynMove(Down,15)
    reportBatches[playerColor].update = true
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

proc statsBatchSpans:seq[Span] =
  if gameStats.len > 0:
    let stats = getMatchingStats()
    if stats.hasData:
      echo "stats has data"
      result = @[
        newSpan("Statistics ",robotoGreen),
        newSpan(if mouseOn statsBatch: "  -   click to reset\n" else: "\n",robotoWhite),
        newSpan("\n",robotolh7),
        newSpan("Games: ",robotoPurple),
        newSpan($(stats.games),robotoYellow),
        newSpan("  |  Turns: ",robotoPurple),
        newSpan($stats.turns,robotoYellow),
        newSpan("  |  Avg turns: ",robotoPurple),
        newSpan($stats.avgTurns&"\n",robotoYellow),
        newSpan(stats.handle&" wins: ",robotoPurple),
        newSpan($stats.humanWins,robotoYellow),
        newSpan("  |  ",robotoPurple),
        newSpan(stats.humanPercent&"%\n",robotoYellow),
        newSpan("Computer wins: ",robotoPurple),
        newSpan($stats.computerWins,robotoYellow),
        newSpan("  |  ",robotoPurple),
        newSpan(stats.computerPercent&"%",robotoYellow),
      ]

proc updateStatsBatch* =
  statsBatch.setSpans statsBatchSpans()
  statsBatch.update = true

template statsBatchVisible*:untyped =
  statsBatch.spansLength > 0
  
proc drawStats*(b:var Boxy) =
  if statsBatch.spansLength > 0:
    let (mouseOver,spanEmpty) = (mouseOn(statsBatch),statsBatch.getSpanText(1).len == 1)
    if (mouseOver and spanEmpty) or (not mouseOver and not spanEmpty):
      statsBatch.setSpanText(if mouseOn statsBatch: "  -   click to reset\n" else: "\n",1)
      statsBatch.update = true
    b.drawDynamicImage statsBatch

template mouseOnStatsBatch*:bool =
  mouseOn statsBatch

