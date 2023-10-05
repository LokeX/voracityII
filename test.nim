from math import PI,pow
type
  ShapeKind = enum Circle,Rectangle
  ShapeProps = tuple[shape:string,area,perimeter:float]
  Shape = object
    case kind:ShapeKind
    of Circle:r:float
    of Rectangle:w,h:float

func buildShapeProps(shape:Shape):ShapeProps =
  case shape.kind
  of Circle:($shape.kind,PI*shape.r.pow 2,2.0*PI*shape.r)
  of Rectangle:($shape.kind,shape.w*shape.h,2.0*shape.w+2.0*shape.h)

const shapes = [ # <- yes, shapes are compiletime resolved
  Circle:Shape(kind:Circle,r:10).buildShapeProps,
  Rectangle:Shape(kind:Rectangle,w:10,h:10).buildShapeProps,
]
template area(shape:untyped):untyped = shapes[shape].area
template perimeter(shape:untyped):untyped = shapes[shape].perimeter

for shape in shapes:
  for prop,value in shape.fieldPairs: 
    echo prop,": ",value 
  echo ""

echo Circle.area # <- A ShapeKind enumerated array of named tuples
echo Circle.perimeter # <- A ShapeKind enumerated array of named tuples
echo Rectangle.area # <- A ShapeKind enumerated array of named tuples
echo Rectangle.perimeter # <- A ShapeKind enumerated array of named tuples

