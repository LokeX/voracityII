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

proc initReportBatch:Batch = 
  newBatch BatchInit(
    kind:TextBatch,
    name:"aireport",
    pos:(rbx,rby),
    padding:(20,20,20,20),
    font:(reportFont,24,color(1,1,1)),
    border:(5,15,color(0,0,0)),
    blur:2,
    opacity:25,
    shadow:(10,1.75,color(255,255,255,100))
  )

let
  plainFont = setNewFont(reportFont,18,contrastColors[turnPlayer.color])

var
  reportBatches:ReportBatches
  selectedBatch*:int
  turnReports*:seq[TurnReport]
  turnReport*:TurnReport

proc initReportBatches:ReportBatches =
  for i,batch in reportBatches.enum_mitems:
    batch = initReportBatch()
    batch.commands: 
      batch.text.bgColor = playerColors[PlayerColor(i)]
      batch.border.color = contrastColors[PlayerColor(i)]
    result[PlayerColor(i)] = batch

proc reports*(playerColor:PlayerColor):seq[TurnReport] =
  turnReports.filterIt(it.playerBatch.color == playerColor)

proc echoTurnReport* =
  echo "\nTurn nr: ",turnReport.turnNr
  echo "Player: "&($turnReport.playerBatch)
  echo "Dice Rolls: "&($turnReport.diceRolls)
  echo "Moves: "&($turnReport.moves)
  echo "Kills: "&($turnReport.kills)
  echo "Cards:"
  echo "Drawn: "&turnReport.cards.drawn.mapIt(it.title).join ","
  echo "Cashed: "&turnReport.cards.cashed.mapIt(it.title).join ","
  echo "Discarded: "&turnReport.cards.discarded.mapIt(it.title).join ","

proc batchUpdate:seq[Span] =
  result.add newSpan("Turn nr: "&($turnReport.turnNr)&"\n",plainFont)
  result.add newSpan("Player: "&($turnReport.playerBatch)&"\n",plainFont)
  result.add newSpan("Dice Rolls:\n"&turnReport.diceRolls.mapIt($it).join("\n")&"\n",plainFont)
  result.add newSpan("Moves:\n"&turnReport.moves.mapIt($it).join("\n")&"\n",plainFont)
  result.add newSpan("Kills: "&($turnReport.kills)&"\n",plainFont)
  result.add newSpan("Cards:\n",plainFont)
  result.add newSpan("Drawn: "&turnReport.cards.drawn.mapIt(it.title).join(",")&"\n",plainFont)
  result.add newSpan("Cashed: "&turnReport.cards.cashed.mapIt(it.title).join(",")&"\n",plainFont)
  result.add newSpan("Discarded: "&turnReport.cards.discarded.mapIt(it.title).join(",")&"\n",plainFont)

proc initTurnReport* =
  turnReport = TurnReport()
  turnReport.turnNr = turnPlayer.turnNr+1
  turnReport.playerBatch.color = turnPlayer.color
  turnReport.playerBatch.kind = turnPlayer.kind
  reportBatches[turnPlayer.color].setSpans batchUpdate()
  reportBatches[turnPlayer.color].update = true

proc updateTurnReport*[T](item:T) =
  when typeOf(T) is Move: 
    turnReport.moves.add item
  when typeof(T) is Dice: 
    turnReport.diceRolls.add item
  when typeof(T) is PlayerColor: 
    turnReport.kills.add item
  reportBatches[turnPlayer.color].setSpans batchUpdate()
  reportBatches[turnPlayer.color].update = true

proc updateTurnReportCards*(blues:seq[BlueCard],playedCard:PlayedCard) =
  case playedCard
  of Drawn: turnReport.cards.drawn.add blues
  of Played: turnReport.cards.played.add blues
  of Cashed: turnReport.cards.cashed.add blues
  of Discarded: turnReport.cards.discarded.add blues
  reportBatches[turnPlayer.color].setSpans batchUpdate()
  reportBatches[turnPlayer.color].update = true

proc resetReports* =
  for batch in reportBatches.mitems:
    batch.setSpans @[]
  initTurnReport()
  turnReports.setLen 0
  selectedBatch = -1

proc recordTurnReport* =
  turnReports.add turnReport

proc startAnimation(batch:var Batch) =
  batch.setShallowPos(
    batch.rect.x.toInt,
    (batch.rect.y-batch.rect.h).toInt
  )

template gotReport*(player:PlayerColor):bool =
  reportBatches[player].spansLength > 0

proc animate(batch:var Batch) =
  # echo "anim"
  if batch.rect.y.toInt < rby:
    batch.setShallowPos(rbx,(batch.rect.y+30).toInt)
    batch.update = true
  elif batch.rect.y.toInt > rby:
    batch.setPos(rbx,rby)
    batch.update = true

proc drawReport*(b:var Boxy,playerBatch:PlayerColor) =
  echo "drawReport"
  if selectedBatch == -1 or playerBatch != PlayerColor(selectedBatch):
    selectedBatch = playerBatch.ord
    # echo "selectedBatch: ",selectedBatch
    reportBatches[playerBatch].startAnimation
  echo "got here"
  animate reportBatches[playerBatch]
  b.drawDynamicImage reportBatches[playerBatch]

reportBatches = initReportBatches()
