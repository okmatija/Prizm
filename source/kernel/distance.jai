signed_distance_point3_plane3 :: (point : Point3, plane : Hyperplane3, $compute_closest_point : bool = false) -> float, Point3 {
    signed_distance := dot(plane.normal, point) - plane.d;
    closest_point : Point3 = ---;
    #if compute_closest_point {
        closest_point = point - signed_distance * plane.normal;
    }
    return signed_distance, closest_point;
}

// Returns closest = ray.origin + t * ray.direction and dist2, the squared distance between point and closest
distance_point3_ray3 :: (point : Point3, ray : Ray3) -> (closest : Point3, dist2 : float, t : float) {

    closest := ray.origin;

    t := dot(ray.direction, point - ray.origin);
    if t > 0  {
        closest += t * ray.direction;
    }

    diff := point - closest;
    dist2 := dot(diff, diff);

    return closest, dist2, t;
}
/*

// Compute the distance between a ray and a solid canonical box in 3D.
// 
// The ray is P + t * D for t >= 0, where D is not required to be unit length.
// 
// The canonical box has center at the origin and is aligned with the
// coordinate axes. The extents are E = (e[0],e[1],e[2]). A box point is
// Y = (y[0],y[1],y[2]) with |y[i]| <= e[i] for all i.
// 
// The closest point on the ray is stored in closest[0] with parameter t. The
// closest point on the box is stored in closest[1]. When there are infinitely
// many choices for the pair of closest points, only one of them is returned.
//
// See: GTE/Mathematics/DistRay3CanonicalBox3.h
distance_ray3_canonical_box3 :: (ray : Ray3, box : Canonical_Box3) -> {

}

max_distance_ray3_axis_box3 :: (ray : Ray3, box : Axis_Box3) -> float {
    // @Question Can we explicitly write the types in for_expansions?
    result : float = FLOAT32_INFINITY;
    for :CornersIterator corner : box {
        corner_dist := distance_ray3_point3(ray, corner);
        if corner_dist < result {
            result = corner_dist;
        }
    }
    return result;
}
*/