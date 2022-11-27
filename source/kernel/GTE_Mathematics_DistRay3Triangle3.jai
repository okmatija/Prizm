// Ported from GeometricTools/GTE/Mathematics/DistRay3Triangle3.h

Closest_Point_Ray_Triangle :: struct {
    // Initialize the fields we'll use when doing many queries to find the closest
    distance, sqrDistance : float = FLOAT32_INFINITY;
    rayParameter : float = FLOAT32_INFINITY;

    triangleParameter : [3]float = ---;

    // Index 0 corresponds to the ray
    // Index 1 corresponds to the triangle
    closestPoint : [2]Vector3 = ---;
}

closest_point_ray_triangle :: (ray : Ray3, triangle : Triangle3) -> Closest_Point_Ray_Triangle {
    result : Closest_Point_Ray_Triangle = ---;

    line : Line3 = ---;
    line.origin = ray.origin;
    line.direction = ray.direction;

    ltResult : Closest_Point_Line_Triangle = closest_point_line_triangle(line, triangle);

    if ltResult.lineParameter >= 0 {
        result.distance = ltResult.distance;
        result.sqrDistance = ltResult.sqrDistance;
        result.rayParameter = ltResult.lineParameter;
        result.triangleParameter[0] = ltResult.triangleParameter[0];
        result.triangleParameter[1] = ltResult.triangleParameter[1];
        result.triangleParameter[2] = ltResult.triangleParameter[2];
        result.closestPoint[0] = ltResult.closestPoint[0];
        result.closestPoint[1] = ltResult.closestPoint[1];
    } else {
        ptResult : Closest_Point_Point_Triangle = closest_point_point_triangle(ray.origin, triangle);
        result.distance = ptResult.distance;
        result.sqrDistance = ptResult.sqrDistance;
        result.rayParameter = 0;
        result.triangleParameter[0] = ptResult.parameter[0];
        result.triangleParameter[1] = ptResult.parameter[1];
        result.triangleParameter[2] = ptResult.parameter[2];
        result.closestPoint[0] = ray.origin;
        result.closestPoint[1] = ptResult.closest;
    }
    return result;
}