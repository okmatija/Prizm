// Ported from GeometricTools/GTE/Mathematics/Vector3.h

Dot :: dot;
Normalize :: normalize;

// Cross, UnitCross, and DotCross have a template parameter N that should
// be 3 or 4.  The latter case supports affine vectors in 4D (last
// component w = 0) when you want to use 4-tuples and 4x4 matrices for
// affine algebra.

// Compute the cross product using the formal determinant:
//   cross = det{{e0,e1,e2},{x0,x1,x2},{y0,y1,y2}}
//         = (x1*y2-x2*y1, x2*y0-x0*y2, x0*y1-x1*y0)
// where e0 = (1,0,0), e1 = (0,1,0), e2 = (0,0,1), v0 = (x0,x1,x2), and
// v1 = (y0,y1,y2).
Cross :: (v0 : Vector3, v1 : Vector3) -> Vector3 {
    result : Vector3;
    result.component[0] = v0.component[1] * v1.component[2] - v0.component[2] * v1.component[1];
    result.component[1] = v0.component[2] * v1.component[0] - v0.component[0] * v1.component[2];
    result.component[2] = v0.component[0] * v1.component[1] - v0.component[1] * v1.component[0];
    return result;
}

// Compute the normalized cross product.
UnitCross :: (v0 : Vector3, v1 : Vector3, $robust := false) -> Vector3 {
    unitCross : Vector3 = Cross(v0, v1);
    Normalize(*unitCross, robust);
    return unitCross;
}

// Compute Dot((x0,x1,x2),Cross((y0,y1,y2),(z0,z1,z2)), the triple scalar
// product of three vectors, where v0 = (x0,x1,x2), v1 = (y0,y1,y2), and
// v2 is (z0,z1,z2).
DotCross :: (v0 : Vector3, v1 : Vector3, v2 : Vector3) -> float {
    return Dot(v0, Cross(v1, v2));
}

// Compute a right-handed orthonormal basis for the orthogonal complement
// of the input vectors.  The function returns the smallest length of the
// unnormalized vectors computed during the process.  If this value is
// nearly zero, it is possible that the inputs are linearly dependent
// (within numerical round-off errors).  On input, numInputs must be 1 or
// 2 and v[0] through v[numInputs-1] must be initialized.  On output, the
// vectors v[0] through v[2] form an orthonormal set.
ComputeOrthogonalComplement :: ($numInputs : int, v : *[3]Vector3, $robust := false) -> float {
    #if numInputs == 1 {
        if (abs(v.*[0].component[0]) > abs(v.*[0].component[1]))
        {
            using v.*[1];
            x = -v.*[0].component[2];
            y = 0;
            z = +v.*[0].component[0];
        }
        else
        {
            using v.*[1];
            x = 0;
            y = +v.*[0].component[2];
            z = -v.*[0].component[1];
        }
        v.*[2] = Cross(v.*[0], v.*[1]);
        return Orthonormalize(3, v, robust);
    } else if numInputs == 2 {
        v.*[2] = Cross(v.*[0], v.*[1]);
        return Orthonormalize(3, v, robust);
    }

    assert(false);
    return 0;
}
