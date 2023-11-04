import win
import sequtils
import times
import strutils except strip
 
type
  BatchKind* = enum TextBatch,MenuBatch,InputBatch
  Batch* = ref object of DynamicImage[Batch]
    case kind*:BatchKind
    of MenuBatch:selector:Select
    of InputBatch:input:Input
    else:discard
    title:Title
    pos:tuple[x,y:int]
    font:Font
    text:Text
    opacity:float = 1
    blur:float
    background:Image
    border:Border
    padding:tuple[left,right,top,bottom:int]
    shadow:tuple[size:int,offSetFactor:float,color:Color]
    fixedBounds:tuple[width,height:int]
    centerOnWin:bool
  Border* = tuple[size:int,angle:float,color:Color]
  Line = tuple[color,bgColor:Color,border:Border]
  Title = tuple[on:bool,line:Line]
  Cursor = tuple[blinkPrSec:float,color:Color]
  Input = tuple
    ctx:Context
    lastBlinkTime:float
    showCursor,forceCursor:bool
    maxChars:int
    numbers:HSlice[int,int]
    alphaOnly:bool
    cursor:Cursor
    line:Line
  Text = tuple
    entries:seq[string]
    bgColor:Color
    spans:seq[Span]
    pos:Vec2
    bounds:tuple[width,height:int]
    hAlign:HorizontalAlignment
  Select = tuple
    img:Image
    selection:int
    line:Line
    selectionRange:HSlice[int,int]
    selectionAreas:seq[Area]
  BatchInit* = object
    case kind*:BatchKind
    of MenuBatch:
      selectorLine*:Line
      selectionRange*:HSlice[int,int]
    of InputBatch:
      alphaOnly*:bool
      inputLine*:Line
      inputCursor*:Cursor
      inputMaxChars*:int
      inputNumbers*:HSlice[int,int]
    else:discard
    titleOn*:bool
    titleLine*:Line
    name*:string
    pos*:(int,int)
    padding*:(int,int,int,int)
    entries*:seq[string]
    hAlign*:HorizontalAlignment
    font*:(string,float,Color)
    opacity*:float
    blur*:float
    bgColor*:Color = color(255,255,255)
    border*:(int,float,Color)
    shadow*:(int,float,Color)
    fixedBounds*:(int,int)
    centerOnWin*:bool

func textBounds(bounds:Vec2):(int,int) = (bounds[0].toInt,bounds[1].toInt)

func batchArea(batch:Batch):Area = (
  batch.pos.x,
  batch.pos.y,
  
  batch.pos.x+
  batch.text.bounds.width+
  (batch.border.size*2)+
  (if batch.fixedBounds.width > 0: 0 else: 
  batch.padding.left+
  batch.padding.right)+
  batch.shadow.size,
  
  batch.pos.y+
  batch.text.bounds.height+
  (batch.border.size*2)+
  (if batch.fixedBounds.height > 0: 0 else: 
  batch.padding.top+
  batch.padding.bottom)+
  batch.shadow.size)

func shadowRect(batch:Batch):Rect = 
  let size = batch.shadow.size.toFloat*batch.shadow.offSetFactor
  batch.area.area_wh:
    result = Rect(
      x:size,
      y:size,
      w:width.toFloat-size,
      h:height.toFloat-size
    )

func outerRect(batch:Batch):Rect = 
  batch.area.area_wh:
    result = Rect(
      x:0,y:0,
      w:(width-batch.shadow.size).toFloat,
      h:(height-batch.shadow.size).toFloat
    )

func innerRect(batch:Batch):Rect = 
  batch.area.area_wh:
    result = Rect(
      x:batch.border.size.toFloat,
      y:batch.border.size.toFloat,
      w:(width-batch.shadow.size-batch.border.size*2).toFloat,
      h:(height-batch.shadow.size-batch.border.size*2).toFloat,
    )

func lineBackground(batch:Batch):Image =
  let 
    r = batch.innerRect
    h = batch.font.defaultLineHeight
  newImage(r.w.toInt,h.toInt)

func lineOuterRect(ctx:Context):Rect = 
  Rect(x:0,y:0,w:ctx.image.width.toFloat,h:ctx.image.height.toFloat)

func lineInnerRect(ctx:Context,bSize:float):Rect = Rect(
  x:bSize, y:bSize,
  w:ctx.image.width.toFloat-(bSize*2),
  h:ctx.image.height.toFloat-(bSize*2))  

