// Ported from GeometricTools/GTE/Mathematics/DistLineSegment.h

Closest_Point_Line_Segment :: struct {
    // Initialize the fields we'll use when doing many queries to find the closest
    distance, sqrDistance : float = FLOAT32_INFINITY;

    // Index 0 corresponds to the line
    // Index 1 corresponds to the segment
    parameter : [2]float = .[FLOAT32_INFINITY, FLOAT32_INFINITY];
    closestPoint : [2]Vector3;

    /* @Incomplete @CompilerBug Use these aliases in user code
    #place parameter[0];    line_parameter : float = ---;
    #place parameter[1];    segment_parameter : float = ---;
    #place closestPoint[0]; line_closest_point : Vector3 = ---;
    #place closestPoint[1]; segment_closest_point : Vector3 = ---;
    */
}

// The centered form of the 'segment' is used.  Thus, parameter[1] of
// the result is in [-e,e], where e = |segment.p[1] - segment.p[0]|/2.
closest_point_line_segment :: (line : Line3, segment : Segment3) -> Closest_Point_Line_Segment {
    result : Closest_Point_Line_Segment;

    using segment_centered : Segment3_Centered = GetCenteredForm(segment);

    diff : Vector3 = line.origin - segment_centered.center;
    a01 : float = -Dot(line.direction, segment_centered.direction);
    b0 : float = Dot(diff, line.direction);
    s0, s1 : float = ---;

    if abs(a01) < 1. {
        // The line and segment are not parallel.
        det : float = 1. - a01 * a01;
        extDet : float = segment_centered.extent * det;
        b1 : float = -Dot(diff, segment_centered.direction);
        s1 = a01 * b0 - b1;

        if s1 >= -extDet {
            if s1 <= extDet {
                // Two interior points are closest, one on the line
                // and one on the segment.
                s0 = (a01 * b1 - b0) / det;
                s1 /= det;
            } else {
                // The endpoint e1 of the segment and an interior
                // point of the line are closest.
                s1 = segment_centered.extent;
                s0 = -(a01 * s1 + b0);
            }
        } else {
            // The endpoint e0 of the segment and an interior point
            // of the line are closest.
            s1 = -segment_centered.extent;
            s0 = -(a01 * s1 + b0);
        }
    } else {
        // The line and segment are parallel.  Choose the closest pair
        // so that one point is at segment origin.
        s1 = 0.;
        s0 = -b0;
    }

    result.parameter[0] = s0;
    result.parameter[1] = s1;
    result.closestPoint[0] = line.origin + s0 * line.direction;
    result.closestPoint[1] = segment_centered.center + s1 * segment_centered.direction;
    diff = result.closestPoint[0] - result.closestPoint[1];
    result.sqrDistance = Dot(diff, diff);
    result.distance = sqrt(result.sqrDistance);
    return result;
}