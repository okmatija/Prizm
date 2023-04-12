#if 1  // Prism debug code begins (fold this in your IDE)

// By default enable the Unreal API
#ifndef PRISM_FOR_UNREAL
#define PRISM_FOR_UNREAL 1
#endif

#if PRISM_FOR_UNREAL
#include <VectorTypes.h>

#define PRISM_VEC2_CLASS_EXTRA                                                                          \
    Vec2(UE::Math::TVector2<T>   p) { x = p.X; y = p.Y; }                                               \
    Vec2(UE::Geometry::FVector2i p) { x = p.X; y = p.Y; }

#define PRISM_VEC3_CLASS_EXTRA                                                                          \
    Vec3(UE::Math::TVector<T>    p) { x = p.X; y = p.Y, z = p.Z; }                                      \
    Vec3(UE::Geometry::FVector3i p) { x = p.X; y = p.Y; z = p.Z; }

#define PRISM_VEC4_CLASS_EXTRA                                                                          \
    Vec4(UE::Math::TVector4<T> p)   { x = p.X; y = p.Y, z = p.Z; w = p.W; }

#define PRISM_OBJ_CLASS_EXTRA                                                                           \
    void write_fstring(const FString& filename)   { return write(TCHAR_TO_UTF8(*filename)); }

#endif // PRISM_FOR_UNREAL

#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>
#include <cassert>
#include <stdarg.h> // for va_arg(), va_list()
#include <iostream> // for std::cout, used in tests

namespace prism {

// Prism internal vector types.
// You can add use the PRISM_VEC2_CLASS_EXTRA, PRISM_VEC3_CLASS_EXTRA, PRISM_VEC4_CLASS_EXTRA macros
// (inspired by Dear ImGui) to define additional constructors and implicit casts to convert back and
// forth between the your custom math types and Vec2/Vec3/Vec4
template <typename T> struct Vec2;
template <typename T> struct Vec3;
template <typename T> struct Vec4;

void example_basic_api(bool write_file = false);    // An example of writing a file using the Basic API
void example_advanced_api(bool write_file = false); // An example of writing a file using the Advanced API
void example_concise_api(bool write_file = false);  // An example of writing a file using the Concise API (very short function names)
void example_printf_logging(bool write_file = false); // An example that demos using the prism::Obj struct for general printf debugging

// Overview of Prism obj extensions
//
// v 0 0 0 # Annotated origin # Text after a second hash is ignored
// v 1 0 0 ## This text is ignored, this vertex has no annotation
// v 0 1 0
// f -3 -2 -1 # This triangle is annotated
// v 0 0 1
// v 1 0 1
// v 0 1 1
// v 1 1 1
// f 4 5 6 7 # Triangle fan
// l -4 -3 -2 -2 # Triangle fan border
//
// Note: You can extend this class by defining a PRISM_OBJ_CLASS_EXTRA macros, this is mostly useful if you want to add
// functions which return an Obj& so you can chain calls. If you don't care about this then you can just make a regular
// since all the members of Obj are public.
struct Obj {

    std::stringstream obj;

    // By default write float data with enough precision to make it possible to round trip from float64 to decimal and back
    // Note: Prism 0.5.1 stores mesh data using float32, we will move to float64 so we can show coordinate labels at full precision
    Obj() { set_precision_max_digits10<double>(); }

    //
    // Basic API. This API is small and verbose but it lets you do everything.
    //

    Obj& newline() { return ln(); }

    template <typename T> Obj& insert(T anything)         { obj << " " << anything; return *this; }
    template <typename T> Obj& vector(T x, T y)           { obj << " " << x << " " << y; return *this; }
    template <typename T> Obj& vector(T x, T y, T z)      { obj << " " << x << " " << y << " " << z; return *this; }
    template <typename T> Obj& vector(T x, T y, T z, T w) { obj << " " << x << " " << y << " " << z << " " << z; return *this; }

    Obj& vertex()                                         { return v(); }
    Obj& point(int i = -1)                                { return pi(i); }
    Obj& segment(int i = -2, int j = -1)                  { return li(i, j); }
    Obj& triangle(int i = -3, int j = -2, int k = -1)     { return fi(i, j, k); }

    Obj&                       annotation()    { obj << "#"; return *this; }
    template <typename T> Obj& annotation(T a) { return annotation().insert(a); }

    // Write data in .obj format. Tip: Use format string "%05d" to write an int padded with zeros to width 5
    void write(std::string filename) const {
        std::ofstream file;
        file.open(filename, std::ofstream::out | std::ofstream::trunc);
        file << obj.str();
        file.close();
    }

    //
    // Advanced API. These are convenience functions
    //

