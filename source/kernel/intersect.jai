// test_intersect_line3_plane3 :: (line : Line3, plane : Hyperplane3) -> bool #must

find_intersect_line3_plane3 :: (line : Line3, plane : Hyperplane3) -> (intersect_count : s32 = 0 #must, parameter : float = 0) {
    cosine := dot(line.direction, plane.normal);
    signed_distance, _ := signed_distance_point3_plane3(line.origin, plane);

    if cosine != 0. {
        // The line is not parallel to the plane, so they must intersect.
        return intersect_count = 1, parameter = -signed_distance / cosine;
    } else {
        // The line and plane are parallel.  Determine whether the line is on the plane.
        if signed_distance == 0. {
            // The line is coincident with the plane, so choose t = 0 for the parameter.
            return intersect_count = S32_MAX;
        } else {
            // The line is not on the plane.
            return;
        }
    }
}

find_intersect_ray3_plane3 :: (ray : Ray3, plane : Hyperplane3) -> (intersect_count : s32 = 0 #must, parameter : float = 0) {
    line : Line3;
    line.origin = ray.origin;
    line.direction = ray.direction;

    intersect_count, parameter := find_intersect_line3_plane3(line, plane);
    if parameter < 0 {
        intersect_count = 0;
    }
    return intersect_count, parameter;
}

find_intersect_ray3_triangle3 :: (ray : Ray3, triangle : Triangle3) -> (intersect : bool = false, parameter : float = 0, triangleBary : [3]float = .[0,0,0], point : Point3) {
    result_intersect : bool = false;
    result_parameter : float = 0;
    result_triangleBary : [3]float = .[0,0,0];
    result_point : Point3;

    // Compute the offset origin, edges, and normal.
    diff := ray.origin - triangle.v[0];
    edge1 := triangle.v[1] - triangle.v[0];
    edge2 := triangle.v[2] - triangle.v[0];
    normal := cross(edge1, edge2);

    // Solve Q + t*D = b1*E1 + b2*E2 (Q = kDiff, D = ray direction,
    // E1 = edge1, E2 = edge2, N = Cross(E1,E2)) by
    //   |Dot(D,N)|*b1 = sign(Dot(D,N))*Dot(D,Cross(Q,E2))
    //   |Dot(D,N)|*b2 = sign(Dot(D,N))*Dot(D,Cross(E1,Q))
    //   |Dot(D,N)|*t = -sign(Dot(D,N))*Dot(Q,N)
    DdN := dot(ray.direction, normal);
    sign : float;
    if (DdN > 0)
    {
        sign = 1;
    }
    else if (DdN < 0)
    {
        sign = -1;
        DdN = -DdN;
    }
    else
    {
        // Ray and triangle are parallel, call it a "no intersection"
        // even if the ray does intersect.
        result_intersect = false;

        return result_intersect, result_parameter, result_triangleBary, result_point;
    }

    DdQxE2 := sign * dot_cross(ray.direction, diff, edge2);
    if (DdQxE2 >= 0)
    {
        DdE1xQ := sign * dot_cross(ray.direction, edge1, diff);
        if (DdE1xQ >= 0)
        {
            if (DdQxE2 + DdE1xQ <= DdN)
            {
                // Line intersects triangle, check whether ray does.
                QdN := -sign * dot(diff, normal);
                if (QdN >= 0)
                {
                    // Ray intersects triangle.
                    result_intersect = true;
                    inv := 1 / DdN;
                    result_parameter = QdN * inv;
                    result_triangleBary[1] = DdQxE2 * inv;
                    result_triangleBary[2] = DdE1xQ * inv;
                    result_triangleBary[0] = 1. - result_triangleBary[1] - result_triangleBary[2];
                    result_point = ray.origin + result_parameter * ray.direction;
                    return result_intersect, result_parameter, result_triangleBary, result_point;
                }
                // else: t < 0, no intersection
            }
            // else: b1+b2 > 1, no intersection
        }
        // else: b2 < 0, no intersection
    }
    // else: b1 < 0, no intersection

    result_intersect = false;
    return result_intersect, result_parameter, result_triangleBary, result_point;
}



// @Refactor Take intersect out of the struct and pass is as the first in a pair of arguments
// This was this struct always represents an intersection
Intersection_Line3_AxisBox3 :: struct {
    intersect : bool;
    numIntersections : int;
    parameter : [2]float;
    point : [2]Point3;
};

