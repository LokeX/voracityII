import win
import deck

type
  PlayerKind* = enum
    human = "Human",
    computer = "Computer",
    none = "None"
  PlayerColors* = enum
    red,green,blue,yellow,black,white
  Player* = ref object
    nr*:int
    color*:PlayerColors
    kind*:PlayerKind
    batch*:AreaHandle
    turnNr*:int
    piecesOnSquares*:array[5,int]
    cards*:seq[BlueCard]
    cash*:int
  Turn* = ref object
    nr*:int
    player*:Player
    diceMoved*:bool
