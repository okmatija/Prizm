// Copyright Epic Games, Inc. All Rights Reserved.

// @Incomplete extend to 3d polygons which are also useful even though they may not be planar

//
// Ring. A closed line (last point == first point) which should not be self-intersecting, inside is on the left of the points
//

Ring :: struct {
    points : [..]Vector2; // last point == first point
}

clear :: (shape : *Ring) {
    if !shape return;
    array_reset_keeping_memory(*shape.points);
}

is_empty :: (shape : Ring) -> bool #must {
    return shape.points.count < 2;
}

deinit :: (shape : *Ring) {
    if !shape return;
    array_reset(*shape.points);
    shape = null;
}

area :: (using ring : Ring) -> float {
    // See http://geomalgorithms.com/a01-_area.html#2D%20Polygons
    // A more efficient version needs to iterate over triples of vertices
    area := 0.;
    for :edge_iterator edge, index : ring {
        using edge;
        area += (from_point.x + to_point.x) * (to_point.y - from_point.y);
    }
    return area / 2.;
}

//
// Polygon. One outer Ring, and zero or more inner rings describing holes, inside is on the left of the points
//

Polygon :: struct {
    // @Cleanup explicitly store allocator/allocator_data and use array views? see Hash_Table.jai
    outer_ring : Ring;
    inner_rings : [..]Ring;
}

clear :: (shape : *Polygon) {
    if !shape return;
    clear(*shape.outer_ring);
    for * shape.inner_rings clear(it);
    array_reset_keeping_memory(*shape.inner_rings);
}

is_empty :: (shape : Polygon) -> bool #must {
    return is_empty(shape.outer_ring);
}

deinit :: (shape : *Polygon) {
    if !shape return;
    deinit(*shape.outer_ring);
    for * shape.inner_rings deinit(it);
    array_reset(*shape.inner_rings);
    shape = null;
}

bounding_box :: (using polygon : Polygon) -> AxisBox2 {
    return make_axis_box(..outer_ring.points);
}

area :: (using polygon : Polygon) -> float {
    result := area(outer_ring);
    for inner_rings {
        result += area(it);
    }
    return result;
}

point_count :: (using polygon : Polygon) -> int {
    count := outer_ring.points.count;
    for ring : inner_rings {
        count += ring.points.count;
    }
    return count;
}

//
// Iterators.
//

point_iterator :: (using polygon : *Polygon, body : Code, flags : For_Flags) #expand {
    BY_POINTER :: cast(bool)(flags & .POINTER);
    #if flags & .POINTER {
    `it : *Vector2 = ---;
    } else {
    `it : Vector2 = ---;
    }
    `it_index := -1;

    // print("outer ring:\n");
    for *=BY_POINTER point, point_index : outer_ring.points {
        it = point;
        it_index += 1;
        #insert body;
    }

    for inner_ring, inner_ring_index : inner_rings {
        // print("inner ring %:\n", inner_ring_index);
        for *=BY_POINTER point, point_index : inner_ring.points {
            it = point;
            it_index += 1;
            #insert body;
        }
    }
}

// point_forward_iterator :: #bake_arguments point_iterator(reverse=false);
// point_reverse_iterator :: #bake_arguments point_iterator(reverse=true);

edge_iterator :: (using ring : *Ring, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported.

    edge_count := points.count - 1;

    `it_index := -1;
    for 0..edge_count-1 {
        `it : Edge2 = ---;
        it.from_point = *points[it_index];
        it.to_point   = *points[it_index + 1];
        it_index += 1;
        #insert (remove=#assert(false)) body;
    }
}


//
// Polygon Soup.
//

Polygon_Soup :: struct {
    polygons : [..]Polygon;
}

clear :: (shape : *Polygon_Soup) {
    if !shape return;
    for * shape.polygons clear(it);
    array_reset_keeping_memory(*shape.polygons);
}

is_empty :: (shape : Polygon_Soup) -> bool #must {
    for shape.polygons if !is_empty(it) return false;
    return true;
}

deinit :: (shape : *Polygon_Soup) {
    if !shape return;
    for * shape.polygons deinit(it);
    array_reset(*shape.polygons);
}

point_count :: (using polygon_soup : Polygon_Soup) -> int {
    count : int;
    for polygon : polygon_soup.polygons {
        count += point_count(polygon);
    }
    return count;
}

// Untested
point_iterator :: (using soup : *Polygon_Soup, body : Code, flags : For_Flags) #expand {

    BY_POINTER :: cast(bool)(flags & .POINTER);
    #if flags & .POINTER {
    `it : *Vector2 = ---;
    } else {
    `it : Vector2 = ---;
    }
    `it_index := -1;

    for polygon, polygon_index : soup.polygons {
        for *=BY_POINTER point, point_index : polygon.outer_ring.points {
            it = point;
            it_index += 1;
            #insert body;
        }

        for inner_ring, inner_ring_index : inner_rings {
            for *=BY_POINTER point, point_index : polygon.inner_ring.points {
                it = point;
                it_index += 1;
                #insert body;
            }
        }
    }
}