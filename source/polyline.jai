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
    shape = null;
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
    shape = null; // @Cleanup is this necessary?? Is it even correct!? with stack/heap variables
}

append_copy :: (dest : *$T/Polyline_Soup, to_copy : T) {
    for polyline_to_copy : to_copy.polylines {
        new_polyline := array_add(*dest.polylines);
        new_polyline = array_copy(polyline_to_copy);
    }
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

get_point ::  (using polyline_soup : $T/Polyline_Soup, global_index : int) -> T.Point {
    running_count : int = 0;
    for polyline : polyline_soup.polylines {
        if global_index < running_count + polyline.points.count {
            return polyline.points[global_index - running_count];
        }
        running_count += polyline.points.count;
    }
    log_error("Error in get_point function");
    return .{}; // Should never reach here
}

segment_count :: (using polyline_soup : $T/Polyline_Soup) -> int {
    count : int;
    for polyline : polyline_soup.polylines {
        count += polyline.points.count - 1;
    }
    return count;
}

Point_Iterator :: (using soup : *$T/Polyline_Soup, body : Code, flags : For_Flags) #expand {
    BY_POINTER :: cast(bool)(flags & .POINTER);
    `it_index := -1;

    for polyline_index : 0..soup.polylines.count-1 {
        point_count := soup.polylines[polyline_index].points.count;
        for point_index : 0..point_count-1 {
            #if flags & .POINTER {
            `it : *T.Point = *soup.polylines[polyline_index].points[point_index];
            } else {
            `it : T.Point = soup.polylines[polyline_index].points[point_index];
            }
            it_index += 1;
            #insert body;
        }
    }
}

// @Speed This is horribly inefficient!
get_segment :: (using polyline_soup : $T/Polyline_Soup, query_index : int) -> found : bool #must, segment : Edge(T.Point) {
    for :SegmentIterator segment, segment_index : polyline_soup {
        if segment_index == query_index {
            return true, segment;
        }
    }
    return false, .{};
}

SegmentIterator :: (using soup : *$T/Polyline_Soup, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported.

    `it_index := -1;
    for polyline_index : 0..soup.polylines.count-1 {
        segment_count := soup.polylines[polyline_index].points.count-1;
        for segment_index : 0..segment_count-1 {
            `it : Edge(T.Point) = ---;
            it.from_point = *soup.polylines[polyline_index].points[segment_index];
            it.to_point   = *soup.polylines[polyline_index].points[segment_index + 1];
            it_index += 1;
            #insert (remove=#assert(false)) body;
        }
    }
}

#scope_file

#import "Math";
#import "Compiler";
