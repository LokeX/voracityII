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
import os

const
  showVolTime = 2.4
  settingsFile = "dat\\settings.cfg"
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

type
  Pinned = enum None,Discard,Deck

var 
  batchInputNr = -1
  mouseOnBatchPlayerNr = -1
  pinnedBatchNr = -1
  altPressed:bool
  pinnedCards:Pinned
  reveal:bool
  frames:float
  vol = 0.05
  showVolume:float
  showPanel = true

proc paintKeybar:Image =
  let 
    ctx = newImage(1200,30).newContext
    white = setNewFont(logoFontPath,18,color(1,1,1))
    yellow = setNewFont(logoFontPath,18,color(1,1,0))
    green = setNewFont(logoFontPath,18,color(0,1,0))
  ctx.image.fill color(0,0,0)
  let spans = [
    newSpan("Keys:  ",green),
    newSpan("P",yellow),
    newSpan("anel (this):  ",white),
    newSpan("on",(if showPanel: yellow else: white)),
    newSpan("/",white),
    newSpan("off",(if showPanel: white else: yellow)),
    newSpan("  |  ",green),
    newSpan("S",yellow),
    newSpan("ound:  ",white),
    newSpan("on",(if volume() == 0: white else: yellow)),
    newSpan("/",white),
    newSpan("off",(if volume() == 0: yellow else: white)),
    newSpan("  |  ",green),
    newSpan("A",yellow),
    newSpan("uto end turn (Computer):  ",white),
    newSpan("on",(if autoEndTurn: yellow else: white)),
    newSpan("/",white),
    newSpan("off",(if autoEndTurn: white else: yellow)),
    newSpan("  |  ",green),
    newSpan("+/- ",yellow),
    newSpan("(NumPad):  Adjust volume",white),
    newSpan("  |  ",green),
    newSpan("Right-click-mouse:  ",yellow),
    newSpan((
      if turn.nr == 0: 
        "Start Game" 
      elif not showMenu:
        "Show Menu"
      elif turnPlayer.cash >= cashToWin: 
        "New Game"
      else: "End Turn"
    ),white),
  ]
  ctx.image.fillText(spans.typeset(vec2(1150,20)),translate vec2(10,2))
  ctx.image

let keybarPainter = DynamicImage[void](
  name:"keybar",
  updateImage:paintKeybar,
  area:(225,935,0,0),
  update:true
)

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

proc paintVolume:Image =
  var ctx = newImage(110,20).newContext
  ctx.image.fill color(255,255,255)
  ctx.fillStyle = color(1,1,1)
  ctx.fillRect(5,5,vol*100,10)
  ctx.image

template mouseOnBatchColor:untyped = players[mouseOnBatchPlayerNr].color

template selectedBatchColor:untyped =
  if mouseOnBatchPlayerNr != -1: players[mouseOnBatchPlayerNr].color
  else: players[pinnedBatchNr].color

template batchSelected:untyped =
  mouseOnBatchPlayerNr != -1 or pinnedBatchNr != -1

proc cashedCards:seq[BlueCard] =
  result.add selectedBatchColor.reports.mapIt(it.cards.cashed).flatMap
  if selectedBatchColor == turnPlayer.color:
    result.add turnReport.cards.cashed

proc reportAnimationMoves:seq[AnimationMove] =
  if selectedBatchColor == turnPlayer.color:
    result.add turnReport.moves.mapIt (it.fromSquare,it.toSquare)
  else: result.add selectedBatchColor
    .reports[^1].moves
    .mapIt (it.fromSquare,it.toSquare)

template drawSelectedPlayersHand:untyped =
  altPressed and pinnedBatchNr == -1 and turnPlayer.cash >= cashToWin

proc paintCardsHeader(b:var Boxy,color:PlayerColor,header:string) =
  if header != cardsHeader.getSpanText 0:
    cardsHeader.commands:
      cardsHeader.border.color = playerColors[color]
    cardsHeader.setSpanText header,0
    cardsHeader.update = true
  b.drawDynamicImage cardsHeader

