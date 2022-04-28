/*

Closest_Point_Point3_Canonical_Box3 :: struct {
    distance : float;
    sqrDistance : float;
    closest : [2]Point3;
}

// Compute the distance from a point to a solid canonical box in nD.
// 
// The canonical box has center at the origin and is aligned with the
// coordinate axes. The extents are E = (e[0],e[1],...,e[n-1]). A box
// point is Y = (y[0],y[1],...,y[n-1]) with |y[i]| <= e[i] for all i.
// 
// The input point P is stored in closest[0]. The closest point on the box
// is stored in closest[1]. When there are infinitely many choices for the
// pair of closest points, only one of them is returned.
closest_point_point3_canonical_box3 :: (point : Point3, box : Canonical_Box3) -> Closest_Point_Point3_Canonical_Box3 {
    result : Closest_Point_Point3_Canonical_Box3;

    result.closest[0] = point;
    result.closest[1] = point;
    result.sqrDistance = 0.;
    for i : 0..N-1 {
        if (point[i] < -box.extent[i]) {
            delta := result.closest[1][i] + box.extent[i];
            result.sqrDistance += delta * delta;
            result.closest[1][i] = -box.extent[i];
        } else if (point[i] > box.extent[i]) {
            delta := result.closest[1][i] - box.extent[i];
            result.sqrDistance += delta * delta;
            result.closest[1][i] = box.extent[i];
        }
    }
    result.distance = sqrt(result.sqrDistance);

    return result;
}

Closest_Point_Line3_Canonical_Box3 :: struct {
    distance : float;
    sqrDistance : float;
    parameter : float;
    closest : [2]Point3;
}

// Compute the distance between a line and a canonical box in 3D.
// 
// The line is P + t * D, where D is not required to be unit length.
// 
// The canonical box has center at the origin and is aligned with the
// coordinate axes. The extents are E = (e[0],e[1],e[2]). A box point is
// Y = (y[0],y[1],y[2]) with |y[i]| <= e[i] for all i.
// 
// The closest point on the line is stored in closest[0] with parameter t. The
// closest point on the box is stored in closest[1]. When there are infinitely
// many choices for the pair of closest points, only one of them is returned.
//
// The DoQueryND functions are described in Section 10.9.4 Linear Component
// to Oriented Bounding Box of
//    Geometric Tools for Computer Graphics,
//    Philip J. Schneider and David H. Eberly,
//    Morgan Kaufmnn, San Francisco CA, 2002
//
// TODO: The code in DistLine2AlignedBox2.h effectively uses the same,
// although in 2D. That code is cleaner than the 3D code here. Clean up the
// 3D code.
closest_point_line3_canonical_box3 :: (line : Line3, box : Canonical_Box3) -> Closest_Point_Line3_Canonical_Box3 {
    
}

Closest_Point_Point3_Axis_Box3 :: Closest_Point_Point3_Canonical_Box3;

// Compute the distance from a point to a solid aligned box in nD.
// 
// The aligned box has minimum corner A and maximum corner B. A box point is X
// where A <= X <= B; the comparisons are componentwise.
// 
// The input point is stored in closest[0]. The closest point on the box is
// stored in closest[1]. When there are infinitely many choices for the pair
// of closest points, only one of them is returned.
// @Refactor make this generic on the point type
closest_point_point3_axis_box3 :: (point : Point3, box : AxisBox3) -> Closest_Point_Point3_Axis_Box3 {
    result : Closest_Point_Point3_Axis_Box3;

    // Translate the point and box so that the box has center at the
    // origin.
    boxCenter : Point3;
    cbox : Canonical_Box3;
    box.GetCenteredForm(boxCenter, cbox.extent);
    xfrmPoint := point - boxCenter;

    // The query computes 'output' relative to the box with center
    // at the origin.
    result = closest_point_point3_canonical_box3(xfrmPoint, cbox);

    // Store the input point.
    result.closest[0] = point;

    // Translate the closest box point to the original coordinates.
    result.closest[1] += boxCenter;

    return result;
}

Closest_Point_Line3_Axis_Box3 :: struct {

}

closest_point_ray3_axis_box3 :: (ray : Ray3, box : AxisBox3) -> Closest_Point_Line3_Axis_Box3 {
}

Closest_Point_Ray3_Axis_Box3 :: Closest_Point_Line3_Axis_Box3

closest_point_ray3_axis_box3 :: (ray : Ray3, box : AxisBox3) -> Closest_Point_Ray3_Axis_Box3 {
    result : Closest_Point_Ray3_Axis_Box3;

    line := Line3.{ray.origin, ray.direction};
    lbOutput := closest_point_line3_axis_box3(line, box);

    if (lbOutput.parameter >= 0.) {
        result = lbOutput;
    } else {
        pbOutput := closest_point_point3_axis_box3(ray.origin, box);
        result.distance = pbOutput.distance;
        result.sqrDistance = pbOutput.sqrDistance;
        result.parameter = 0.;
        result.closest[0] = ray.origin;
        result.closest[1] = pbOutput.closest[1];
    }
    return result;
}


*/

