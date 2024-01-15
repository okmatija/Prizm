FLOAT_MACHINE_EPSILON :: 0.0001; // @FIXME

almost_equal :: (a : float, b : float, epsilon : float = 10 * FLOAT_MACHINE_EPSILON, scale : float = 1.0) -> bool {
    // exact comparison allows to handle infinities and prevents from getting FPE triggered by (inf - inf)
    exactly_equal := (a == b);
    return exactly_equal || (abs(a - b) < epsilon * (scale + abs(a) + abs(b)));
}

almost_equal :: (a : Vector3, b : Vector3, epsilon : float = 10 * FLOAT_MACHINE_EPSILON, scale : float = 1.0) -> bool {
    return almost_equal(a.x, b.x) && almost_equal(a.y, b.y) && almost_equal(a.z, b.z);
}

angle :: (a : Vector3, b : Vector3, do_normalize : bool = false) -> float {
    if do_normalize {
        // @Cleanup make this #if and use a = normalize(a), currently this looks like a @CompilerBug
        normalize(*a, fallback=.{z=1});
        normalize(*b, fallback=.{z=1});
        // a = normalize(a);
        // b = normalize(b);
    }
    // Following https://people.eecs.berkeley.edu/~wkahan/MathH110/Cross.pdf
    return 2 * atan2(length(a - b), length(a + b));
}

angle_unit :: #bake_arguments angle(do_normalize = false);

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
        v.* = fallback;
        return sq;
    }

    factor := 1.0 / sq;
    x *= factor;
    y *= factor;

    return sq;
} @NoProfile

Tuple2i :: Tuple2(int);
Tuple3i :: Tuple2(int);

Tuple2 :: struct (T : Type) {
    x, y : T;

#place x;
    component : [2] T = ---;

#place x; i : T = ---;
#place y; j : T = ---;
}

Tuple3 :: struct (T : Type) {
    x, y, z : T;

#place x; component : [3] T = ---;

#place x; i : T = ---;
#place y; j : T = ---;
#place z; k : T = ---;
}

// @Cleanup: Replace these make_* functions with struct literals with non-const elements

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

operator - :: (a : $T/Tuple2, b : T) -> T {
    result : T = ---;
    result.x = a.x - b.x;
    result.y = a.y - b.y;
    return result;
}

operator == :: (a : $T/Tuple2, b : T) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator == :: (a : $T/Tuple3, b : T) -> bool {
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

// Based on boost::hash_combine
hash_combine :: (lhs : u32, rhs : u32) -> u32 {
    lhs ^= rhs + 0x9e3779b9 + (lhs << 6) + (lhs >> 2);
    return lhs;
}

hash_Tuple2i :: (key : Tuple2i) -> u32 {
    return hash_combine(get_hash(key.x), get_hash(key.y));
}

ensure_finite :: (input : Vector3, fallback : Vector3 = .{0,0,0}) -> Vector3, bool {
    using result : Vector3 = input;

    finite := true;

    if !is_finite(x) {
        x = fallback.x;
        finite = false;
    }

    if !is_finite(y) {
        y = fallback.y;
        finite = false;
    }

    if !is_finite(z) {
        z = fallback.z;
        finite = false;
    }

    return result, finite;
}

ensure_finite :: (input : Vector2, fallback : Vector2 = .{0,0}) -> Vector2, bool {
    using result : Vector2 = input;

    finite := true;

    if !is_finite(x) {
        x = fallback.x;
        finite = false;
    }

    if !is_finite(y) {
        y = fallback.y;
        finite = false;
    }

    return result, finite;
}
