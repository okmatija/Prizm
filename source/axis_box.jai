AxisBox :: struct(Point : Type) {
    Vector :: Point;

    DIM :: #run dimension_of(Point);
    Corner :: #run corner_type(DIM);

    min_point : Point;
    max_point : Point;

    // Initialize min and max to a state where:
    // 1. is_empty returns true
    // 2. we can start calling `expand`
    #insert #run generate_initializer(DIM);
}

// Explicitly initialize the box
init :: (using box : *$T/AxisBox) {
    ini :: initializer_of(T);
    ini(box);
}

AxisBox2 :: AxisBox(Vector2);

Corner2 :: enum u8 {
    // These names/values are based on the coordinate values of the corners of a unit box [0,0]x[1,1]
    XY_00 :: 0b00;
    XY_01 :: 0b01;
    XY_10 :: 0b10;
    XY_11 :: 0b11;
}

AxisBox3 :: AxisBox(Vector3);

Corner3 :: enum u8 {
    // These names/values are based on the coordinate values of the corners of a unit box [0,0,0]x[1,1,1]
    XYZ_000 :: 0b000;
    XYZ_001 :: 0b001;
    XYZ_010 :: 0b010;
    XYZ_011 :: 0b011;
    XYZ_100 :: 0b100;
    XYZ_101 :: 0b101;
    XYZ_110 :: 0b110;
    XYZ_111 :: 0b111;
}

corner :: inline (using box : $T/AxisBox, corner : T.Corner) -> T.Point
{
    result : T.Point = ---;

    m := 1;
    for d : 0..box.DIM-1 {
        if m & cast(s64)corner {
            result.component[d] = box.max_point.component[d];
        } else {
            result.component[d] = box.min_point.component[d];
        }
        m *= 2;
    }

    return result;
}

// @Cleanup Write the types of it_index and it explicitly in interator bodies
CornersIterator :: (using box : *$T/AxisBox, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported

    CORNER_COUNT :: 1 << T.DIM;

    `it_index := -1;
    for 0..CORNER_COUNT-1 {
        it_index += 1;
        `it := corner(box, xx it_index); // @CompilerBug Cannot use autodereference. Attempt to use a type restriction
        #insert (remove=#assert(false)) body;
    }
}

// @Cleanup rename to make_AxisBox2
make_axis_box :: (points : ..Vector2) -> AxisBox2 {
    box : AxisBox2;
    for points expand(*box, it);
    return box;
}

// @Cleanup rename to make_AxisBox3
make_axis_box3 :: (points : ..Vector3) -> AxisBox3 {
    box : AxisBox3;
    for points expand(*box, it);
    return box;
}

to_polyline :: (using box : AxisBox2) -> Polyline2 {
    polyline : Polyline2;
    array_add(*polyline.points,
              corner(box, .XY_00),
              corner(box, .XY_10),
              corner(box, .XY_11),
              corner(box, .XY_01),
              corner(box, .XY_00));
    return polyline;
}

to_polyline_soup :: (using box : AxisBox3) -> Polyline_Soup3 {
    result : Polyline_Soup3;

    Add_Face_Polyline :: (a : Corner3, b : Corner3, c : Corner3, d : Corner3) #expand {
        face_polyline := array_add(*result.polylines);
        array_add(*face_polyline.points,
                  corner(box, a),
                  corner(box, b),
                  corner(box, c),
                  corner(box, d),
                  corner(box, a));
    }

    Add_Face_Polyline(.XYZ_000, .XYZ_100, .XYZ_110, .XYZ_010); // XY, Z=0
    Add_Face_Polyline(.XYZ_001, .XYZ_101, .XYZ_111, .XYZ_011); // XY, Z=1
    Add_Face_Polyline(.XYZ_000, .XYZ_010, .XYZ_011, .XYZ_001); // YZ, X=0
    Add_Face_Polyline(.XYZ_100, .XYZ_110, .XYZ_111, .XYZ_101); // YZ, X=1
    Add_Face_Polyline(.XYZ_000, .XYZ_100, .XYZ_101, .XYZ_001); // XZ, Y=0
    Add_Face_Polyline(.XYZ_010, .XYZ_110, .XYZ_111, .XYZ_011); // XZ, Y=1

    return result;
}

is_empty :: (using box : $T/AxisBox) -> bool {
    for d : 0..box.DIM-1 {
        if min_point.component[d] > max_point.component[d] {
            return true;
        }
    }
    return false;
}

expand :: (using box : *$T/AxisBox, point : T.Point) {
    for d : 0..box.DIM-1 {
        min_point.component[d] = min(min_point.component[d], point.component[d]);
        max_point.component[d] = max(max_point.component[d], point.component[d]);
    }
}

expand :: (using box : *$T/AxisBox, other : T) {
    if !is_empty(other) {
        expand(box, other.min_point);
        expand(box, other.max_point);
    }
}

transform_axis_box3 :: (transform : Matrix4, using box : AxisBox3) -> AxisBox3 {
    result : AxisBox3 = box;
    result.min_point = transform_point(transform, result.min_point);
    result.max_point = transform_point(transform, result.max_point);
    return result;
}

center_point :: (using box : $T/AxisBox) -> T.Point {
    return (max_point + min_point) / 2;
}

diagonal :: (using box : $T/AxisBox) -> T.Vector {
    result : T.Vector;
    for d : 0..box.DIM-1 {
        if min_point.component[d] <= max_point.component[d] {
            result.component[d] = max_point.component[d] - min_point.component[d];
        }
    }
    return result;
}

get_centered_form :: (using box : $T/AxisBox) -> (center : T.Vector, extent : T.Vector) {
    return center_point(box), diagonal(box) / 2;
}

offset :: (using box : *$T/AxisBox, increment : float) {
    vector_increment : T.Vector;
    for d : 0..box.DIM-1 {
        vector_increment.component[d] = increment;
    }
    offset(box, vector_increment);
}

offset :: (using box : *$T/AxisBox, increment : T.Vector) {
    if !is_empty(box) {
        for d : 0..box.DIM-1 {
            assert(is_finite(increment.component[d]));
            min_point.component[d] -= increment.component[d];
            max_point.component[d] += increment.component[d];
        }
    }

    if is_empty(box) {
        // If box min/max invert after offset, use the standard representation of an empty box
        init(box);
    }
}

contains :: (using box : $T/AxisBox, point : T.Point) -> bool {
    return (min_point.x <= point.x) && (min_point.y <= point.y) &&
           (max_point.x >= point.x) && (max_point.y >= point.y);
}

#scope_file

generate_initializer :: ($DIM : int) -> string {
    builder : String_Builder;
    defer free_buffers(*builder);
    for 0..DIM-1 {
        print_to_builder(*builder, "min_point.component[%] =  FLOAT32_INFINITY;\n", it);
        print_to_builder(*builder, "max_point.component[%] = -FLOAT32_INFINITY;\n", it);
    }
    return builder_to_string(*builder);
}

corner_type :: ($DIM : int) -> Type {
    return ifx DIM == 2 then Corner2 else Corner3;
}

#import "Math";
#import "Basic";
#import "Compiler";
