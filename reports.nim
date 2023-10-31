import win
import batch
import colors
import sequtils
import strutils
import game
import deck
import board
import eval
import misc

type 
  PlayedCard* = enum Drawn,Played,Cashed,Discarded
  ReportBatches = array[PlayerColor,Batch]
  TurnReport* = object
    turnNr*:int
    playerBatch*:tuple[color:PlayerColor,kind:PlayerKind]
    diceRolls*:seq[Dice]
    moves*:seq[Move]
    cards*:tuple[drawn,played,cashed,discarded:seq[BlueCard]]
    kills*:seq[PlayerColor]

const
  reportFont = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  (rbx,rby) = (450,280)

let
  plainFont = setNewFont(reportFont,18,contrastColors[turnPlayer.color])

var
  reportBatches:ReportBatches
  selectedBatch*:int
  turnReports*:seq[TurnReport]
  turnReport*:TurnReport

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

proc reportLines(report:TurnReport):seq[string] = 
  result.add @[
    "Turn nr: "&($report.turnNr),
    "Player: "&($report.playerBatch),
    "Dice Rolls:\n"&report.diceRolls.mapIt($it).join("\n"),
    "Moves:\n"&report.moves.mapIt($it).join("\n"),
    "Kills: "&($report.kills),
  ]
  if turnPlayer.cash >= cashToWin:
    result.add @[
      "Hand: "&turnPlayer.hand.mapIt(it.title).join(","),
      "Drawn: "&report.cards.drawn.mapIt(it.title).join(","),
    ]
  result.add @[
    "Played: "&report.cards.played.mapIt(it.title).join(","),
    "Cashed: "&report.cards.cashed.mapIt(it.title).join(","),
    "Discarded: "&report.cards.discarded.mapIt(it.title).join(","),
  ]

proc echoTurnReport* =
  for line in reportLines turnReport: echo line

proc batchUpdate(turnReport:TurnReport):seq[Span] =
  for line in reportLines turnReport:
    result.add newSpan(line&"\n",plainFont)

proc writeEndOfGameReports* =
  for i,batch in reportBatches:
    if turnPlayer.color != PlayerColor(i):
      batch.setSpans batchUpdate turnReports
        .filterIt(it.playerBatch.color == PlayerColor(i))[^1]

proc initTurnReport* =
  turnReport = TurnReport()
  turnReport.turnNr = turnPlayer.turnNr+1
  turnReport.playerBatch.color = turnPlayer.color
  turnReport.playerBatch.kind = turnPlayer.kind
  reportBatches[turnPlayer.color].setSpans batchUpdate turnReport
  reportBatches[turnPlayer.color].update = true

proc updateTurnReport*[T](item:T) =
  when typeOf(T) is Move: 
    turnReport.moves.add item
  when typeof(T) is Dice: 
    turnReport.diceRolls.add item
  when typeof(T) is PlayerColor: 
    turnReport.kills.add item
  reportBatches[turnPlayer.color].setSpans batchUpdate turnReport
  if turnPlayer.cash >= cashToWin:
    writeEndOfGameReports()
  reportBatches[turnPlayer.color].update = true

proc updateTurnReportCards*(blues:seq[BlueCard],playedCard:PlayedCard) =
  case playedCard
  of Drawn: turnReport.cards.drawn.add blues
  of Played: turnReport.cards.played.add blues
  of Cashed: turnReport.cards.cashed.add blues
  of Discarded: turnReport.cards.discarded.add blues
  reportBatches[turnPlayer.color].setSpans batchUpdate turnReport
  if turnPlayer.cash >= cashToWin:
    writeEndOfGameReports()
  reportBatches[turnPlayer.color].update = true

proc resetReports* =
  writeFile("test.txt",turnReports.mapIt($it).join "\n")
  for batch in reportBatches.mitems:
    batch.setSpans @[]
  initTurnReport()
  turnReports.setLen 0
  selectedBatch = -1

proc recordTurnReport* =
  turnReports.add turnReport

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

proc drawReport*(b:var Boxy,playerBatch:PlayerColor) =
  echo "draw report: "&($playerBatch)&" player"
  if selectedBatch == -1 or playerBatch != PlayerColor(selectedBatch):
    echo "start report animation"
    selectedBatch = playerBatch.ord
    reportBatches[playerBatch].startAnimation
  animate reportBatches[playerBatch]
  echo "done animation"
  b.drawDynamicImage reportBatches[playerBatch]
  echo "end report"

reportBatches = initReportBatches()
