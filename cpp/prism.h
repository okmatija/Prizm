// nocommit remove the functions taking floats separately, and make curly braces work
// nocommit remove the space saving, format it normally since you can just include the absolute path
// nocommit Add the dimension suffixes everywhere!
// nocommit If there is no selection and you add files make them selected
// nocommit If you press the buttons with no selection make that noticable

#if 1  // Prism debug code begins (here to help you fold this in your IDE if you copied the contents directly)

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

template <typename T>
struct Vec2 {
    union { struct { T x; T y; }; T xy[2]; };

    Vec2() : x(0), y(0) {}
    Vec2(T x, T y) : x(x), y(y) {}

    template <typename T> friend std::ostream& operator<<(std::ostream& os, const Vec2<T>& v);

#ifdef PRISM_VEC2_CLASS_EXTRA
    PRISM_VEC2_CLASS_EXTRA
#endif
};

template <typename T> std::ostream& operator<<(std::ostream& os, const Vec2<T>& v) {
    os << v.x << " " << v.y;
    return os;
}

template <typename T>
struct Vec3 {
    union { struct { T x; T y; T z; }; T xyz[3]; };

    Vec3() : x(0), y(0), z(0) {}
    Vec3(T x, T y, T z) : x(x), y(y), z(z) {}

    template <typename T> friend std::ostream& operator<<(std::ostream& os, const Vec3<T>& v);

#ifdef PRISM_VEC3_CLASS_EXTRA
    PRISM_VEC3_CLASS_EXTRA
#endif
};

template <typename T> std::ostream& operator<<(std::ostream& os, const Vec3<T>& v) {
    os << v.x << " " << v.y << " " << v.z;
    return os;
}

template <typename T>
struct Vec4 {
    union { struct { T x; T y; T z; T w; }; T xyzw[4]; };

    Vec4() : x(0), y(0), z(0), w(0) {}
    Vec4(T x, T y, T z, T w) : x(x), y(y), z(z), w(w) {}

    template <typename T> friend std::ostream& operator<<(std::ostream& os, const Vec4<T>& v);

#ifdef PRISM_VEC4_CLASS_EXTRA
    PRISM_VEC4_CLASS_EXTRA
#endif
};

template <typename T> std::ostream& operator<<(std::ostream& os, const Vec4<T>& v) {
    os << v.x << " " << v.y << " " << v.z << " " << v.w;
    return os;
}

