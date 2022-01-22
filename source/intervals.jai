// Copyright Epic Games, Inc. All Rights Reserved.

// Parts of this file are based on:
// https://github.com/davideberly/GeometricTools (Distributed under the Boost Software License, Version 1.0.)

// The query finds overlap, whether a single point or an entire interval.
Intersection_Interval_Interval :: struct {
    intersect : bool;

    // Static queries (no motion of intervals over time). The number
    // of number of intersections is 0 (no overlap), 1 (intervals are
    // just touching), or 2 (intervals overlap in an interval). If
    // 'intersect' is false, numIntersections is 0 and 'overlap' is
    // set to [0,0]. If 'intersect' is true, numIntersections is
    // 1 or 2. When 1, 'overlap' is set to [x,x], which is degenerate
    // and represents the single intersection point x. When 2,
    // 'overlap' is the interval of intersection.
    numIntersections : s32 ;
    overlap : [2]float;

    Intersection_Type :: enum u8 {
        // No intersection.
        IS_EMPTY :: 0;

        // Intervals touch at an endpoint, [t0,t0].
        IS_POINT :: 1;

        // Finite-length interval of intersection, [t0,t1].
        IS_FINITE :: 2;

        // Semi-infinite interval of intersection, [t0,+infinity). The
        // result.overlap[0] is t0 and result.overlap[1] is +1 as a
        // message that the right endpoint is +infinity (you still need
        // the result.type to know this interpretation).
        IS_POSITIVE_FINITE :: 3;


        // Semi-infinite interval of intersection, (-infinity,t1]. The
        // result.overlap[0] is -1 as a message that the left endpoint is
        // -infinity (you still need the result.type to know this
        // interpretation). The result.overlap[1] is t1.
        IS_NEGATIVE_FINITE :: 4;

        // The dynamic queries all set the type to IS_DYNAMIC_QUERY because
        // the queries look for time of first and last contact.
        IS_DYNAMIC_QUERY :: 5;
    }

    type : Intersection_Type = .IS_EMPTY;

    // Dynamic queries (intervals moving with constant speeds). If
    // 'intersect' is true, the contact times are valid and
    //     0 <= firstTime <= lastTime,  firstTime <= maxTime
    // If 'intersect' is false, there are two cases reported. If the
    // intervals will intersect at firstTime > maxTime, the contact
    // times are reported just as when 'intersect' is true. However,
    // if the intervals will not intersect, then firstTime and
    // lastTime are both set to zero (invalid because 'intersect' is
    // false).
    firstTime, lastTime : float;
};

// Static queries where at least one interval is semiinfinite. The
// two types of semiinfinite intervals are [a,+infinity), which I call
// a positive-infinite interval, and (-infinity,a], which I call a
// negative-infinite interval.
find_intersect_interval_interval :: (finite : [2]float, a : float, isPositiveInfinite : bool) -> Intersection_Interval_Interval {
    result : Intersection_Interval_Interval;

    if (isPositiveInfinite) {
        if (finite[1] > a) {
            result.overlap[0] = max(finite[0], a);
            result.overlap[1] = finite[1];
            if (result.overlap[0] < result.overlap[1]) {
                result.numIntersections = 2;
                result.type = .IS_FINITE;
            } else {
                result.numIntersections = 1;
                result.type = .IS_POINT;
            }
        } else if (finite[1] == a) {
            result.numIntersections = 1;
            result.overlap[0] = a;
            result.overlap[1] = result.overlap[0];
            result.type = .IS_POINT;
        } else {
            result.numIntersections = 0;
            result.overlap[0] = 0;
            result.overlap[1] = 0;
            result.type = .IS_EMPTY;
        }
    } else { // is negative-infinite
        if (finite[0] < a) {
            result.overlap[0] = finite[0];
            result.overlap[1] = min(finite[1], a);
            if (result.overlap[0] < result.overlap[1]) {
                result.numIntersections = 2;
                result.type = .IS_FINITE;
            } else {
                result.numIntersections = 1;
                result.type = .IS_POINT;
            }
        } else if (finite[0] == a) {
            result.numIntersections = 1;
            result.overlap[0] = a;
            result.overlap[1] = result.overlap[0];
            result.type = .IS_POINT;
        } else {
            result.numIntersections = 0;
            result.overlap[0] = 0;
            result.overlap[1] = 0;
            result.type = .IS_EMPTY;
        }
    }

    result.intersect = (result.numIntersections > 0);
    return result;
}