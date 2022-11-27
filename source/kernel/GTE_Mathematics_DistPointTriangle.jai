// Ported from GeometricTools/GTE/Mathematics/DistPointTriangle.h

Closest_Point_Point_Triangle :: struct {
    // Initialize the fields we'll use when doing many queries to find the closest
    distance, sqrDistance : float = FLOAT32_INFINITY;

    parameter : [3]float = ---;  // barycentric coordinates for triangle.v[3]
    closest : Vector3 = ---;
}

closest_point_point_triangle :: (point : Vector3, triangle : Triangle3) -> Closest_Point_Point_Triangle {
    diff : Vector3 = point - triangle.v[0];
    edge0 : Vector3 = triangle.v[1] - triangle.v[0];
    edge1 : Vector3 = triangle.v[2] - triangle.v[0];
    a00 : float = Dot(edge0, edge0);
    a01 : float = Dot(edge0, edge1);
    a11 : float = Dot(edge1, edge1);
    b0 : float = -Dot(diff, edge0);
    b1 : float = -Dot(diff, edge1);

    f00 : float = b0;
    f10 : float = b0 + a00;
    f01 : float = b0 + a01;

    p0, p1, p : Vector2 = ---;
    dt1, h0, h1 : float = ---;

    // Compute the endpoints p0 and p1 of the segment.  The segment is
    // parameterized by L(z) = (1-z)*p0 + z*p1 for z in [0,1] and the
    // directional derivative of half the quadratic on the segment is
    // H(z) = Dot(p1-p0,gradient[Q](L(z))/2), where gradient[Q]/2 =
    // (F,G).  By design, F(L(z)) = 0 for cases (2), (4), (5), and
    // (6).  Cases (1) and (3) can correspond to no-intersection or
    // intersection of F = 0 with the triangle.
    if f00 >= 0 {
        if f01 >= 0 {
            // (1) p0 = (0,0), p1 = (0,1), H(z) = G(L(z))
            GetMinEdge02(a11, b1, *p);
        } else {
            // (2) p0 = (0,t10), p1 = (t01,1-t01),
            // H(z) = (t11 - t10)*G(L(z))
            p0.component[0] = 0;
            p0.component[1] = f00 / (f00 - f01);
            p1.component[0] = f01 / (f01 - f10);
            p1.component[1] = cast(float)1 - p1.component[0];
            dt1 = p1.component[1] - p0.component[1];
            h0 = dt1 * (a11 * p0.component[1] + b1);
            if h0 >= 0 {
                GetMinEdge02(a11, b1, *p);
            } else {
                h1 = dt1 * (a01 * p1.component[0] + a11 * p1.component[1] + b1);
                if h1 <= 0 {
                    GetMinEdge12(a01, a11, b1, f10, f01, *p);
                } else {
                    GetMinInterior(p0, h0, p1, h1, *p);
                }
            }
        }
    } else if f01 <= 0 {
        if f10 <= 0 {
            // (3) p0 = (1,0), p1 = (0,1), H(z) = G(L(z)) - F(L(z))
            GetMinEdge12(a01, a11, b1, f10, f01, *p);
        } else {
            // (4) p0 = (t00,0), p1 = (t01,1-t01), H(z) = t11*G(L(z))
            p0.component[0] = f00 / (f00 - f10);
            p0.component[1] = cast(float)0;
            p1.component[0] = f01 / (f01 - f10);
            p1.component[1] = cast(float)1 - p1.component[0];
            h0 = p1.component[1] * (a01 * p0.component[0] + b1);
            if h0 >= cast(float)0 {
                p = p0;  // GetMinEdge01
            } else {
                h1 = p1.component[1] * (a01 * p1.component[0] + a11 * p1.component[1] + b1);
                if h1 <= 0 {
                    GetMinEdge12(a01, a11, b1, f10, f01, *p);
                } else {
                    GetMinInterior(p0, h0, p1, h1, *p);
                }
            }
        }
    } else if f10 <= 0 {
        // (5) p0 = (0,t10), p1 = (t01,1-t01),
        // H(z) = (t11 - t10)*G(L(z))
        p0.component[0] = cast(float)0;
        p0.component[1] = f00 / (f00 - f01);
        p1.component[0] = f01 / (f01 - f10);
        p1.component[1] = cast(float)1 - p1.component[0];
        dt1 = p1.component[1] - p0.component[1];
        h0 = dt1 * (a11 * p0.component[1] + b1);
        if h0 >= 0 {
            GetMinEdge02(a11, b1, *p);
        } else {
            h1 = dt1 * (a01 * p1.component[0] + a11 * p1.component[1] + b1);
            if h1 <= 0 {
                GetMinEdge12(a01, a11, b1, f10, f01, *p);
            } else {
                GetMinInterior(p0, h0, p1, h1, *p);
            }
        }
    } else {
        // (6) p0 = (t00,0), p1 = (0,t11), H(z) = t11*G(L(z))
        p0.component[0] = f00 / (f00 - f10);
        p0.component[1] = 0;
        p1.component[0] = 0;
        p1.component[1] = f00 / (f00 - f01);
        h0 = p1.component[1] * (a01 * p0.component[0] + b1);
        if h0 >= 0 {
            p = p0;  // GetMinEdge01
        } else {
            h1 = p1.component[1] * (a11 * p1.component[1] + b1);
            if h1 <= 0 {
                GetMinEdge02(a11, b1, *p);
            } else {
                GetMinInterior(p0, h0, p1, h1, *p);
            }
        }
    }

    result : Closest_Point_Point_Triangle;
    result.parameter[0] = cast(float)1 - p.component[0] - p.component[1];
    result.parameter[1] = p.component[0];
    result.parameter[2] = p.component[1];
    result.closest = triangle.v[0] + p.component[0] * edge0 + p.component[1] * edge1;
    diff = point - result.closest;
    result.sqrDistance = Dot(diff, diff);
    result.distance = sqrt(result.sqrDistance);
    return result;
}

#scope_file

GetMinEdge02 :: (a11 : float, b1 : float, p : *Vector2) {
    p.component[0] = 0;
    if b1 >= 0 {
        p.component[1] = 0;
    } else if a11 + b1 <= 0 {
        p.component[1] = 1;
    } else {
        p.component[1] = -b1 / a11;
    }
}

GetMinEdge12 :: inline (a01 : float, a11 : float, b1 : float, f10 : float, f01 : float, p : *Vector2) {
    h0 : float = a01 + b1 - f10;
    if h0 >= 0 {
        p.component[1] = 0;
    } else {
        h1 : float = a11 + b1 - f01;
        if h1 <= 0 {
            p.component[1] = 1;
        } else {
            p.component[1] = h0 / (h0 - h1);
        }
    }
    p.component[0] = cast(float)1 - p.component[1];
}

GetMinInterior :: inline (p0 : Vector2, h0 : float, p1 : Vector2, h1 : float, p : *Vector2) {
    z : float = h0 / (h0 - h1);
    <<p = (cast(float)1 - z) * p0 + z * p1;
}