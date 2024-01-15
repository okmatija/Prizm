// Ported from GeometricTools/GTE/Mathematics/IntrSphere3Sphere3.h

// The queries consider the spheres to be solids.

test_intersection_sphere3_sphere3 :: (sphere0 : Sphere3, sphere1 : Sphere3) -> intersect : bool #must {
    diff : Vector3 = sphere1.center - sphere0.center;
    rSum : float = sphere0.radius + sphere1.radius;
    return (Dot(diff, diff) <= rSum * rSum);
}

Intersection_Sphere3_Sphere3 :: struct {
    // The type of intersection.
    //   0: spheres are disjoint and separated
    //   1: spheres touch at point, each sphere outside the other
    //   2: spheres intersect in a circle
    //   3: sphere0 strictly contained in sphere1
    //   4: sphere0 contained in sphere1, share common point
    //   5: sphere1 strictly contained in sphere0
    //   6: sphere1 contained in sphere0, share common point
    Intersection_Kind :: enum {
        SPHERES_SEPARATED_AND_DISJOINT :: 0;
        SPHERES_SEPARATED_WITH_COMMON_POINT :: 1;
        SPHERES_INTERSECT_IN_A_CIRCLE :: 2;
        SPHERE0_STRICTLY_INSIDE_SPHERE1 :: 3;
        SPHERE0_INSIDE_SPHERE1_WITH_COMMON_POINT :: 4;
        SPHERE1_STRICTLY_INSIDE_SPHERE0 :: 5;
        SPHERE1_INSIDE_SPHERE0_WITH_COMMON_POINT :: 6;
    }

    kind : Intersection_Kind;
    point : Vector3;    // types 1, 4, 6
    circle : Circle3;   // type 2
}

// Assumes sphere0 and sphere1 are non-empty
find_intersection_sphere3_sphere3 :: (sphere0 : Sphere3, sphere1 : Sphere3) -> Intersection_Sphere3_Sphere3 {
    result : Intersection_Sphere3_Sphere3 = ---;

    // The plane of intersection must have C1-C0 as its normal
    // direction.
    C1mC0 := sphere1.center - sphere0.center;
    sqrLen := Dot(C1mC0, C1mC0);
    r0, r1 := sphere0.radius, sphere1.radius;
    rSum := r0 + r1;
    rSumSqr := rSum * rSum;

    if (sqrLen > rSumSqr)
    {
        // The spheres are disjoint/separated.
        result.kind = xx 0;
        return result;
    }

    if (sqrLen == rSumSqr)
    {
        // The spheres are just touching with each sphere outside the
        // other.
        //Normalize(*C1mC0); // :NormalizeCompilerBug @CompilerBug Error: Procedure call matches multiple possible overloads
        normalize(*C1mC0);
        result.kind = xx 1;
        result.point = sphere0.center + r0 * C1mC0;
        return result;
    }

    rDif := r0 - r1;
    rDifSqr := rDif * rDif;
    if (sqrLen < rDifSqr)
    {
        // One sphere is strictly contained in the other.  Compute a
        // point in the intersection set.
        result.kind = xx (ifx rDif <= 0. then 3 else 5);
        result.point = .5 * (sphere0.center + sphere1.center);
        return result;
    }
    if (sqrLen == rDifSqr)
    {
        // One sphere is contained in the other sphere but with a
        // single point of contact.
        // :NormalizeCompilerBug
        //Normalize(*C1mC0);
        normalize(*C1mC0);
        if (rDif <= 0.)
        {
            result.kind = xx 4;
            result.point = sphere1.center + r1 * C1mC0;
        }
        else
        {
            result.kind = xx 6;
            result.point = sphere0.center + r0 * C1mC0;
        }
        return result;
    }

    // Compute t for which the circle of intersection has center
    // K = C0 + t*(C1 - C0).
    t := .5 * (1. + rDif * rSum / sqrLen);

    // Compute the center and radius of the circle of intersection.
    result.circle.center = sphere0.center + t * C1mC0;
    result.circle.radius = sqrt(max(r0 * r0 - t * t * sqrLen, 0.));

    // Compute the normal for the plane of the circle.
    //Normalize(*C1mC0); // :NormalizeCompilerBug
    normalize(*C1mC0);
    result.circle.normal = C1mC0;

    // The intersection is a circle.
    result.kind = xx 2;
    return result;
}