proc showCards(b:var Boxy) =
  var
    cards:seq[BlueCard]
    show:Reveal = Front
    header = ""
    color = Black
  if turn.nr == 0:
    if pinnedCards == Deck or mouseOn blueDeck.drawSlot.area:
      cards = blueDeck.fullDeck
      header = "Full deck"
  elif pinnedCards == Discard or mouseOn blueDeck.discardSlot.area:
    cards = blueDeck.discardPile
    header = "Discard pile"
  elif batchSelected and selectedBatchColor.reports.len > 0:
    if drawSelectedPlayersHand:
      cards = players[mouseOnBatchPlayerNr].hand
      color = players[mouseOnBatchPlayerNr].color
      header = $color&" player's hand"
    else: 
      cards = cashedCards()
      color = players[max(mouseOnBatchPlayerNr,pinnedBatchNr)].color
      header = $color&"player's cashed cards"
  else: 
    cards = turnPlayer.hand
    show = if turnPlayer.kind == Human or reveal: Front else: Back
    color = turnPlayer.color
    header = $color&" player's hand"
  b.paintCards(blueDeck,cards,show)
  if header.len > 0:
    b.paintCardsHeader(color,header)

template showFooter:untyped =
  mouseOnBatchPlayerNr != -1 or 
  pinnedBatchNr != -1 or 
  pinnedCards == Discard or 
  mouseOn(blueDeck.discardSlot.area) or
  pinnedCards == Deck or
  (mouseOn(blueDeck.drawSlot.area) and turn.nr == 0)

template clickToPin:untyped =
  (mouseOnBatchPlayerNr != -1 or 
  mouseOn(blueDeck.discardSlot.area) or 
  mouseOn(blueDeck.drawSlot.area)) and 
  (pinnedBatchNr == -1 and pinnedCards == None)

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
  if showPanel: 
    if updateKeybar:
      keybarPainter.update = true
      updateKeybar = false
    b.drawDynamicImage keybarPainter
  if showMenu: b.drawDynamicImage mainMenu
  if batchInputNr != -1: b.drawBatch inputBatch
  if showVolume > 0: b.drawImage("volume",vec2(750,15))
  if turn.nr > 0:
    if mouseOn squares[0].dims.area: b.drawKillMatrix
    b.doMoveAnimation
    b.drawCursor
    b.drawCardsFooter
    if not turn.diceMoved or turnPlayer.kind == Computer: b.drawDice
    if not isRollingDice() and turnPlayer.kind == Human: b.drawSquares
    if turnPlayer.kind == Human and turn.undrawnBlues > 0: 
      b.drawDynamicImage nrOfUndrawnBluesPainter
    if mouseOnBatchPlayerNr != -1 and gotReport mouseOnBatchColor:
      b.drawReport mouseOnBatchColor
  elif pinnedCards != Deck and not mouseOn blueDeck.drawSlot.area: 
    b.drawImage("logo",vec2(1475,60))
    b.drawImage("advicetext",vec2(1525,450))
    b.drawImage("barman",Rect(x:1545,y:530,w:220,h:275))
  else:
    b.drawCardsFooter
  b.showCards

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
  if m.leftMousePressed or m.rightMousePressed:
    if mouseOn blueDeck.discardSlot.area: 
      pinnedCards = Discard
    elif turn.nr == 0 and mouseOn blueDeck.drawSlot.area: 
      pinnedCards = Deck
    else: pinnedCards = None
  if m.leftMousePressed:
    if turn.nr == 0: togglePlayerKind()
    if showMenu and mouseOnMenuSelection():
      menuSelection()
    elif turnPlayer.kind == Human:
      m.leftMouse
      if turn.nr > 0 and mouseOnDice() and mayReroll(): 
        startDiceRoll humanRoll
  elif m.rightMousePressed and batchInputNr == -1: 
    if turn.nr > 0 and turnPlayer.kind == Computer: 
      m.aiRightMouse
    else:
      m.rightMouse
    keybarPainter.update = true

