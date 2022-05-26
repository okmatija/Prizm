transform_ray :: (transform : Matrix4, ray : Ray3) -> Ray3 {
    result : Ray3 = ---;
    result.origin = transform_point(transform, ray.origin);
    result.direction = transform_vector(transform, ray.direction);

    check := normalize_or_zero(*result.direction);
    assert(check != 0);

    return result;
}

compute_normal :: inline (t : Triangle3, $normalize : bool = true) -> Vector3 {
    ab := t.b - t.a;
    ac := t.c - t.a;
    #if normalize {
    return unit_vector(cross(ab, ac));
    } else {
    return cross(ab, ac);
    }
}


make_sphere :: (center : Point3, radius : float) -> Sphere {
    result : Sphere = ---;

    result.center = center;
    result.radius = radius;

    return result;
}

// @Incomplete @robustness handle scaling of radius
transform :: (using sphere : *Sphere, transform : Matrix4) {
    center = (transform * make_vector4(center, 1.)).xyz;
}

// @Cleanup Use optional value bakes on keep_center_of_this parameter
expand :: (using this : *Sphere, other : Sphere, keep_center_of_this := false) {
    center_distance := distance(this.center, other.center);

    if this.radius > center_distance + other.radius {
        // Do nothing, this sphere contains other sphere
    } else if other.radius > center_distance + this.radius {
        // Update this sphere, it's contained in the other sphere
        if keep_center_of_this {
            this.radius = center_distance + other.radius;
        } else {
            <<this = other;
        }
    } else {
        if keep_center_of_this {
            this.radius = center_distance + max(this.radius, other.radius);
        } else {
            this.radius = center_distance / 2 + max(this.radius, other.radius);
            this.center = (this.center + other.center) / 2;
        }
    }

    return;
}

// Return true if this contains other
contains :: (using this : *Sphere, other : Sphere) -> bool {
    center_distance := distance(this.center, other.center);
    return this.radius > center_distance + other.radius;
}

contains :: (sphere : Sphere, point : Vector3) -> bool {
    return distance_squared(sphere.center, point) < (sphere.radius * sphere.radius);
}

make_hyperplane3 :: (plane_normal : Vector3, point_on_plane: Point3) -> Hyperplane3 {
    result : Hyperplane3 = ---;

    result.normal = plane_normal;
    result.d = dot(plane_normal, point_on_plane);

    return result;
}

make_normalized_hyperplane3_from_points :: (a : Point3, b : Point3, c : Point3) -> Hyperplane3 {
    result : Hyperplane3 = ---;

    // @Cleanup Make this consistent with triangle compute_normal! use ab and bc edges??
    normal := unit_vector(cross(c - b, a - b));
    result.normal = normal;
    result.d = -dot_product(normal, a);

    return result;
}

to_point :: (line : Line3, t : float) -> Point3 {
    return line.origin + t * line.direction;
}

to_point :: (ray : Ray3, t : float) -> Point3 {
    assert(t >= 0, "Expected t >= 0 but got t = %", t);
    return ray.origin + t * ray.direction;
}


// Compute Dot((x0,x1,x2),Cross((y0,y1,y2),(z0,z1,z2)), the triple scalar
// product of three vectors, where v0 = (x0,x1,x2), v1 = (y0,y1,y2), and
// v2 is (z0,z1,z2).
dot_cross :: (v0 : Vector3, v1 : Vector3, v2 : Vector3) -> float {
    return dot(v0, cross(v1, v2));
}

bounding_sphere :: (aabb : AxisBox3) -> Sphere
{
    result : Sphere = ---;
    result.center = center_point(aabb);
    result.radius = length(diagonal(aabb) / 2);
    return result;
}

bounding_sphere_naive :: (points : []Point3) -> Sphere
{
    aabb := make_axis_box3(..points);
    result := bounding_sphere(aabb);
    return result;
}

bounding_sphere_ritter :: (points : []Point3) -> Sphere
{
    result : Sphere;

    if !points.count {
        return result;
    }

    // Get sphere encompassing two approximately most distant points
    result = sphere_from_distant_points(points);

    // Grow sphere to include all points
    for i : 0..points.count-1 {
        result = bounding_sphere_of_sphere_and_point(result, points[i]);
    }

    return result;
}

expand :: (using box : *AxisBox3, triangle : Triangle3) {
    expand(box, triangle.a);
    expand(box, triangle.b);
    expand(box, triangle.c);
}

#scope_file

// Given a Sphere s and a Point p return a sphere adjusted (if needed) to just encompass p
bounding_sphere_of_sphere_and_point :: (s : Sphere, p : Point3) -> Sphere
{
    // Compute squared distance between point and sphere center
    d := p - s.center;
    dist2 := dot(d, d);

    // Only update s if point p is outside it
    if dist2 > s.radius * s.radius {
        dist := sqrt(dist2);
        newRadius := (s.radius + dist) * 0.5;
        k := (newRadius - s.radius) / dist;

        result := s;
        result.radius = newRadius;
        result.center += d * k;
        return result;
    }

    return s;
}

// Compute indices to the two most separated points of the (up to) six points
// defining the AABB encompassing the point set. Return these as min and max.
most_separated_points_on_AABB :: (points : []Point3) -> (min : int, max : int)
{
    // First find most extreme points along principal axes
    minx, maxx := 0, 0;
    miny, maxy := 0, 0;
    minz, maxz := 0, 0;
    for i : 1..points.count-1 {
        if points[i].x < points[minx].x then minx = i;
        if points[i].x > points[maxx].x then maxx = i;
        if points[i].y < points[miny].y then miny = i;
        if points[i].y > points[maxy].y then maxy = i;
        if points[i].z < points[minz].z then minz = i;
        if points[i].z > points[maxz].z then maxz = i;
    }

    // Compute the squared distances for the three pairs of points
    dist2x := dot(points[maxx] - points[minx], points[maxx] - points[minx]);
    dist2y := dot(points[maxy] - points[miny], points[maxy] - points[miny]);
    dist2z := dot(points[maxz] - points[minz], points[maxz] - points[minz]);

    // Pick the pair (min,max) of points most distant
    min, max := minx, maxx;
    if (dist2y > dist2x && dist2y > dist2z) then min, max = miny, maxy;
    if (dist2z > dist2x && dist2z > dist2y) then min, max = minz, maxz;

    return min, max;
}

sphere_from_distant_points :: (points : []Point3) -> Sphere
{
    // Find the most separated point pair defining the encompassing AABB
    min, max := most_separated_points_on_AABB(points);

    // Set up sphere to just encompass these two points
    sphere : Sphere = ---;
    sphere.center = (points[min] + points[max]) * .5;
    sphere.radius = dot(points[max] - sphere.center, points[max] - sphere.center);
    sphere.radius = sqrt(sphere.radius);
    return sphere;
}

dot :: dot_product;
cross :: cross_product;