    // Add an annotation. This short form also starts a newline
    Obj&                       an(std::string a = "") { return a == "" ? ln() : an(a); }
    template <typename T> Obj& an(T a)                { return annotation(a).ln(); }

    // Add a vector.
    template <typename T> Obj& vector(Vec2<T> p) { return vector(p.x,p.y); }
    template <typename T> Obj& vector(Vec3<T> p) { return vector(p.x,p.y,p.z); }
    template <typename T> Obj& vector(Vec4<T> p) { return vector(p.x,p.y,p.z,p.w); }

    // Add a vertex/position.
    template <typename T> Obj& vertex(T x,T y)     { return v(x,y); }
    template <typename T> Obj& vertex(T x,T y,T z) { return v(x,y,z); }
    template <typename T> Obj& vertex(Vec2<T> xy)  { return v(xy.x,xy.y); }
    template <typename T> Obj& vertex(Vec3<T> xyz) { return v(xyz.x,xyz.y,xyz.z); }

    // Add a point.
    template <typename T> Obj& point(T x,T y)     { return p(x,y); }
    template <typename T> Obj& point(T x,T y,T z) { return p(x,y,z); }
    template <typename T> Obj& point(Vec2<T> xy)  { return p(xy.x,xy.y); }
    template <typename T> Obj& point(Vec3<T> xyz) { return p(xyz.x,xyz.y,xyz.z); }

    // Add a segment.
    template <typename T> Obj& segment(T x1,T y1,      T x2,T y2)      { return l(x1,y1,    x2,y2);    }
    template <typename T> Obj& segment(T x1,T y1,T z1, T x2,T y2,T z2) { return l(x1,y1,z1, x2,y2,z2); }
    template <typename T> Obj& segment(Vec2<T> xy1,    Vec2<T> xy2)    { return l(xy1,      xy2);      }
    template <typename T> Obj& segment(Vec3<T> xyz1,   Vec3<T> xyz2)   { return l(xyz1,     xyz2);     }

    // Add a triangle.
    template <typename T> Obj& triangle(T x1,T y1,      T x2,T y2,      T x3,T y3)      { return f(x1,y1,    x2,y2,    x3,y3);    }
    template <typename T> Obj& triangle(T x1,T y1,T z1, T x2,T y2,T z2, T x3,T y3,T z3) { return f(x1,y1,z1, x2,y2,z2, x3,y3,z3); }
    template <typename T> Obj& triangle(Vec2<T> xy1,    Vec2<T> xy2,    Vec2<T> xy3)    { return f(xy1,      xy2,      xy3);      }
    template <typename T> Obj& triangle(Vec3<T> xyz1,   Vec3<T> xyz2,   Vec3<T> xyz3)   { return f(xyz1,     xyz2,     xyz3);     }

    // Add a 2D polygon. Ex. (write a square) float square[4][2] = {{0,0},{1,0},{1,1},{0,1}}; polygon2(*square,4);
    template <typename T> Obj& polygon2(int point_count, T* xy_coords) { return poly_impl('f', point_count, xy_coords, 2); }
    template <typename T> Obj& polygon2(int point_count, T x1,T y1,  T x2,T y2,  T x3,T y3, ...) {
        va_list va;
        va_start(va, y3);
        v2_impl(point_count, x1,y1, x2,y2, x3,y3, va);
        va_end(va);
        return fis(point_count);
    }
    // template <typename T> Obj& polygon2_Vec(int point_count, Vec2 xy1, Vec2 xy2, Vec2 xy3, ...) { } // TODO test this

    // Add a 3D polygon.
    template <typename T> Obj& polygon3(int point_count, T* xyz_coords) { return poly_impl('f', point_count, xyz_coords, 3); }
    template <typename T> Obj& polygon3(int point_count, T x1,T y1,T z1,  T x2,T y2,T z2,  T x3,T y3,T z3, ...) {
        va_list va;
        va_start(va, z3);
        v3_impl(point_count, x1,y1,z1, x2,y2,z2, x3,y3,z3, va);
        va_end(va);
        return fis(point_count);
    }


    // Add a 2D polyline
    template <typename T> Obj& polyline2(int point_count, T x1,T y1,  T x2,T y2,  T x3,T y3, ...) {
        va_list va;
        va_start(va, y3);
        v2_impl(point_count, x1,y1, x2,y2, x3,y3, va);
        va_end(va);
        return lis(point_count);
    }

    template <typename T> Obj& insert(T* data, int count) { 
        if (data == nullptr || count <= 0) {
            return;
        }

        for (int i = 0; i < count; i++) {
            insert(data[i]);
        }

        return *this;
    }