func linePos(batch:Batch,lineIdx:int):Vec2 = vec2(
  batch.border.size.toFloat,
  (batch.border.size+batch.padding.top+
  (batch.font.defaultLineHeight.toInt*lineIdx)).toFloat)

proc newPos*(batch:Batch,x,y:float) =
  batch.rect.x = x
  batch.rect.y = y
  batch.area = batch.rect.toArea
  batch.update = true

proc paintLineBackground(batch:Batch,color:Color,border:Border):Image =
  let ctx = batch.lineBackground.newContext
  ctx.fillStyle = border.color
  ctx.fillRoundedRect(ctx.lineOuterRect,border.angle)
  ctx.fillStyle = color
  ctx.fillRoundedRect(ctx.lineInnerRect(border.size.toFloat),border.angle)
  ctx.image

proc paintTitleBackgroundOn(batch:Batch,img:sink Image):Image =
  result = img
  result.draw(
    batch.paintLineBackground(batch.title.line.bgColor,batch.title.line.border),
    batch.linePos(0).translate)

proc paintBackground(batch:Batch):Image =
  let
    (width,height) = batch.area.area_wh
    ctx = newContext(newImage(width,height))
  ctx.fillStyle = batch.shadow.color
  ctx.fillRoundedRect(batch.shadowRect,batch.border.angle)
  ctx.fillStyle = batch.border.color
  ctx.fillRoundedRect(batch.outerRect,batch.border.angle)
  ctx.fillStyle = batch.text.bgColor
  ctx.fillRoundedRect(batch.innerRect,batch.border.angle)
  if batch.title.on: ctx.image = batch.paintTitleBackgroundOn ctx.image
  if batch.blur > 0: ctx.image.blur batch.blur
  ctx.image

proc paintSelector(batch:Batch):Image =
  batch.paintLineBackground(batch.selector.line.bgColor,batch.selector.line.border)

proc setSpanFontColors(batch:Batch) =
  for i,span in batch.text.spans:
    if span.font.paint != batch.font.paint and not batch.title.on or i > 0: 
      span.font.paint = batch.font.paint
  batch.text.spans[batch.selector.selection].font.paint = batch.selector.line.color

proc typeSet(batch:Batch):Arrangement = batch.text.spans.typeset(
  bounds = vec2(batch.text.bounds.width.toFloat,batch.text.bounds.height.toFloat),
  hAlign = batch.text.hAlign,
  wrap = false)

proc drawSelectorOn(batch:Batch,img:sink Image):Image =
  img.draw(batch.selector.img,translate batch.linePos(batch.selector.selection))
  img

proc setDimensions*(batch:Batch) =
  batch.text.bounds = batch.text.spans.layoutBounds.textBounds
  if batch.fixedBounds.width > 0: batch.text.bounds.width = batch.fixedBounds.width
  if batch.fixedBounds.height > 0: batch.text.bounds.height = batch.fixedBounds.height
  batch.area = batch.batchArea
  batch.rect = batch.area.toRect
  batch.background = batch.paintBackground

proc cursorRect(batch:Batch):Rect =
  let 
    x = batch.text.pos.x+batch.input.ctx.measureText(batch.text.spans[^1].text).width
    z = batch.linePos(batch.text.spans.high).y
    y = z+(z*0.025)
    (w,h) = (batch.font.size/2,batch.font.size)
  Rect(x:x,y:y,w:w,h:h)

proc paintCursorOn(batch:Batch,img:sink Image):Image =
  let ctx = img.newContext
  ctx.fillStyle = batch.input.cursor.color
  ctx.fillRect batch.cursorRect
  ctx.image

proc paintInputBackground(batch:Batch):Image =
  batch.paintLineBackground(batch.input.line.bgColor,batch.input.line.border)

func inputLinePos(batch:Batch):Vec2 = batch.linePos(batch.text.spans.high)

proc blinkTime(batch:Batch):bool =
  cpuTime()-batch.input.lastBlinkTime > batch.input.cursor.blinkPrSec

proc showCursor(batch:Batch):bool =
  if batch.blinkTime or batch.input.forceCursor:
    if batch.input.forceCursor:
      batch.input.forceCursor = false
      batch.input.showCursor = true
    else: batch.input.showCursor = not batch.input.showCursor
    batch.input.lastBlinkTime = cpuTime()
  batch.input.showCursor