Closest_Point_Ray_Segment :: struct {
    distance : float = 0;
    sqrDistance : float = 0;
    parameter : [2]float = .[0, 0];
    closest : [2]Point3 = .[.{0,0,0}, .{0,0,0}];
};

// Compute the distance between a ray and a segment in nD.
// 
// The ray is P[0] + s[0] * D[0] for s[0] >= 0. D[0] is not required to be
// unit length. 
// 
// The segment is Q[0] + s[1] * (Q[1] - Q[0]) for 0 <= s[1 <= 1. The
// direction D = Q[1] - Q[0] is generally not unit length.
// 
// The closest point on the ray is stored in closest[0] with parameter[0]
// storing s[0]. The closest point on the segment is stored in closest[1] with
// parameter[1] storing s[1]. When there are infinitely many choices for the
// pair of closest points, only one of them is returned.
closest_point_ray_segment :: (ray : Ray3, segment : Segment3) -> Closest_Point_Ray_Segment
{
    result : Closest_Point_Ray_Segment;

    zero : float = 0;
    one : float = 1;
    segDirection := segment.p[1] - segment.p[0];
    diff := ray.origin - segment.p[0];
    a00 := dot(ray.direction, ray.direction);
    a01 := -dot(ray.direction, segDirection);
    a11 := dot(segDirection, segDirection);
    b0 := dot(ray.direction, diff);
    det := Max(a00 * a11 - a01 * a01, zero);
    s0, s1 : float = 0, 0;

    if (det > zero)
    {
        // The ray and segment are not parallel.
        b1 := -dot(segDirection, diff);
        s0 = a01 * b1 - a11 * b0;
        s1 = a01 * b0 - a00 * b1;

        if (s0 >= zero)
        {
            if (s1 >= zero)
            {
                if (s1 <= det)  // region 0
                {
                    // The minimum occurs at interior points of the
                    // ray and the segment.
                    s0 /= det;
                    s1 /= det;
                }
                else  // region 1
                {
                    // The endpoint Q1 of the segment and an interior
                    // point of the line are closest.
                    s0 = -(a01 + b0) / a00;
                    s1 = one;
                }
            }
            else  // region 5
            {
                // The endpoint Q0 of the segment and an interior
                // point of the line are closest.
                s0 = -b0 / a00;
                s1 = zero;
            }
        }
        else  // s0 < 0
        {
            if (s1 <= zero)  // region 4
            {
                s0 = -b0;
                if (s0 > zero)
                {
                    s0 /= a00;
                    s1 = zero;
                }
                else
                {
                    s0 = zero;
                    s1 = -b1;
                    if (s1 < zero)
                    {
                        s1 = zero;
                    }
                    else if (s1 > a11)
                    {
                        s1 = one;
                    }
                    else
                    {
                        s1 /= a11;
                    }
                }
            }
            else if (s1 <= det)  // region 3
            {
                s0 = zero;
                s1 = -b1;
                if (s1 < zero)
                {
                    s1 = zero;
                }
                else if (s1 > a11)
                {
                    s1 = one;
                }
                else
                {
                    s1 /= a11;
                }
            }
            else  // region 2
            {
                s0 = -(a01 + b0);
                if (s0 > zero)
                {
                    s0 /= a00;
                    s1 = one;
                }
                else
                {
                    s0 = zero;
                    s1 = -b1;
                    if (s1 < zero)
                    {
                        s1 = zero;
                    }
                    else if (s1 > a11)
                    {
                        s1 = one;
                    }
                    else
                    {
                        s1 /= a11;
                    }
                }
            }
        }
    }
    else
    {
        // The ray and segment are parallel.
        if (a01 > zero)
        {
            // Opposite direction vectors.
            s0 = -b0 / a00;
            s1 = zero;
        }
        else
        {
            // Same direction vectors.
            s0 = -(a01 + b0) / a00;
            s1 = one;
        }
    }

    result.parameter[0] = s0;
    result.parameter[1] = s1;
    result.closest[0] = ray.origin + s0 * ray.direction;
    result.closest[1] = segment.p[0] + s1 * segDirection;
    diff = result.closest[0] - result.closest[1];
    result.sqrDistance = dot(diff, diff);
    result.distance = sqrt(result.sqrDistance);
    return result;
}



