import sequtils

type
  PlanSquares = tuple[required,oneInMany:seq[int]]
  CardKind* = enum Deed,Plan,Job,Event,News,Mission
  BlueCard* = object
    title*:string
    case cardKind*:CardKind
    of Plan,Mission,Job,Deed:
      squares*:PlanSquares
      cash*:int
      eval*:int
    of Event,News:
      moveSquares*:seq[int]
      bgPath*:string


let 
  pieces = [1,1,1,33,36]
  plan = BlueCard(
    cardKind:Plan,
    squares:(@[33,36],@[])
  )

template requiredSquaresOk(pieces,card:untyped):untyped =
  card.squares.required.deduplicate
    .allIt pieces.count(it) >= card.squares.required.count it

template oneInManySquaresOk(pieces,card:untyped):untyped =
  card.squares.oneInmany.len == 0 or 
  pieces.anyIt it in card.squares.oneInMany

func isCashable*(pieces:openArray[int],card:BlueCard):bool =
  (pieces.requiredSquaresOk card) and (pieces.oneInManySquaresOk card)

func plans*(pieces:openArray[int],cards:seq[BlueCard]):tuple[cashable,notCashable:seq[BlueCard]] =
  for card in cards:
    if pieces.isCashable card: result.cashable.add card
    else: result.notCashable.add card

echo pieces.plans(@[plan])