proc paint(batch:Batch):Image =
  if batch.kind == InputBatch: batch.setDimensions()
  result = batch.background.copy
  if batch.kind == MenuBatch:
    batch.setSpanFontColors
    result = batch.drawSelectorOn result
  elif batch.kind == InputBatch: 
    result.draw(batch.paintInputBackground,batch.inputLinePos.translate)
    if batch.showCursor: result = batch.paintCursorOn result
  result.applyOpacity(batch.opacity)
  result.fillText(batch.typeSet,batch.text.pos.translate)

proc drawBatch*(b:var Boxy,batch:Batch) =
  if batch.kind == InputBatch and batch.blinkTime:batch.update = true
  if batch.isActive:
    b.drawDynamicImage (DynamicImage[Batch])batch

template inputOk:bool =
  if batch.input.numbers.b > 0:
    try: k.rune.toUTF8.parseInt in batch.input.numbers
    except: false
  elif batch.input.alphaOnly:
    k.rune.isAlpha
  else: true

template lengthOk(txt:untyped):bool =
  txt.len < batch.input.maxChars or batch.input.maxchars < 0

proc keyInput(batch:Batch,k:KeyboardEvent) =
  let txt = batch.text.spans[^1].text
  batch.update = true
  if k.hasRune and txt.lengthOk and inputOk:
    batch.text.spans[^1].text.add k.rune
  elif k.keyState.down:
    case k.button:
    of KeyBackspace:
      if txt.len > 0:
        let t = txt.toRunes
        batch.text.spans[^1].text = t[0..t.high-1].join
    else: batch.update = false
  else: batch.update = false
  if batch.update: batch.input.forceCursor = true

proc arrowUpPressed(batch:Batch) =
  if batch.selector.selection > batch.selector.selectionRange.a: 
    dec batch.selector.selection

proc downArrowPressed(batch:Batch) =
  if batch.selector.selection < batch.selector.selectionRange.b: 
    inc batch.selector.selection

proc menuBatchKeyb(batch:Batch,k:KeyboardEvent) =
  batch.update = true
  case k.button:
    of KeyUp:batch.arrowUpPressed
    of KeyDown:batch.downArrowPressed
    else:batch.update = false

proc batchKeyb*(k:KeyboardEvent,batch:Batch) =
  if batch.kind == InputBatch: batch.keyInput k
  elif batch.isActive and batch.kind == MenuBatch and k.keyState.down:
    batch.menuBatchKeyb k

func selectionArea(batch:Batch,selection:int):Area =
  let 
    selectionPos = batch.linePos selection
    (x,y) = (batch.pos.x+selectionPos.x.toInt,batch.pos.y+selectionPos.y.toInt)
  (x,y,x+batch.selector.img.width,y+batch.selector.img.height)

proc mouseOnSelectionArea*(batch:Batch):int =
  for idx,area in batch.selector.selectionAreas:
    if mouseOn area: return idx+batch.selector.selectionRange.a
  return -1

proc mouseSelect*(batch:Batch) = 
  if batch.isActive and batch.kind == MenuBatch:
    let selection = batch.mouseOnSelectionArea
    if selection > -1 and batch.selector.selection != selection:
      batch.selector.selection = selection
      batch.update = true

func batchSpans(entries:seq[string],font:Font):seq[Span] = 
  entries.mapIt newSpan(it,font.copy)

proc batchFont*(f:(string,float,Color)):Font =
  setNewFont(f[0],f[1],f[2])

func textPos(batch:Batch):Vec2 = vec2(
  (batch.border.size+batch.padding.left).toFloat,
  (batch.border.size+batch.padding.top).toFloat)

template inputContext:Context =
  let ctx = newContext(10,10)
  ctx.font = batch.font.typeface.filePath
  ctx.fontSize = batch.font.size
  ctx

template initInputBatch =
  if batchInit.inputMaxChars > 0:
    batch.input.maxChars = batchInit.inputMaxChars
  else: batch.input.maxChars = -1
  if batchInit.inputNumbers.b > 0:
    batch.input.numbers = batchInit.inputNumbers
  batch.input.alphaOnly = batchInit.alphaOnly
  batch.input.line = batchInit.inputLine
  batch.input.cursor = batchInit.inputCursor
  batch.text.hAlign = LeftAlign
  batch.text.spans.add newSpan("",batch.font.copy)
  batch.input.ctx = inputContext
  batch.text.spans[^1].font = setNewFont(
    batch.font.typeface.filePath,
    batch.font.size,batch.input.line.color)
  batch.input.lastBlinkTime = cpuTime()  