    // Add a box. // TODO @continue Refactor to use the multiple faces thing, and when you do this copy the annotation to each segment
    template <typename T> Obj& segment_box_min_max(Vec2<T> min, Vec2<T> max, std::string annotation = "") {
        const std::string& a = annotation;
        Vec2<T> p(min); Vec2<T> q(max.x, min.y); Vec2<T> r(max); Vec2<T> s(min.x, max.y);
        return l(p, q).an(a).l(q, r).an(a).l(r, s).an(a).l(s, p).annotation(a);
    }
    template <typename T> Obj& segment_box_centered(Vec2<T> center, T side_length, std::string annotation = "") {
        Vec2<T> min = center; min.x -= side_length/2; min.y -= side_length/2;
        Vec2<T> max = center; max.x += side_length/2; max.y += side_length/2;
        return segment_box_min_max(min, max, annotation);
    }

    // Set the precision used when writing floats to the obj.
    // Use the max_digits10 variant to round-trip from float to decimal and back
    // More details here: https://randomascii.wordpress.com/2012/02/11/they-sure-look-equal/
    Obj&                       set_precision(int n = 6)     { obj.precision(n); return *this; }
    template <typename T> Obj& set_precision_digits10()     { return set_precision(std::numeric_limits<T>::digits10); }
    template <typename T> Obj& set_precision_max_digits10() { return set_precision(std::numeric_limits<T>::max_digits10); }

    //
    // Concise API.
    //

    Obj& ln() { obj << "\n"; return *this; }

    // Add positions.
    Obj&                       v()            { obj << "v"; return *this; }
    template <typename T> Obj& v(T x,T y)     { return v().vector(x,y);   }
    template <typename T> Obj& v(T x,T y,T z) { return v().vector(x,y,z); }
    template <typename T> Obj& v(Vec2<T> xy)  { return v().vector(xy);    }
    template <typename T> Obj& v(Vec3<T> xyz) { return v().vector(xyz);   }
    template <typename T> Obj& v2(int point_count, T x1,T y1,  T x2,T y2,  T x3,T y3, ...) {
        va_list va;
        va_start(va, y3);
        v2_impl(point_count, x1,y1, x2,y2, x3,y3, va);
        va_end(va);
        return *this;
    }
    template <typename T> Obj& v3(int point_count, T x1,T y1,T z1,  T x2,T y2,T z2,  T x3,T y3,T z3, ...) {
        va_list va;
        va_start(va, z3);
        v3_impl(point_count, x1,y1,z1, x2,y2,z2, x3,y3,z3, va);
        va_end(va);
        return *this;
    }

    // TODO Add normals.

    // TODO Add tangents.

    // TODO Add groups.

    // Add a point (index only)
    Obj& p()            { obj << "p"; return *this;  }
    Obj& pi(int i = -1) { return p().insert(i);      }

    // Add a segment/polyline (indices only)
    Obj& l()                               { obj << "l"; return *this; }
    Obj& li(int i = -2, int j = -1)        { return l().vector(i,j);   }
    Obj& lis(int count)                    { l(); for (int i = -count; i < 0; i++) insert(i); return *this; }
    Obj& lis(int count, int i, int j, ...) { li(i, j); va_list va; va_start(va, j); for (int n = 0; n < count-2; n++) insert(va_arg(va, int)); va_end(va); return *this; }

    // Add a triangle/polygon (indices only)
    Obj& f()                                      { obj << "f"; return *this; }
    Obj& fi(int i = -3, int j = -2, int k = -1)   { return f().vector(i,j,k); }
    Obj& fis(int count)                           { f(); for (int i = -count; i < 0; i++) insert(i); return *this; }
    Obj& fis(int count, int i, int j, int k, ...) { fi(i, j, k); va_list va; va_start(va, k); for (int n = 0; n < count-3; n++) insert(va_arg(va, int)); va_end(va); return *this; }

    // Add a point (position and index)
    template <typename T> Obj& p(T x, T y)      { return v(x,y)  .ln().pi(); }
    template <typename T> Obj& p(T x, T y, T z) { return v(x,y,z).ln().pi(); }
    template <typename T> Obj& p(Vec2<T> xy)    { return v(xy)   .ln().pi(); }
    template <typename T> Obj& p(Vec3<T> xyz)   { return v(xyz)  .ln().pi(); }

