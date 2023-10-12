from math import PI,pow
type
  ShapeKind = enum Circle,Rectangle
  ShapeProps = tuple[shape:string,area,perimeter:float]
  CircleShape = concept circle
    circle.r
    # proc buildCircleProps(circle:CircleShape):ShapeProps
  RectangleShape = concept rectangle
    rectangle.w
    rectangle.h
    # proc buildRectangleProps(rectangle:RectangleShape):ShapeProps    
  Shape = object
    case kind:ShapeKind
    of Circle:r:float
    of Rectangle:w,h:float

func buildCircleProps(circle:CircleShape):ShapeProps =
  ($Circle,PI*circle.r.pow 2,2.0*PI*circle.r)

func buildRectangleProps(rectangle:RectangleShape):ShapeProps =
  ($Rectangle,rectangle.w*rectangle.h,2.0*rectangle.w+2.0*rectangle.h)

const shapes = [
  Circle:Shape(kind:Circle,r:10).buildCircleProps,
  Rectangle:Shape(kind:Rectangle,w:10,h:10).buildRectangleProps,
]

template area(shape:untyped):untyped = shapes[shape].area
template perimeter(shape:untyped):untyped = shapes[shape].perimeter

for shape in shapes:
  for prop,value in shape.fieldPairs: 
    echo prop,": ",value 
  echo ""

echo Circle.area
echo Circle.perimeter
echo Rectangle.area
echo Rectangle.perimeter

type
  Test = enum T1,T2,T3

var test:Test
echo Test.high
for _ in 0..10:
  echo test
  inc test