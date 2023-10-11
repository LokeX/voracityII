import win
import batch
import colors
import sequtils
import game

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
    border:(0,15,color(0,0,0)),
    blur:2,
    opacity:25,
    shadow:(10,1.75,color(255,255,255,100))
  )

var
  reportBatch = initReportBatch()
  playerReports:array[PlayerColor,seq[Span]]
  currentPlayerReport:PlayerColor
  turnReport*:seq[string]

proc gotReport*(player:PlayerColor):bool = playerReports[player].len > 0

proc playerReport:seq[Span] = 
  let aiFont = setNewFont(reportFont,18,contrastColors[turnPlayer.color])
  result = turnReport.mapIt newSpan(it&"\n",aiFont)

proc setCurrentReportTo(player:PlayerColor) =
  reportBatch.commands: 
    reportBatch.text.bgColor = playerColors[player]
  reportBatch.setSpans playerReports[player]
  currentPlayerReport = player
  reportBatch.update = true

proc recordPlayerReport* =
  playerReports[turnPlayer.color] = playerReport()

proc drawReport*(b:var Boxy,player:PlayerColor) =
  if player != currentPlayerReport:
    setCurrentReportTo player
  b.drawDynamicImage reportBatch