    // Add a segment/polyline (positions and indices)
    template <typename T> Obj& l(T x1,T y1,      T x2,T y2     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().li(); }
    template <typename T> Obj& l(T x1,T y1,T z1, T x2,T y2,T z2) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().li(); }
    template <typename T> Obj& l(Vec2<T> xy1,      Vec2<T> xy2 ) { return v(xy1)     .ln().v(xy2)     .ln().li(); }
    template <typename T> Obj& l(Vec3<T> xyz1,     Vec3<T> xyz2) { return v(xyz1)    .ln().v(xyz2)    .ln().li(); }

    // Add a triangle/polygon (positions and indices)
    template <typename T> Obj& f(T x1,T y1,      T x2,T y2,      T x3,T y3     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().v(x3,y3)   .ln().fi(); }
    template <typename T> Obj& f(T x1,T y1,T z1, T x2,T y2,T z2, T x3,T y3,T z3) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().v(x3,y3,z3).ln().fi(); }
    template <typename T> Obj& f(Vec2<T> xy1,    Vec2<T> xy2,    Vec2<T> xy3   ) { return v(xy1)     .ln().v(xy2)     .ln().v(xy3)     .ln().fi(); }
    template <typename T> Obj& f(Vec3<T> xyz1,   Vec3<T> xyz2,   Vec3<T> xyz3  ) { return v(xyz1)    .ln().v(xyz2)    .ln().v(xyz3)    .ln().fi(); }

    // Add a box.
    template <typename T> Obj& lbox(Vec2<T> min,    Vec2<T> max,   std::string annotation = "") { return segment_box_min_max(min, max, annotation); }
    template <typename T> Obj& lbox(Vec2<T> center, T side_length, std::string annotation = "") { return segment_box_centered(center, side_length, annotation); }

    // TODO fbox, l/frect, l/faabb, l/fcircle, l/fball, l/fsphere, l/ftetrahedron, polyline, star (defined to neatly fit into a box or a circle with the same number of points)
    // TODO Add functions corresponding to command annotations e.g., to set item state/prism application state
    // TODO Template the above on the annotation type?

    // Implementation methods. Not private but you probably don't want to use them

    template <typename T> Obj& poly_impl(char directive, int point_count, T* coord_buffer, uint8_t point_dimension) {
        if (point_count <= 0) {
            return;
        }

        for (int i = 0; i < point_count; i++) {
            v();
            for (int d = 0; d < point_dimension; d++) {
                insert(coord_buffer[i * point_dimension + d]).ln();
            }
        }

        directive == 'f' ? f() : l();
        for (int i = -point_count; i < 0; i++) {
            insert(i);
        }

        // No newline so the caller can add an annotation

        return *this;
    }

    template <typename T> Obj& v2_impl(int point_count, T x1,T y1,  T x2,T y2,  T x3,T y3, va_list va) {
        v(x1,y1).ln().v(x2,y2).ln().v(x3,y3).ln();
        for (int i = 0; i < point_count-3; i++) {
            T xn = va_arg(va, T);
            T yn = va_arg(va, T);
            v(xn, yn).ln();
        }
        return *this;
    }

    template <typename T> Obj& v3_impl(int point_count, T x1,T y1,T z1,  T x2,T y2,T z2,  T x3,T y3,T z3,  va_list va) {
        v(x1,y1,z1).ln().v(x2,y2,z2).ln().v(x3,y3,z3).ln();
        for (int i = 0; i < point_count-3; i++) {
            T xn = va_arg(va, T);
            T yn = va_arg(va, T);
            T zn = va_arg(va, T);
            v(xn,yn,zn).ln();
        }
        return *this;
    }

#ifdef PRISM_OBJ_CLASS_EXTRA
    PRISM_OBJ_CLASS_EXTRA
#endif
};

template <typename T>
struct Vec2 {
    union { struct { T x; T y; }; T xy[2]; };

    Vec2() : x(0), y(0) {}
    Vec2(T x, T y) : x(x), y(y) {}

#ifdef PRISM_VEC2_CLASS_EXTRA
    PRISM_VEC2_CLASS_EXTRA
#endif
};

template <typename T>
struct Vec3 {
    union { struct { T x; T y; T z; }; T xyz[3]; };

    Vec3() : x(0), y(0), z(0) {}
    Vec3(T x, T y, T z) : x(x), y(y), z(z) {}

#ifdef PRISM_VEC3_CLASS_EXTRA
    PRISM_VEC3_CLASS_EXTRA
#endif
};

template <typename T>
struct Vec4 {
    union { struct { T x; T y; T z; T w; }; T xyzw[4]; };

    Vec4() : x(0), y(0), z(0), w(0) {}
    Vec4(T x, T y, T z, T w) : x(x), y(y), z(z), w(w) {}

#ifdef PRISM_VEC4_CLASS_EXTRA
    PRISM_VEC4_CLASS_EXTRA
#endif
};

