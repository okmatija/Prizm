// Ported from GeometricTools/GTE/Mathematics/Vector.h

Normalize :: (v : *Vector3, $robust := false) -> float {
    #if robust {
        maxAbsComp := abs(v.component[0]);
        for i : 1..2 {
            absComp := abs(v.component[i]);
            if absComp > maxAbsComp {
                maxAbsComp = absComp;
            }
        }

        length : float = ---;
        if maxAbsComp > 0 {
            <<v /= maxAbsComp;
            length = sqrt(Dot(v, v));
            <<v /= length;
            length *= maxAbsComp;
        } else {
            length = 0;
            for i : 0..2 {
                v.component[i] = 0;
            }
        }
        return length;
    } else {
        length := sqrt(Dot(v, v));
        if length > 0 {
            <<v /= length;
        } else {
            for i : 0..2 {
                v.component[i] = 0;
            }
        }
        return length;
    }
}

// Gram-Schmidt orthonormalization to generate orthonormal vectors from
// the linearly independent inputs.  The function returns the smallest
// length of the unnormalized vectors computed during the process.  If
// this value is nearly zero, it is possible that the inputs are linearly
// dependent (within numerical round-off errors).  On input,
// 1 <= numElements <= N and v[0] through v[numElements-1] must be
// initialized.  On output, the vectors v[0] through v[numElements-1]
// form an orthonormal set.
Orthonormalize :: ($numInputs : int, v : *[3]Vector3, $robust := false) -> float {
    #if 1 <= numInputs && numInputs <= 3 {
        minLength : float = Normalize(*(<<v)[0], robust);
        for i : 1..numInputs-1 {
            for j : 0..i-1 {
                dot : float = Dot((<<v)[i], (<<v)[j]);
                (<<v)[i] -= (<<v)[j] * dot;
            }
            length : float = Normalize(*(<<v)[i], robust);
            if length < minLength {
                minLength = length;
            }
        }
        return minLength;
    }

    return 0;
}
