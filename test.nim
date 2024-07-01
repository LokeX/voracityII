from math import PI,pow
type
  ShapeKind = enum Circle,Rectangle
  ShapeProps = tuple[shape:string,area,perimeter:float]
  CircleShape = concept circle
    circle.r
    proc buildShapeProps(circle:CircleShape):ShapeProps
  RectangleShape = concept rectangle
    rectangle.w
    rectangle.h
    proc buildRectangleProps(rectangle:RectangleShape):ShapeProps    
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

for shape in shapes:
  for prop,value in shape.fieldPairs: 
    echo prop,": ",value 
  echo ""

template area(shape:untyped):untyped = shapes[shape].area
template perimeter(shape:untyped):untyped = shapes[shape].perimeter

echo Circle.area
echo Circle.perimeter
echo Rectangle.area
echo Rectangle.perimeter

import misc
var te = [1,2,3]

for i,e in te.enum_mitems:
  echo i

echo "0..0"
for i in 0..0:
  echo i