namespace {
bool check_and_or_write(const Obj& obj, std::string wanted, std::string test_name, bool write_file) {

    bool passed = true;

    std::string got = obj.obj.str();
    if (wanted == got) {
        std::cout << "Test " << test_name << "() PASSED..." << std::endl;
    } else {
        std::cout << "Test " << test_name << "() FAILED..." << std::endl;
        std::cout << "Wanted:\n" << wanted << "\nGot:\n" << got << std::endl;
        passed = false;
    }

    std::string filename = "prism_" + test_name + ".obj";
    if (write_file || !passed) {
        obj.write(filename);
        std::cout << "  Wrote " << filename << std::endl;
    } else {
        std::cout << "  Write " << filename << " by passing true to the test function" << std::endl;
    }

    return passed;
}
}

void example_basic_api(bool write_file) {
    Obj obj;
    obj.vertex().vector(0., 0.).newline().point().newline();                       // "v 0 0\np -1\n"
    obj.vertex().vector(1., 0.).newline().point().newline();                       // "v 1 0\np -1\n"
    obj.vertex().vector(1., 1.).newline().point().newline();                       // "v 1 1\np -1\n"
    obj.triangle().annotation("Tri(1,2,3)").newline();                             // "f -3 -2 -1# Tri(1,2,3)\n"
    obj.vertex().vector(3., 3.).newline().point().annotation("Point 4").newline(); // "v 3 3\np -1# Point 4"

    std::string wanted = R"DONE(v 0 0
p -1
v 1 0
p -1
v 1 1
p -1
f -3 -2 -1# Tri(1,2,3)
v 3 3
p -1# Point 4
)DONE";

    assert(check_and_or_write(obj, wanted, "example_basic_api", write_file));
}

void example_advanced_api(bool write_file) {
    Obj obj;
    obj.triangle(0., 0., 1., 0., 1., 1.).an("Tri2D 1");
    obj.point(3., 3.).an("Point 4");
    obj.polygon2( 5, 10.,10.,    11.,10.,    11.,11.,    10.,11.,    10.,10.).ln();
    obj.polyline2(5, 10.,10.,    11.,10.,    11.,11.,    10.,11.,    10.,10.).ln();
    obj.polygon3( 5, 10.,10.,2., 11.,10.,2., 11.,11.,2., 10.,11.,2., 10.,10.,2.).ln();

    std::string wanted = R"DONE(v 0 0
v 1 0
v 1 1
f -3 -2 -1# Tri2D 1
v 3 3
p -1# Point 4
v 10 10
v 11 10
v 11 11
v 10 11
v 10 10
f -5 -4 -3 -2 -1
v 10 10
v 11 10
v 11 11
v 10 11
v 10 10
l -5 -4 -3 -2 -1
v 10 10 2
v 11 10 2
v 11 11 2
v 10 11 2
v 10 10 2
f -5 -4 -3 -2 -1
)DONE";

    assert(check_and_or_write(obj, wanted, "example_advanced_api", write_file));
}

void example_concise_api(bool write_file) {
    Obj obj; // If we didn't need to pass this variable to the check function below we could use Obj() in the line below (and also add a `write` call to create and log a file in one line)
    obj.f(0., 0., 1., 0., 1., 1.).an("Tri(1,2,3)").p(3., 3.).an("Point 4");

    std::string wanted = R"DONE(v 0 0
v 1 0
v 1 1
f -3 -2 -1# Tri(1,2,3)
v 3 3
p -1# Point 4
)DONE";

    assert(check_and_or_write(obj, wanted, "example_concise_api", write_file));
}

void example_printf_logging(bool write_file) {
    Obj obj;
    obj.insert("some int = ").insert(5).ln();
    if (true) {
        obj.insert("condition passed on line ").insert(__LINE__).ln();
    }

    // Do not test this function, since __LINE__ above will result in frequent breaking changes
    if (write_file) {
        obj.write("prism_example_printf_logging.obj");
    }
}


} // end namespace prism

#ifdef PRISM_FOR_UNREAL
#undef PRISM_FOR_UNREAL
#endif

#ifdef PRISM_VEC2_CLASS_EXTRA
#undef PRISM_VEC2_CLASS_EXTRA
#endif

#ifdef PRISM_VEC3_CLASS_EXTRA
#undef PRISM_VEC3_CLASS_EXTRA
#endif

#ifdef PRISM_VEC4_CLASS_EXTRA
#undef PRISM_VEC4_CLASS_EXTRA
#endif

#ifdef PRISM_OBJ_CLASS_EXTRA
#undef PRISM_OBJ_CLASS_EXTRA
#endif

#endif // Prism debug code ends