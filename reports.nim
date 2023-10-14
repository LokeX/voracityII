import win
import batch
import colors
import sequtils
import strutils
import game
import deck
import board
import eval

type 
  TurnReport* = object
    turnNr*:int
    player*:tuple[color:PlayerColor,kind:PlayerKind]
    diceRolls*:seq[Dice]
    moves*:seq[Move]
    cards*:tuple[drawn,cashed,discarded:seq[BlueCard]]
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

var
  reportBatch = initReportBatch()
  playerReports:array[PlayerColor,seq[Span]]
  currentPlayerReport*:PlayerColor
  turnReports*:seq[TurnReport]
  turnReport*:TurnReport

proc echoTurnReport* =
  echo "\nTurn nr: ",turnReport.turnNr
  echo "Player: "&($turnReport.player)
  echo "Dice Rolls: "&($turnReport.diceRolls)
  echo "Moves: "&($turnReport.moves)
  echo "Kills: "&($turnReport.kills)
  echo "Cards:"
  echo "  Drawn: "&turnReport.cards.drawn.mapIt(it.title).join ","
  echo "  Cashed: "&turnReport.cards.cashed.mapIt(it.title).join ","
  echo "  Discarded: "&turnReport.cards.discarded.mapIt(it.title).join ","

proc playerReport:seq[Span] =
  let font = setNewFont(reportFont,18,contrastColors[turnPlayer.color])
  result.add newSpan("Turn report:\n",font)
  result.add newSpan("Turn nr: "&($turnReport.turnNr)&"\n",font)
  result.add newSpan("Player: "&($turnReport.player)&"\n",font)
  result.add newSpan("Dice Rolls:\n"&turnReport.diceRolls.mapIt($it).join("\n")&"\n",font)
  result.add newSpan("Moves:\n"&turnReport.moves.mapIt($it).join("\n")&"\n",font)
  result.add newSpan("Kills: "&($turnReport.kills)&"\n",font)
  result.add newSpan("Cards:\n",font)
  result.add newSpan("Drawn: "&turnReport.cards.drawn.mapIt(it.title).join(",")&"\n",font)
  result.add newSpan("Cashed: "&turnReport.cards.cashed.mapIt(it.title).join(",")&"\n",font)
  result.add newSpan("Discarded: "&turnReport.cards.discarded.mapIt(it.title).join(",")&"\n",font)

proc initTurnReport* =
  turnReport = TurnReport()
  turnReport.turnNr = turnPlayer.turnNr+1
  turnReport.player.color = turnPlayer.color
  turnReport.player.kind = turnPlayer.kind

proc resetTurnReports* =
  initTurnReport()
  turnReports.setLen 0

proc gotReport*(player:PlayerColor):bool = playerReports[player].len > 0

proc setCurrentReportTo(player:PlayerColor) =
  reportBatch.commands: 
    reportBatch.text.bgColor = playerColors[player]
    reportBatch.border.color = contrastColors[player]
  reportBatch.setSpans playerReports[player]
  reportBatch.setShallowPos(
    reportBatch.rect.x.toInt,
    (reportBatch.rect.y-reportBatch.rect.h).toInt
  )
  currentPlayerReport = player
  reportBatch.update = true

proc recordPlayerReport* =
  turnReports.add turnReport
  # echo "saved "&($turnReports[^1].player.color)&" player report"
  playerReports[turnPlayer.color] = playerReport()
  setCurrentReportTo turnPlayer.color

proc drawReport*(b:var Boxy,player:PlayerColor) =
  if player != currentPlayerReport:
    setCurrentReportTo player
  if reportBatch.rect.y.toInt < rby:
    reportBatch.setShallowPos(rbx,(reportBatch.rect.y+30).toInt)
  elif reportBatch.rect.y.toInt > rby:
    reportBatch.setPos(rbx,rby)
  b.drawDynamicImage reportBatch
