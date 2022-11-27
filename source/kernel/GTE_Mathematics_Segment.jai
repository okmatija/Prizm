// Ported from GeometricTools/GTE/Mathematics/Segment.h

Segment3_Centered :: struct {
    center : Vector3;
    direction : Vector3;
    extent : float;
}

SetCenteredForm :: (center : Vector3, direction : Vector3, extent : float) -> Segment3 {
    using result : Segment3 = ---;
    p[0] = center - extent * direction;
    p[1] = center + extent * direction;
    return result;
}

GetCenteredForm :: (using segment : Segment3) -> Segment3_Centered {
    using result : Segment3_Centered = ---;
    center = cast(float).5 * (p[0] + p[1]);
    direction = p[1] - p[0];
    extent = cast(float).5 * normalize(*direction);
    return result;
}