func computeSelectionAreas(batch:Batch):seq[Area] =
  batch.selector.selectionRange.toSeq.mapIt(batch.selectionArea it)

template selectionRange:HSlice[int,int] =
  if batchInit.selectionRange.b > 0: batchInit.selectionRange
  else:(if batch.title.on: 1 else: 0)..batch.text.spans.high

template initBatch*(batchKind:BatchKind,batch,userInitBlock:untyped):Batch =
  var batch = Batch(kind:batchKind)
  userInitBlock
  batch.text.spans = batch.text.entries.batchSpans(batch.font)
  if batch.kind == InputBatch: initInputBatch
  batch.setDimensions()
  if batch.title.on: batch.text.spans[0].font.paint = batch.title.line.color
  batch.text.pos = batch.textPos
  batch.updateImage = paint
  if batch.centerOnWin:
    batch.rect.x = (scaledWidth.toFloat-batch.rect.w)/2
    batch.rect.y = (scaledHeight.toFloat-batch.rect.h)/3
    batch.area = batch.rect.toArea
    batch.pos = (batch.rect.x.toInt,batch.rect.y.toInt)
  if batch.kind == MenuBatch: 
    batch.selector.selectionRange = selectionRange
    batch.selector.selection = batch.selector.selectionRange.a
    batch.selector.img = batch.paintSelector()
    batch.selector.selectionAreas = batch.computeSelectionAreas()
  batch.context = batch
  batch.update = true
  batch.isActive = true
  batch

proc newBatch*(batchInit:BatchInit):Batch = 
  initBatch batchInit.kind,batch:
    batch.name = batchInit.name
    batch.pos = batchInit.pos
    batch.padding = batchInit.padding
    batch.text.entries = batchInit.entries
    batch.font = batchFont batchInit.font
    batch.text.bgColor = batchInit.bgColor
    batch.text.hAlign = batchInit.hAlign
    batch.fixedBounds = batchInit.fixedBounds
    if batchInit.opacity > 0: batch.opacity = batchInit.opacity
    if batchInit.blur > 0: batch.blur = batchInit.blur
    if batchInit.titleOn:
      batch.title.on = true
      batch.title.line = batchInit.titleLine
    if batch.kind == MenuBatch:
      batch.selector.line = batchInit.selectorLine
    batch.border = batchInit.border
    batch.shadow = batchInit.shadow
    batch.centerOnWin = batchInit.centerOnWin

proc selection*(batch:Batch):int = 
  if batch.kind == MenuBatch: batch.selector.selection else: -1

proc input*(batch:Batch):string =
  if batch.kind == InputBatch: 
    batch.text.spans[^1].text
  else: "error, batch is not InputBatch"

proc deleteInput*(batch:Batch) =
  if batch.kind == InputBatch: 
    batch.text.spans[^1].text = ""
  else: echo "error, batch is not InputBatch"

proc resetMenu*(batch:Batch,entries:seq[string],selectionRange:HSlice[int,int]) =
  if batch.kind == MenuBatch:
    batch.text.spans = batchSpans(entries,batch.font)
    batch.setDimensions
    batch.selector.selectionRange = selectionRange
    batch.selector.selection = selectionRange.a
    batch.selector.selectionAreas = batch.computeSelectionAreas()
  else: echo "error, cannot resetSpanTexts: batch is not MenuBatch"

proc setSpanTexts*(batch:Batch,spans:seq[string]) =
  for i,span in batch.text.spans.mpairs:
    span.text = spans[i]
  batch.setDimensions

proc setSpans*(batch:Batch,spans:seq[Span]) =
  batch.text.spans = spans
  batch.setDimensions()

proc setSpanText*(batch:Batch,text:string,idx:int) =
  if idx < batch.text.spans.len and idx >= 0:
    batch.text.spans[idx].text = text
    batch.setDimensions()

proc setShallowPos*(batch:Batch,x,y:int) =
  batch.area.x1 = x
  batch.area.y1 = y
  batch.update = true

proc setPos*(batch:Batch,x,y:int) =
  batch.pos = (x,y)
  batch.rect.x = x.toFloat
  batch.rect.y = y.toFloat
  batch.area = batch.rect.toArea
  if batch.kind == MenuBatch:
    batch.selector.selectionAreas = batch.computeSelectionAreas()
  batch.update = true

proc pos*(batch:Batch):tuple[x,y:int] = (batch.area.x1,batch.area.y1)

proc spansLength*(batch:Batch):int = batch.text.spans.len

template commands*(batch,body:untyped):untyped =
  body