using V2 = Vec2<double>;
using V3 = Vec3<double>;
using V4 = Vec4<double>;
using V2f = Vec2<float>;
using V3f = Vec3<float>;
using V4f = Vec4<float>;

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

    //
    // State
    //////////////////////////////////////////////////////////////////////////
    
    // Current contents of the .obj file
    std::stringstream obj;

    // Number of hash characters on a line. 0 => writing geometry, 1 => writing an annotation, 2 => writing a comment ignored by Prism
    int hash_count = 0;

    //
    // Basic API. This API is small and verbose but it lets you do everything.
    //////////////////////////////////////////////////////////////////////////

    // By default write float data with enough precision to make it possible to round trip from float64 to decimal and back
    // Note: Prism 0.5.1 stores mesh data using float32, we will move to float64 so we can show coordinate labels at full precision
    Obj() {
        set_precision_max_digits10<double>();
    }

    // Start a new line and set hash_count to 0
    Obj& newline() {
        return ln();
    }

    // Add anything with an operator<< to the obj file.
    // Note: If you want to write '\n' or '#' use the newline(), annotation() or comment() functions since these properly update hash_count
    template <typename T> Obj& insert(T anything) {
        obj << " " << anything;
        return *this;
    }

    // Add a vector to the obj file
    template <typename T> Obj& vector(T x, T y)           { obj << " " << x << " " << y; return *this; }
    template <typename T> Obj& vector(T x, T y, T z)      { obj << " " << x << " " << y << " " << z; return *this; }
    template <typename T> Obj& vector(T x, T y, T z, T w) { obj << " " << x << " " << y << " " << z << " " << w; return *this; }
    template <typename T> Obj& vector(Vec2<T> v) { return insert(v); }
    template <typename T> Obj& vector(Vec3<T> v) { return insert(v); }
    template <typename T> Obj& vector(Vec4<T> v) { return insert(v); }

    // Add 'v' to the obj. Should be followed with a 2D/3D position vector
    // Note: You probably want to use vertex2, vertex3 instead
    Obj& vertex()                                         { return v(); }

    // Add 'p' to the obj followed by i.
    // If i > 0  the point refers to the ith added vertex
    // If i < 0  the point refers to ith preceeding vertex relative to this call
    // if i == 0 this is silent error
    Obj& point(int i = -1)                                { return pi(i); }

    // Add 'l' to the obj followed by i and j which should not be zero, see documentation for point()
    Obj& segment(int i = -2, int j = -1)                  { return li(i, j); }

    // Add 'f' to the obj followed by i, j and k which should not be zero, see documentation for point()
    Obj& triangle(int i = -3, int j = -2, int k = -1)     { return fi(i, j, k); }
    // TODO polygon variadic function

    Obj& annotation() { if (hash_count == 0) { obj << "#"; hash_count++; } return *this; }
    template <typename T> Obj&
    annotation(T a) { return annotation().insert(a); }

    Obj&                       comment()    { while (hash_count < 2) { obj << "#"; hash_count++; } return *this; }
    template <typename T> Obj& comment(T anything) { return comment().insert(anything); }

    // Write data in .obj format. Tip: Use format string "%05d" to write an int padded with zeros to width 5
    void write(std::string filename) const {
        std::ofstream file;
        file.open(filename, std::ofstream::out | std::ofstream::trunc);
        file << obj.str();
        file.close();
    }

    //
    // Advanced API. These are convenience functions
    //////////////////////////////////////////////////////////////////////////

    // Add an annotation. This short form also starts a newline
    Obj&                       an(std::string a = "") { return a == "" ? ln() : an(a); }
    template <typename T> Obj& an(T a)                { return annotation(a).ln(); }

    // Add a vertex/position.
    // template <typename T> Obj& vertex(T x,T y)     { return v(x,y); }
    // template <typename T> Obj& vertex(T x,T y,T z) { return v(x,y,z); }
    template <typename T> Obj& vertex(Vec2<T> xy)  { return v(xy); }
    template <typename T> Obj& vertex(Vec3<T> xyz) { return v(xyz); }

    // Add a point.
    // template <typename T> Obj& point(T x,T y)     { return p(x,y); }
    // template <typename T> Obj& point(T x,T y,T z) { return p(x,y,z); }
    template <typename T> Obj& point(Vec2<T> xy)  { return p(xy); }
    template <typename T> Obj& point(Vec3<T> xyz) { return p(xyz); }

    // Add a segment.
    // template <typename T> Obj& segment(T x1,T y1,      T x2,T y2)      { return l(x1,y1,    x2,y2);    }
    // template <typename T> Obj& segment(T x1,T y1,T z1, T x2,T y2,T z2) { return l(x1,y1,z1, x2,y2,z2); }
    template <typename T> Obj& segment(Vec2<T> xy1,    Vec2<T> xy2)    { return l(xy1,      xy2);      }
    template <typename T> Obj& segment(Vec3<T> xyz1,   Vec3<T> xyz2)   { return l(xyz1,     xyz2);     }

    // Add a triangle.
    // template <typename T> Obj& triangle(T x1,T y1,      T x2,T y2,      T x3,T y3)      { return f(x1,y1,    x2,y2,    x3,y3);    }
    // template <typename T> Obj& triangle(T x1,T y1,T z1, T x2,T y2,T z2, T x3,T y3,T z3) { return f(x1,y1,z1, x2,y2,z2, x3,y3,z3); }
    template <typename T> Obj& triangle(Vec2<T> xy1,    Vec2<T> xy2,    Vec2<T> xy3)    { return f(xy1,      xy2,      xy3);      }
    template <typename T> Obj& triangle(Vec3<T> xyz1,   Vec3<T> xyz2,   Vec3<T> xyz3)   { return f(xyz1,     xyz2,     xyz3);     }

    // Add a 2D polygon. Ex. (write a square) float square[4][2] = {{0,0},{1,0},{1,1},{0,1}}; polygon2(*square,4);
    template <typename T> Obj& polygon2(int point_count, T* xy_coords) { return poly_impl('f', point_count, xy_coords, 2); }
    template <typename T> Obj& polygon2(int point_count, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex2_variadic(point_count, p1, p2, p3, va);
        va_end(va);
        return fis(point_count);
    }

    // Add a 3D polygon.
    template <typename T> Obj& polygon3(int point_count, T* xyz_coords) { return poly_impl('f', point_count, xyz_coords, 3); }
    template <typename T> Obj& polygon3(int point_count, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex3_variadic(point_count, p1, p2, p3, va);
        va_end(va);
        return fis(point_count);
    }


    // Add a 2D polyline
    template <typename T> Obj& polyline2(int point_count, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex2_variadic(point_count, p1, p2, p3, va);
        va_end(va);
        return lis(point_count);
    }
	// nocommit implement polyline3

    template <typename T> Obj& insert(T* data, int count) { 
        if (data == nullptr || count <= 0) {
            return;
        }

        for (int i = 0; i < count; i++) {
            insert(data[i]);
        }

        return *this;
    }

    // Add a box.
    template <typename T> Obj& segment_box_min_max(Vec2<T> min, Vec2<T> max) {
        return v(5, min, Vec2<T>{max.x,min.y}, max, Vec2<T>{min.x,max.y}, min).lis(5);
        // return v(5, min, {max.x,min.y}, max, {min.x,max.y}, min).lis(5); // TODO Make this work..!
    }
    template <typename T> Obj& segment_box_centered(Vec2<T> center, T side_length) {
        return segment_box_min_max<T>(
            {center.x - side_length/2, center.y - side_length/2},
            {center.x + side_length/2, center.y + side_length/2});
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

    // Start a new line and set hash_count to 0
    Obj& ln() { obj << "\n"; hash_count = 0; return *this; }

    // Add positions.
    Obj&                       v()            { obj << "v"; return *this; }
    // template <typename T> Obj& v(T x,T y)     { return v().vector(x,y);   }
    // template <typename T> Obj& v(T x,T y,T z) { return v().vector(x,y,z); }
    template <typename T> Obj& v(Vec2<T> xy)  { return v().vector(xy);    }
    template <typename T> Obj& v(Vec3<T> xyz) { return v().vector(xyz);   }
    template <typename T> Obj& v(int point_count, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex2_variadic(point_count, p1, p2, p3, va);
        va_end(va);
        return *this;
    }
    template <typename T> Obj& v(int point_count, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex3_variadic(point_count, p1, p2, p3, va);
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
    Obj& li(int i = -2, int j = -1)        { return l().vector(i, j);   }
    Obj& lis(int count)                    { l(); for (int i = -count; i < 0; i++) insert(i); return *this; }
    Obj& lis(int count, int i, int j, ...) { li(i, j); va_list va; va_start(va, j); for (int n = 0; n < count-2; n++) insert(va_arg(va, int)); va_end(va); return *this; }

    // Add a triangle/polygon (indices only)
    Obj& f()                                      { obj << "f"; return *this; }
    Obj& fi(int i = -3, int j = -2, int k = -1)   { return f().vector(i, j, k); }
    Obj& fis(int count)                           { f(); for (int i = -count; i < 0; i++) insert(i); return *this; }
    Obj& fis(int count, int i, int j, int k, ...) { fi(i, j, k); va_list va; va_start(va, k); for (int n = 0; n < count-3; n++) insert(va_arg(va, int)); va_end(va); return *this; }

    // Add a point (position and index)
    // template <typename T> Obj& p(T x, T y)      { return v(x,y)  .ln().pi(); }
    // template <typename T> Obj& p(T x, T y, T z) { return v(x,y,z).ln().pi(); }
    template <typename T> Obj& p(Vec2<T> xy)    { return v(xy)   .ln().pi(); }
    template <typename T> Obj& p(Vec3<T> xyz)   { return v(xyz)  .ln().pi(); }

    // Add a segment/polyline (positions and indices)
    // template <typename T> Obj& l(T x1,T y1,      T x2,T y2     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().li(); }
    // template <typename T> Obj& l(T x1,T y1,T z1, T x2,T y2,T z2) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().li(); }
    template <typename T> Obj& l(Vec2<T> xy1,      Vec2<T> xy2 ) { return v(xy1)     .ln().v(xy2)     .ln().li(); }
    template <typename T> Obj& l(Vec3<T> xyz1,     Vec3<T> xyz2) { return v(xyz1)    .ln().v(xyz2)    .ln().li(); }

    // Add a triangle/polygon (positions and indices)
    // template <typename T> Obj& f(T x1,T y1,      T x2,T y2,      T x3,T y3     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().v(x3,y3)   .ln().fi(); }
    // template <typename T> Obj& f(T x1,T y1,T z1, T x2,T y2,T z2, T x3,T y3,T z3) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().v(x3,y3,z3).ln().fi(); }
    template <typename T> Obj& f(Vec2<T> xy1,    Vec2<T> xy2,    Vec2<T> xy3   ) { return v(xy1)     .ln().v(xy2)     .ln().v(xy3)     .ln().fi(); }
    template <typename T> Obj& f(Vec3<T> xyz1,   Vec3<T> xyz2,   Vec3<T> xyz3  ) { return v(xyz1)    .ln().v(xyz2)    .ln().v(xyz3)    .ln().fi(); }

    // Add a box.
    template <typename T> Obj& lbox(Vec2<T> min,    Vec2<T> max) { return segment_box_min_max(min, max); }
    template <typename T> Obj& lbox(Vec2<T> center, T side_length) { return segment_box_centered(center, side_length); }

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

    template <typename T> Obj& vertex2_variadic(int point_count, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, va_list va) {
        vertex(p1).newline().vertex(p2).newline().vertex(p3).newline();
        for (int i = 0; i < point_count-3; i++) {
            Vec2<T> pn = va_arg(va, Vec2<T>);
            vertex(pn).newline();
        }
        return *this;
    }

    template <typename T> Obj& vertex3_variadic(int point_count, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, va_list va) {
        vertex(p1).newline().vertex(p2).newline().vertex(p3).newline();
        for (int i = 0; i < point_count-3; i++) {
            Vec3<T> pn = va_arg(va, Vec3<T>);
            vertex(pn).newline();
        }
        return *this;
    }

#ifdef PRISM_OBJ_CLASS_EXTRA
    PRISM_OBJ_CLASS_EXTRA
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

void example_verbose_api(bool write_file) {
    Obj obj;
    obj.vertex().vector(V2{0., 0.}).newline().point().newline();
    obj.vertex().vector(V2{1., 0.}).newline().point().newline();
    obj.vertex().vector(V2{1., 1.}).newline().point().newline();
    obj.triangle().annotation("Tri(1,2,3)").newline();
    obj.vertex().vector(V2{3., 3.}).newline().point().annotation("Point 4").newline();

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

void example_basic_api(bool write_file) {
    Obj obj;
    obj.vertex(V2{0., 0.}).newline().point().newline();
    obj.vertex(V2{1., 0.}).newline().point().newline();
    obj.vertex(V2{1., 1.}).newline().point().newline();
    obj.triangle().annotation("Tri(1,2,3)").newline();
    obj.vertex(V2{3., 3.}).newline().point().annotation("Point 4").newline();

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
    obj.triangle(V2{0., 0.}, V2{1., 0.}, V2{1., 1.}).an("Tri2D 1");
    obj.point(V2{3., 3.}).an("Point 4");
    obj.polygon2(5, V2{10.,10.}, V2{11.,10.}, V2{11.,11.}, V2{10.,11.}, V2{10.,10.}).ln();
    obj.polyline2(5, V2{10.,10.}, V2{11.,10.}, V2{11.,11.}, V2{10.,11.}, V2{10.,10.}).ln();
    obj.polygon3( 5, V3{10.,10.,2.}, V3{11.,10.,2.}, V3{11.,11.,2.}, V3{10.,11.,2.}, V3{10.,10.,2.}).ln();

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
    obj.f(V2{0., 0.}, V2{1., 0.}, V2{1., 1.}).an("Tri(1,2,3)").p(V2{3., 3.}).an("Point 4");

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