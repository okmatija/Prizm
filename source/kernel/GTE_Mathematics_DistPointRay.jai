// Ported from GeometricTools/GTE/Mathematics/DistPointRay.h

Closest_Point_Ray_Point :: struct {
    // Initialize the fields we'll use when doing many queries to find the closest
    distance, sqrDistance : float = FLOAT32_INFINITY;
    rayParameter : float = FLOAT32_INFINITY;  // t in [0,+infinity)

    rayClosest : Vector3 = ---;  // origin + t * direction
    point : Vector3 = ---;
}

closest_point_ray_point :: (ray : Ray3, point : Point3) -> Closest_Point_Ray_Point {
    result : Closest_Point_Ray_Point;
    result.point = point;

    diff : Vector3 = point - ray.origin;
    result.rayParameter = Dot(ray.direction, diff);
    if result.rayParameter > 0 {
        result.rayClosest = ray.origin + result.rayParameter * ray.direction;
    } else {
        result.rayClosest = ray.origin;
    }

    diff = point - result.rayClosest;
    result.sqrDistance = Dot(diff, diff);
    result.distance = sqrt(result.sqrDistance);

    return result;
}