// Copyright Epic Games, Inc. All Rights Reserved.

FLOAT_MACHINE_EPSILON :: 0.0001; // @FIXME

almost_equal :: (a : float, b : float, epsilon : float = 10 * FLOAT_MACHINE_EPSILON, scale : float = 1.0) -> bool {
    // exact comparison allows to handle infinities and prevents from getting FPE triggered by (inf - inf)
    exactly_equal := (a == b);
    return exactly_equal || (abs(a - b) < epsilon * (scale + abs(a) + abs(b)));
}

angle :: (a : Vector3, b : Vector3, normalize : bool = false) -> float {
    if normalize {
        // @Cleanup make this #if and use a = normalize(a), currently this looks like a @CompilerBug
        normalize_or_z_axis(*a);
        normalize_or_z_axis(*b);
        // a = normalize(a);
        // b = normalize(b);
    }
    // Following https://people.eecs.berkeley.edu/~wkahan/MathH110/Cross.pdf
    return 2 * atan2(length(a - b), length(a + b));
}

angle_unit :: #bake_arguments angle(normalize = false);

cwise_max :: (v : Vector3) -> float, int {
    max_component := v.component[0];
    max_index     := 0;
    for d : 0..2 {
        if v.component[d] > max_component {
            max_component = v.component[d];
            max_index     = d;
        }
    }
    return max_component, max_index;
}

cwise_min :: (v : Vector3) -> float, int {
    min_component := v.component[0];
    min_index     := 0;
    for d : 0..2 {
        if v.component[d] < min_component {
            min_component = v.component[d];
            min_index     = d;
        }
    }
    return min_component, min_index;
}

transform_point :: (point : Vector3, transform : Matrix4) -> Vector3 {
    return (transform * make_vector4(point, 1.)).xyz;
}

normalize :: (using v: *Vector2, epsilon := 0, fallback := Vector2.{0, 0}) -> float {
    sq := sqrt(x*x + y*y);
    if sq == 0 {
        <<v = fallback;
        return sq;
    }

    factor := 1.0 / sq;
    x *= factor;
    y *= factor;

    return sq;
} @NoProfile

normalize_or_x_axis :: inline (using v: *Vector2) -> float {
    return normalize(v, fallback=.{x=1});
} @NoProfile

Tuple2 :: struct (T : Type) {
    x, y : T;
#place x;
    component : [2] T = ---;
}

Tuple3 :: struct (T : Type) {
    x, y, z : T;
#place x;
    component : [3] T = ---;
}

make_Tuple2 :: (x : $T, y : T) -> Tuple2(T) {
    result : Tuple2(T) = ---;
    result.x = x;
    result.y = y;
    return result;
}

make_Tuple3 :: (x : $T, y : T, z : T) -> Tuple3(T) {
    result : Tuple3(T) = ---;
    result.x = x;
    result.y = y;
    result.z = z;
    return result;
}

operator == :: (a : $T/Tuple2, b : T) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator == :: (a : $T/Tuple3, b : T) -> bool {
    return a.x == b.x && a.y == b.y && a.z == b.z;
}