// Copyright Epic Games, Inc. All Rights Reserved.

//
// Polyline.
//

Polyline :: struct ($Point : Type)
{
    #run ensure_2d_or_3d(Point);
    points : [..]Point;
}

Polyline2 :: Polyline(Vector2);
Polyline3 :: Polyline(Vector3);

clear :: (shape : *$T/Polyline) {
    if !shape return;
    array_reset_keeping_memory(*shape.points);
}

deinit :: (shape : *$T/Polyline) {
    if !shape return;
    array_reset(*shape.points);
}

is_empty :: (polyline : $T/Polyline) -> bool #must {
    return polyline.points.count < 2;
}

bounding_box :: (using polyline : $T/Polyline) -> AxisBox(T.Point) #must {
    box : AxisBox(T.Point);
    for points {
        expand(*box, it);
    }
    return box;
}

//
// Polyline Soup.
//

Polyline_Soup :: struct ($Point : Type)
{
    #run ensure_2d_or_3d(Point);
    polylines : [..]Polyline(Point);
}

Polyline_Soup2 :: Polyline_Soup(Vector2);
Polyline_Soup3 :: Polyline_Soup(Vector3);

clear :: (shape : *$T/Polyline_Soup) {
    if !shape return;
    for * shape.polylines clear(it);
    array_reset_keeping_memory(*shape.polylines);
}

deinit :: (shape : *$T/Polyline_Soup) {
    if !shape return;
    for * shape.polylines deinit(it);
    array_reset(*shape.polylines);
}

is_empty :: (polyline_soup : $T/Polyline_Soup) -> bool #must {
    for polyline_soup.polylines {
        if !is_empty(it) {
            return false;
        }
    }
    return true;
}

bounding_box :: (using polyline_soup : $T/Polyline_Soup) -> AxisBox(T.Point) #must {
    box : AxisBox(T.Point);
    for * polylines {
        polyline_box := bounding_box(it);
        expand(*box, polyline_box);
    }
    return box;
}

point_count :: (using polyline_soup : $T/Polyline_Soup) -> int {
    count : int;
    for polyline : polyline_soup.polylines {
        count += polyline.points.count;
    }
    return count;
}

segment_iterator :: (using soup : *$T/Polyline_Soup, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported.

    `it_index := 0;
    for polyline_index : 0..soup.polylines.count-1 {
        segment_count := soup.polylines[polyline_index].points.count-1;
        for segment_index : 0..segment_count-1 {
            `it : Edge(T.Point) = ---;
            it.from_point = *soup.polylines[polyline_index].points[segment_index];
            it.to_point   = *soup.polylines[polyline_index].points[segment_index + 1];
            #insert (remove=#assert(false)) body;
            it_index += 1;
        }
    }
}

#scope_file

#import "Math";
#import "Compiler";
