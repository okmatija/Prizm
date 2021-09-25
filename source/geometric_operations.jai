// Copyright Epic Games, Inc. All Rights Reserved.

// Parts of this file are based on:
// https://github.com/davideberly/GeometricTools (Distributed under the Boost Software License, Version 1.0.)
// Real-Time Collision Detection by Christer Ericson, published by Morgan Kaufmann Publishers, (c) 2005 Elsevier Inc

Point3 :: Vector3;

// The plane is represented as Dot(U,X) = d where U is a unit-length normal
// vector, d is the plane constant, and X is any point on the plane.  The user
// must ensure that the normal vector is unit length.
Hyperplane3 :: struct {
    a, b, c, d : float;
#place a;
    normal : Vector3 = ---;
}

// The line is represented by P+t*D, where P is an origin point, D is a
// unit-length direction vector, and t is any real number.  The user must
// ensure that D is unit length.
Line3 :: struct {
    origin : Point3;
    direction : Vector3; // must be unit length
}

// The ray is represented as P+t*D, where P is the ray origin, D is a
// unit-length direction vector, and t >= 0.  The user must ensure that D is
// unit length.
Ray3 :: struct {
    origin : Point3;
    direction : Vector3; // must be unit length
}

// The segment is represented by (1-t)*P0 + t*P1, where P0 and P1 are the
// endpoints of the segment and 0 <= t <= 1.  Some algorithms prefer a
// centered representation that is similar to how oriented bounding boxes are
// defined.  This representation is C + s*D, where C = (P0 + P1)/2 is the
// center of the segment, D = (P1 - P0)/|P1 - P0| is a unit-length direction
// vector for the segment, and |t| <= e.  The value e = |P1 - P0|/2 is the
// extent (or radius or half-length) of the segment.
Segment3 :: struct {
    start : Point3;
    end : Point3;

#place start;
    p : [2]Point3 = ---;
}

Sphere :: struct {
    center : Point3;
    radius : float;
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

expand :: (using this : *Sphere, other : Sphere) {
    center_distance := distance(this.center, other.center);

    if this.radius > center_distance + other.radius {
        // Do nothing, this sphere contains other sphere
    } else if other.radius > center_distance + this.radius {
        // Update this sphere, it's contained in the other sphere
        <<this = other;
    } else {
        this.radius = center_distance / 2 + max(this.radius, other.radius);
        this.center = (this.center + other.center) / 2;
    }

    return;
}

make_hyperplane3 :: (plane_normal : Vector3, point_on_plane: Point3) -> Hyperplane3 {
    result : Hyperplane3 = ---;

    result.normal = plane_normal;
    result.d = dot(plane_normal, point_on_plane);

    return result;
}

make_normalized_hyperplane3_from_points :: (a : Point3, b : Point3, c : Point3) -> Hyperplane3 {
    result : Hyperplane3 = ---;

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

// test_intersect_line3_plane3 :: (line : Line3, plane : Hyperplane3) -> bool #must

find_intersect_line3_plane3 :: (line : Line3, plane : Hyperplane3) -> (intersect_count : s32 = 0 #must, parameter : float = 0)
{
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

test :: () {
    #import "Basic"; // @Question: ask about why this works

    print("Running test in %:%\n", #location().fully_pathed_filename, #location().line_number);

    l := Line3.{origin=.{0, 0, 0}, direction=.{0, 0, 1}};
    p := Hyperplane3.{d=10, normal=.{0, 0, 1}};
    intersect, t := find_intersect_line3_plane3(l, p);
    print("%, %, %\n", intersect, t, to_point(l, t));
}

#if 0 {
#run test();
}

dot :: dot_product;
cross :: cross_product;

 // @Cleanup Plane3 struct in Math module means we need to use the name Hyperplane3

