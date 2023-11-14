import win
import deck
import game
import play
import board
import times
import megasound
import dialog
import ai
import menu
import batch
import sugar
import reports
import sequtils
import misc
import random
import eval
import strutils
import colors

const
  logoFontPath = "fonts\\IBMPlexSansCondensed-SemiBold.ttf"
  logoText = [
    "Created by",
    "Sebastian Tue Øltieng",
    "Per Ulrik Bøge Nielsen",
    "",
    "Coded by",
    "Per Ulrik Bøge Nielsen",
    "",
    "All rights reserved (1998 - 2023)",
  ]
  adviceText = [
    "The way is long, dark and lonely",
    "Let perseverance light your path"
  ]
  headerInit = BatchInit(
    kind:TextBatch,
    name:"header",
    pos:(1560,5),
    entries: @[""],
    font:(logoFontPath,18.0,color(1,1,1)),
    hAlign:CenterAlign,
    fixedBounds:(300,25),
    bgColor:color(0,0,0),
    opacity:25,
    border:(5,10,color(1,1,1)),
  )
  footerInit = BatchInit(
    kind:TextBatch,
    name:"footer",
    pos:(1560,930),
    entries: @[""],
    font:(logoFontPath,18.0,color(1,1,1)),
    hAlign:CenterAlign,
    fixedBounds:(300,25),
    bgColor:color(0,0,0),
    opacity:25,
    border:(5,10,color(1,1,1)),
  )

let
  voracityLogo = readImage "pics\\voracity.png"
  lets_rockLogo = readImage "pics\\lets_rock.png"
  barMan = readImage "pics\\barman.jpg"
  logoFont = setNewFont(logoFontPath,size = 16.0,color(1,1,1))
  cardsHeader = newBatch headerInit
  cardsFooter = newBatch footerInit

var 
  batchInputNr = -1
  mouseOnBatchPlayerNr = -1
  pinnedBatchNr = -1
  discardPinned,mouseOnDiscard:bool
  frames:float

proc paintSubText:Image =
  var 
    spans:seq[Span]
    logoFontYellow = logoFont.copy
    logoFontBlack = logoFont.copy
  logoFontYellow.paint = color(1,1,0)
  logoFontBlack.paint = color(0,0,0)
  spans.add newSpan(adviceText[0]&"\n",logoFontBlack)
  spans.add newSpan(adviceText[1],logoFontYellow)
  let 
    arrangement = spans.typeset(
      bounds = vec2(250,100),
      hAlign = CenterAlign
    )
  result = newImage(250,100)
  result.fillText(arrangement,translate vec2(0,0))

proc logoTextArrangement(width,height:float):Arrangement =
  logoFont.lineHeight = 22
  logoFont.typeset(
    logoText.join("\n"),
    bounds = vec2(width,height),
    hAlign = CenterAlign
  )

proc paintLogo:Image =
  result = newImage(350,400)
  var ctx = result.newContext
  ctx.drawImage(voracityLogo,vec2(0,0))
  ctx.drawImage(lets_rockLogo,vec2(50,70))
  ctx.image.fillText(logoTextArrangement(350,200),translate vec2(0,150))

proc paintBarman:Image =
  let 
    (w,h) = (barMan.width,barMan.height)
    shadow = 5
  result = newImage(w+shadow,h+shadow)
  var ctx = result.newContext
  ctx.fillStyle = color(0,0,0,100)
  ctx.fillRect(Rect(x:shadow.toFloat,y:shadow.toFloat,w:w.toFloat,h:h.toFloat))
  ctx.image.blur 2
  ctx.drawImage(barman,vec2(0,0))
  ctx.image.applyOpacity 25

template mouseOnBatchColor:untyped = players[mouseOnBatchPlayerNr].color

template selectedBatchColor:untyped =
  if mouseOnBatchPlayerNr != -1: players[mouseOnBatchPlayerNr].color
  else: players[pinnedBatchNr].color

template batchSelected:untyped =
  mouseOnBatchPlayerNr != -1 or pinnedBatchNr != -1

proc cashedCards:seq[BlueCard] =
  result.add selectedBatchColor.reports.mapIt(it.cards.cashed).flatMap
  if turnPlayer.kind == Human and selectedBatchColor == turnPlayer.color:
    result.add turnReport.cards.cashed