find_intersect_line3_axis_box3 :: (line : Line3, box : AxisBox3) -> Intersection_Line3_AxisBox3 {

    // Test whether the current clipped segment intersects the current
    // test plane.  If the return value is 'true', the segment does
    // intersect the plane and is clipped; otherwise, the segment is
    // culled (no intersection with box).
    Clip :: (denom : float, numer : float, t0 : *float, t1 : *float) -> bool {
        if (denom > 0) {
            if (numer > denom * <<t1) {
                return false;
            }
            if (numer > denom * <<t0) {
                <<t0 = numer / denom;
            }
            return true;
        } else if (denom < 0) {
            if (numer > denom * <<t0) {
                return false;
            }
            if (numer > denom * <<t1) {
                <<t1 = numer / denom;
            }
            return true;
        } else {
            return numer <= 0;
        }
    }

    // Get the centered form of the aligned box.
    boxCenter, boxExtent := get_centered_form(box);

    // Transform the line to the aligned-box coordinate system.
    lineOrigin := line.origin - boxCenter;

    result : Intersection_Line3_AxisBox3;
    {
        // The line t-values are in the interval (-infinity,+infinity).
        // Clip the line against all six planes of an aligned box in
        // centered form. The result.numIntersections is
        //   0, no intersection
        //   1, intersect in a single point (t0 is line parameter of point)
        //   2, intersect in a segment (line parameter interval is [t0,t1])
        t0 := -FLOAT32_INFINITY;
        t1 :=  FLOAT32_INFINITY;
        if (Clip(+line.direction.x, -line.origin.x - boxExtent.x, *t0, *t1) &&
            Clip(-line.direction.x, +line.origin.x - boxExtent.x, *t0, *t1) &&
            Clip(+line.direction.y, -line.origin.y - boxExtent.y, *t0, *t1) &&
            Clip(-line.direction.y, +line.origin.y - boxExtent.y, *t0, *t1) &&
            Clip(+line.direction.z, -line.origin.z - boxExtent.z, *t0, *t1) &&
            Clip(-line.direction.z, +line.origin.z - boxExtent.z, *t0, *t1))
        {
            result.intersect = true;
            if (t1 > t0)
            {
                result.numIntersections = 2;
                result.parameter[0] = t0;
                result.parameter[1] = t1;
            }
            else
            {
                result.numIntersections = 1;
                result.parameter[0] = t0;
                result.parameter[1] = t0;
            }
        }
    }

    if (result.intersect) {
        for i : 0..1 {
            result.point[i] = line.origin + result.parameter[i] * line.direction;
        }
    }
    return result;
}

Intersection_Ray3_AxisBox3 :: Intersection_Line3_AxisBox3;

// @Cleanup rename to find_Intersection_Ray3_AxisBox3? since it finds the above result struct
find_intersect_ray3_axis_box3 :: (ray : Ray3, box : AxisBox3) -> Intersection_Ray3_AxisBox3 {
    // Get the centered form of the aligned box
    boxCenter, boxExtent := get_centered_form(box);

    // Transform the ray to the aligned-box coordinate system.
    rayOrigin := ray.origin - boxCenter;

    result : Intersection_Ray3_AxisBox3;

    // DoQuery(rayOrigin, ray.direction, boxExtent, result);
    {
        line : Line3 = ---;
        line.origin = rayOrigin;
        line.direction = ray.direction;
        result = find_intersect_line3_axis_box3(line, box);

        if (result.intersect) {
            // The line containing the ray intersects the box; the
            // t-interval is [t0,t1]. The ray intersects the box as long
            // as [t0,t1] overlaps the ray t-interval (0,+infinity).
            iiResult := find_intersect_interval_interval(result.parameter, 0, true);
            if (iiResult.intersect) {
                result.numIntersections = iiResult.numIntersections;
                result.parameter = iiResult.overlap;
            } else {
                // The line containing the ray does not intersect the box.
                // result = .{};
                result.intersect = false;
            }
        }
    }

    if (result.intersect) {
        for i : 0..1 {
            result.point[i] = ray.origin + result.parameter[i] * ray.direction;
        }
    }
    return result;
}



// The test-intersection queries use the method of separating axes.
// https://www.geometrictools.com/Documentation/MethodOfSeparatingAxes.pdf
// The find-intersection queries use parametric clipping against the six
// faces of the box. The find-intersection queries use Liang-Barsky
// clipping. The queries consider the box to be a solid. The algorithms
// are described in
// https://www.geometrictools.com/Documentation/IntersectionLineBox.pdf
test_intersect_ray3_axis_box3 :: (ray : Ray3, box : AxisBox3) -> intersect : bool {

    // Get the centered form of the aligned box
    boxCenter, boxExtent := get_centered_form(box);

    // Transform the ray to the aligned-box coordinate system.
    rayOrigin := ray.origin - boxCenter;

    for i : 0..2 {
        if (abs(rayOrigin.component[i]) > boxExtent.component[i] && rayOrigin.component[i] * ray.direction.component[i] >= 0) {
            return false;
        }
    }

    WxD := cross(ray.direction, rayOrigin);
    absWdU := make_vector3(abs(ray.direction.x), abs(ray.direction.y), abs(ray.direction.z));

    if (abs(WxD.x) > boxExtent.y * absWdU.z + boxExtent.z * absWdU.y) {
        return false;
    }

    if (abs(WxD.y) > boxExtent.x * absWdU.z + boxExtent.z * absWdU.x) {
        return false;
    }

    if (abs(WxD.z) > boxExtent.x * absWdU.y + boxExtent.y * absWdU.x) {
        return false;
    }

    return true;
}