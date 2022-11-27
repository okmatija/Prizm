// Ported from GeometricTools/GTE/Mathematics/DistLine3Triangle3.h

Closest_Point_Line_Triangle :: struct {
    // Initialize the fields we'll use when doing many queries to find the closest
    distance, sqrDistance : float = FLOAT32_INFINITY;
    lineParameter : float = FLOAT32_INFINITY;

    triangleParameter : [3]float = ---;

    // Index 0 corresponds to the line
    // Index 1 corresponds to the triangle
    closestPoint : [2]Vector3 = ---;
}

closest_point_line_triangle :: (line : Line3, triangle : Triangle3) -> Closest_Point_Line_Triangle {
    result : Closest_Point_Line_Triangle = ---;

    // Test if line intersects triangle.  If so, the squared distance
    // is zero.
    edge0 : Vector3 = triangle.v[1] - triangle.v[0];
    edge1 : Vector3 = triangle.v[2] - triangle.v[0];
    normal : Vector3 = UnitCross(edge0, edge1);
    NdD := Dot(normal, line.direction);
    if abs(NdD) > 0 {
        // The line and triangle are not parallel, so the line
        // intersects/ the plane of the triangle.
        diff : Vector3 = line.origin - triangle.v[0];
        basis : [3]Vector3 = ---;  // {D, U, V}
        basis[0] = line.direction;
        ComputeOrthogonalComplement(1, *basis);
        UdE0 := Dot(basis[1], edge0);
        UdE1 := Dot(basis[1], edge1);
        UdDiff := Dot(basis[1], diff);
        VdE0 := Dot(basis[2], edge0);
        VdE1 := Dot(basis[2], edge1);
        VdDiff := Dot(basis[2], diff);
        invDet := (cast(float)1) / (UdE0 * VdE1 - UdE1 * VdE0);

        // Barycentric coordinates for the point of intersection.
        b1 := (VdE1 * UdDiff - UdE1 * VdDiff) * invDet;
        b2 := (UdE0 * VdDiff - VdE0 * UdDiff) * invDet;
        b0 := cast(float)1 - b1 - b2;

        if b0 >= 0 && b1 >= 0 && b2 >= 0 {
            // Line parameter for the point of intersection.
            DdE0 := Dot(line.direction, edge0);
            DdE1 := Dot(line.direction, edge1);
            DdDiff := Dot(line.direction, diff);
            result.lineParameter = b1 * DdE0 + b2 * DdE1 - DdDiff;

            // Barycentric coordinates for the point of intersection.
            result.triangleParameter[0] = b0;
            result.triangleParameter[1] = b1;
            result.triangleParameter[2] = b2;

            // The intersection point is inside or on the triangle.
            result.closestPoint[0] = line.origin + result.lineParameter * line.direction;
            result.closestPoint[1] = triangle.v[0] + b1 * edge0 + b2 * edge1;

            result.distance = 0;
            result.sqrDistance = 0;
            return result;
        }
    }

    // Either (1) the line is not parallel to the triangle and the
    // point of intersection of the line and the plane of the triangle
    // is outside the triangle or (2) the line and triangle are
    // parallel.  Regardless, the closest point on the triangle is on
    // an edge of the triangle.  Compare the line to all three edges
    // of the triangle.
    result.distance = FLOAT32_MAX;
    result.sqrDistance = FLOAT32_MAX;
    i0, i1 := 2, 0;
    while i1 < 3 {
        segCenter : Vector3 = cast(float)0.5 * (triangle.v[i0] + triangle.v[i1]);
        segDirection : Vector3 = triangle.v[i1] - triangle.v[i0];
        segExtent := cast(float).5 * Normalize(*segDirection);
        segment : Segment3 = SetCenteredForm(segCenter, segDirection, segExtent);

        lsResult : Closest_Point_Line_Segment = closest_point_line_segment(line, segment);
        if lsResult.sqrDistance < result.sqrDistance {
            result.sqrDistance = lsResult.sqrDistance;
            result.distance = lsResult.distance;
            result.lineParameter = lsResult.parameter[0];
            result.triangleParameter[i0] = cast(float).5 * (cast(float)1 - lsResult.parameter[0] / segExtent);
            result.triangleParameter[i1] = cast(float)1 - result.triangleParameter[i0];
            result.triangleParameter[3 - i0 - i1] = cast(float)0;
            result.closestPoint[0] = lsResult.closestPoint[0];
            result.closestPoint[1] = lsResult.closestPoint[1];
        }

        i0 = i1;
        i1 += 1;
    }

    return result;
}