proc reportAnimationMoves:seq[AnimationMove] =
  if selectedBatchColor == turnPlayer.color:
    result.add turnReport.moves.mapIt (it.fromSquare,it.toSquare)
  else: result.add selectedBatchColor
    .reports[^1].moves
    .mapIt (it.fromSquare,it.toSquare)

proc drawCards(b:var Boxy) =
  if batchSelected and selectedBatchColor.reports.len > 0:
    let storedRevealSetting = blueDeck.reveal
    blueDeck.reveal = Front
    b.paintCards blueDeck,cashedCards()
    blueDeck.reveal = storedRevealSetting   
  else: b.paintCards blueDeck,turnPlayer.hand

proc setRevealCards(deck:var Deck,playerKind:PlayerKind) =
  if deck.reveal != UserSetFront: 
    if playerKind == Computer:
      deck.reveal = Back
    else: deck.reveal = Front

template cardsHeaderColorAndText:untyped =
  if blueDeck.show == Hand:
    if mouseOnBatchPlayerNr > -1 or pinnedBatchNr > -1:
      (players[max(mouseOnBatchPlayerNr,pinnedBatchNr)].color,"player's cashed cards")
    else: (turnPlayer.color," player's hand")
  else: (Black,"Discard pile")

proc drawCardsHeader(b:var Boxy) =
  let 
    (color,text) = cardsHeaderColorAndText
    txt = if text == "Discard pile": text else: $color&text
  if txt != cardsHeader.getSpanText 0:
    cardsHeader.commands:
      cardsHeader.border.color = playerColors[color]
    cardsHeader.setSpanText txt,0
    cardsHeader.update = true
  b.drawDynamicImage cardsHeader

template showFooter:untyped =
  mouseOnBatchPlayerNr != -1 or 
  pinnedBatchNr != -1 or 
  discardPinned or 
  mouseOnDiscard

template clickToPin:untyped =
  (mouseOnBatchPlayerNr != -1 or mouseOnDiscard) and 
  (pinnedBatchNr == -1 and not discardPinned)

proc drawCardsFooter(b:var Boxy) =
  if showFooter:
    let txt = if clickToPin: "Click to pin" else: "Click to unpin"
    if txt != cardsFooter.getSpanText 0:
      let (fColor,bColor) = if txt.endsWith "unpin": 
        (contrastColors[Red],playerColors[Red])
      else: (contrastColors[Green],playerColors[Green]) 
      cardsFooter.commands:
        cardsFooter.text.bgColor = bColor
        cardsFooter.border.color = bColor
        cardsFooter.text.spans[0].font.paint = fColor
      cardsFooter.setSpanText txt,0
      cardsFooter.update = true
    b.drawDynamicImage cardsFooter

proc draw(b:var Boxy) =
  frames += 1
  if oldBg != -1: b.drawImage backgrounds[oldBg].name,oldBgRect
  b.drawImage backgrounds[bgSelected].name,bgRect
  b.drawBoard
  b.drawDynamicImage piecesImg
  b.drawPlayerBatches
  b.drawStats
  if showMenu: b.drawDynamicImage mainMenu
  if batchInputNr != -1: b.drawBatch inputBatch
  if turn.nr > 0:
    if mouseOn squares[0].dims.area: b.drawKillMatrix
    b.doMoveAnimation
    b.drawCards
    b.drawCursor
    b.drawCardsHeader
    b.drawCardsFooter
    if not turn.diceMoved or turnPlayer.kind == Computer: b.drawDice
    if not isRollingDice() and turnPlayer.kind == Human: b.drawSquares
    if turnPlayer.kind == Human and turn.undrawnBlues > 0: 
      b.drawDynamicImage nrOfUndrawnBluesPainter
    if mouseOnBatchPlayerNr != -1 and gotReport mouseOnBatchColor:
      b.drawReport mouseOnBatchColor
  else: 
    b.drawImage("logo",vec2(1475,60))
    b.drawImage("advicetext",vec2(1525,450))
    b.drawImage("barman",Rect(x:1545,y:530,w:220,h:275))

proc really(title:string,answer:string -> void) =
  let entries = @[
    "Really "&title&"\n",
    "\n",
    "Yes\n",
    "No",
  ]
  showMenu = false
  startDialog(entries,2..3,answer)

proc confirmQuit = really("quit Voracity?",
  (answer:string) => (if answer == "Yes": window.closeRequested = true)
)

proc confirmEndGame = really("end this game?",
  (answer:string) => (if answer == "Yes": setupNewGame())
)

