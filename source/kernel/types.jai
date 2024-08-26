// @Cleanup maybe these should be #type,isa?
Point2 :: Vector2;
Point3 :: Vector3;

Triangle3 :: struct {
    a : Point3;
    b : Point3;
    c : Point3;
#place a;
    v : [3]Point3 = ---;
}

// The plane is represented as Dot(U,X) = d where U is a unit-length normal
// vector, d is the plane constant, and X is any point on the plane.  The user
// must ensure that the normal vector is unit length.
// @Cleanup Plane3 struct in Math module means we need to use the name Hyperplane3
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
Segment :: struct (Point : Type) {
    start : Point;
    end : Point;

#place start;
    p : [2]Point = ---;
}

Segment2 :: Segment(Point2);
Segment3 :: Segment(Point3);


// A canonical box has center at the origin and is aligned with the standard
// Euclidean basis vectors. It has E = (e[0],e[1],...,e[N-1]) with e[i] >= 0
// for all i. A zero extent is allowed, meaning the box is degenerate in the
// corresponding direction. A box point is X = (x[0],x[1],...,x[N-1]) with
// |x[i]| <= e[i] for all i.
Canonical_Box :: struct(Point : Type) {
    Vector :: Point;

    DIM :: #run dimension_of(Point);

    extent : Vector;
}

Canonical_Box2 :: Canonical_Box(Point2);
Canonical_Box3 :: Canonical_Box(Point3);

Sphere3 :: Sphere;

Sphere :: struct {
    center : Point3;
    radius : float = -1;
}

is_empty :: (sphere : Sphere) -> bool {
    return sphere.radius < 0;
}


// The circle is the intersection of the sphere |X-C|^2 = r^2 and the
// plane Dot(N,X-C) = 0, where C is the circle center, r is the radius,
// and N is a unit-length plane normal.
Circle3 :: struct {
    // Warning: GTE's default constructor sets center to (0,0,0), normal to (0,0,1), and radius to 1.

    center : Vector3;
    normal : Vector3;
    radius : float;
}

Point_Color :: Vector3;

Segment_Color :: struct {
    start : Vector3 = DEFAULT_VERTEX_COLOR;
    end : Vector3 = DEFAULT_VERTEX_COLOR;

#place start;
    p : [2]Vector3 = ---;
}

Triangle_Color :: struct {
    a : Vector3 = DEFAULT_VERTEX_COLOR;
    b : Vector3 = DEFAULT_VERTEX_COLOR;
    c : Vector3 = DEFAULT_VERTEX_COLOR;
#place a;
    v : [3]Point3 = ---;
}