proc mouseMoved = 
  # moveSelection.hoverSquare = mouseOnSquare()
  let batchNr = mouseOnPlayerBatchNr()
  if altPressed: 
    if batchNr != -1: mouseOnBatchPlayerNr = batchNr
  else: mouseOnBatchPlayerNr = batchNr
  if showMenu and mouseOn mainMenu.area:
    mainMenu.mouseSelect

proc keyboard (key:KeyboardEvent) =
  altPressed = key.pressed.alt
  if batchInputNr != -1: key.batchKeyb inputBatch
  if key.keyPressed: 
    case key.button
    of NumpadAdd,NumpadSubtract:
      vol += (
        if key.button.isKey NumpadAdd: 
          if vol < 0.95: 0.05 else: 0
        elif vol <= 0.05: 0 else: -0.05
      )
      setVolume vol
      removeImg("volume")
      addImage("volume",paintVolume())
      showVolume = showVolTime
    of KeyEnter:
      if batchInputNr != -1: 
        if inputBatch.input.len > 0:
          playerKinds[batchInputNr] = Human
        playerHandles[batchInputNr] = inputBatch.input
        updateBatch batchInputNr
        batchInputNr = -1
        inputBatch.deleteInput
        updateStatsBatch()
    of KeyA: 
      keybarPainter.update = true
      autoEndTurn = not autoEndTurn
    of KeyP: showPanel = not showPanel
    of KeyR: reveal = not reveal
    of KeyS:
      keybarPainter.update = true
      if volume() == 0:
        setVolume vol
      else: setVolume 0
    else:discard
  if key.button == ButtonUnknown and not isRollingDice():
    editDiceRoll key.rune.toUTF8

proc cycle = 
  if bgRect.w < scaledWidth.toFloat:
    if bgRect.w+90 < scaledWidth.toFloat:
      bgRect.w += 90
    else: 
      bgRect.w = scaledWidth.toFloat
      oldBg = -1
  if turnPlayer.kind == Computer and not moveAnimationActive() and aiTurn():
    aiTakeTurn()

proc timer = 
  if showVolume > 0: showVolume -= 0.4
  showCursor = not showCursor
  if turnPlayer.kind == Human and turnReport.diceRolls.len < diceRolls.len:
    updateTurnReport diceRolls[^1]
  if turn.nr > 0 and not moveAnimation.active and mouseOnBatchPlayerNr != -1:
    if mouseOnBatchColor.gotReport:
      if (let moves = reportAnimationMoves(); moves.len > 0):
          startMovesAnimations(mouseOnBatchColor,moves)
  # echo frames*2.5
  frames = 0

proc settingsToFile =
  let f = open(settingsFile,fmWrite)
  f.writeIt autoEndTurn
  f.writeIt reveal
  f.writeIt vol
  f.writeIt showPanel
  f.close

proc settingsFromFile =
  let f = open(settingsFile,fmRead)
  f.readIt autoEndTurn
  f.readIt reveal
  f.readIt vol
  f.readIt showPanel
  f.close

proc quitVoracity =
  playerKindsToFile playerKinds
  playerHandlesToFile playerHandles
  settingsToFile()
  closeSound()

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
addImage("volume",paintVolume())
# addImage("keybar",paintKeybar())
randomize()
# vol = 0.05
if fileExists(settingsFile): 
  settingsFromFile()
else: settingsToFile()
setVolume vol
addCall call
addCall dialogCall # we add dialog second - or it will be drawn beneath the board
window.onCloseRequest = quitVoracity
window.icon = readImage "pics\\BarMan.png"
runWinWith: 
  callCycles()
  callTimers()