proc menuSelection =
  if mouseOnMenuSelection("Quit Voracity"):
    confirmQuit()
  elif mouseOnMenuSelection("Start Game") or mouseOnMenuSelection("End Turn"):
    nextGameState()
  elif mouseOnMenuSelection("New Game"):
    if turnPlayer.cash >= cashToWin:
      setupNewGame()
    else: confirmEndGame()

proc mouse(m:KeyEvent) =
  if mouseOnBatchPlayerNr != -1:
    if turn.nr > 0: pinnedBatchNr = mouseOnBatchPlayerNr
  else: 
    pinnedBatchNr = -1
    batchInputNr = -1
    inputBatch.deleteInput
  if m.rightMousePressed and turn.nr == 0 and mouseOnBatchPlayerNr != -1:
    batchInputNr = mouseOnBatchPlayerNr
  if m.leftMousePressed:
    discardPinned = not discardPinned and mouseOn blueDeck.discardSlot.area
    if turn.nr == 0: togglePlayerKind()
    if showMenu and mouseOnMenuSelection():
      menuSelection()
    elif turnPlayer.kind == Human:
      m.leftMouse()
      if turn.nr > 0 and mouseOnDice() and mayReroll(): 
        startDiceRoll(humanRoll)
  elif m.rightMousePressed and batchInputNr == -1: 
    if turn.nr > 0 and turnPlayer.kind == Computer: 
      m.aiRightMouse
    else:
      m.rightMouse

proc mouseMoved = 
  mouseOnDiscard = mouseOn blueDeck.discardSlot.area
  if discardPinned or mouseOnDiscard: 
    blueDeck.show = Discard
  else: blueDeck.show = Hand
  mouseOnBatchPlayerNr = mouseOnPlayerBatchNr()
  if showMenu and mouseOn mainMenu.area:
    mainMenu.mouseSelect

proc keyboard (key:KeyboardEvent) =
  if batchInputNr != -1: key.batchKeyb inputBatch
  if key.keyPressed: 
    case key.button
    of KeyEnter:
      if batchInputNr != -1: 
        if inputBatch.input.len > 0:
          playerKinds[batchInputNr] = Human
        playerHandles[batchInputNr] = inputBatch.input
        updateBatch batchInputNr
        batchInputNr = -1
        inputBatch.deleteInput
        updateStatsBatch()
    of KeyE: autoEndTurn = not autoEndTurn
    of KeyR: 
      case blueDeck.reveal
      of UserSetFront: blueDeck.reveal = Back
      of Back,Front: blueDeck.reveal = UserSetFront
    of KeyS:
      if volume() == 0:
        setVolume 0.05
      else: setVolume 0
    else:discard
  if key.button == ButtonUnknown and not isRollingDice():
    editDiceRoll key.rune.toUTF8

proc cycle = 
  blueDeck.setRevealCards turnPlayer.kind
  if bgRect.w < scaledWidth.toFloat:
    if bgRect.w+90 < scaledWidth.toFloat:
      bgRect.w += 90
    else: 
      bgRect.w = scaledWidth.toFloat
      oldBg = -1
  if turnPlayer.kind == Computer and not moveAnimationActive() and aiTurn():
    aiTakeTurn()

proc timer = 
  showCursor = not showCursor
  if turnPlayer.kind == Human and turnReport.diceRolls.len < diceRolls.len:
    updateTurnReport diceRolls[^1]
  if turn.nr > 0 and not moveAnimation.active and mouseOnBatchPlayerNr != -1:
    if mouseOnBatchColor.gotReport:
      if (let moves = reportAnimationMoves(); moves.len > 0):
          startMovesAnimations(mouseOnBatchColor,moves)
  # echo frames*2.5
  frames = 0

proc quitVoracity =
  playerKindsToFile playerKinds
  playerHandlesToFile playerHandles

proc timerCall:TimerCall =
  TimerCall(call:timer,lastTime:cpuTime(),secs:0.4)

var
  call = Call(
    reciever:"voracity",
    draw:draw,
    mouse:mouse,
    mouseMoved:mouseMoved,
    keyboard:keyboard,
    cycle:cycle,
    timer:timerCall()
  )

addImage("logo",paintLogo())
addImage("barman",paintBarman())
addImage("advicetext",paintSubText())
randomize()
setVolume 0.05
addCall call
addCall dialogCall # we add dialog second - or it will be drawn beneath the board
window.onCloseRequest = quitVoracity
window.icon = readImage "pics\\BarMan.png"
runWinWith: 
  callCycles()
  callTimers()
