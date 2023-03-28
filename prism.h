#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>

namespace prism {

// Prism internal vector types. For now we hardcode constructors from Unreal types, but eventually this will need to be
// added by defining PRISM_VEC2_CLASS_EXTRA, PRISM_VEC3_CLASS_EXTRA, PRISM_VEC4_CLASS_EXTRA respectively. These macros
// are inspired by ImGui and are used to define additional constructors and implicit casts to convert back and forth
// between the user's custom math types and Vec2/Vec3/Vec4
template <typename T> struct Vec2;
template <typename T> struct Vec3;
template <typename T> struct Vec4;

void example_basic_api();    // An example of writing a file using the Basic API
void example_advanced_api(); // Same as example_basic_api but using the Advanced API
void example_concise_api();  // Same as example_advanced_api but using the Concise API
//void example_entire_api(); // An example which shows all features of the API

struct Obj {

    std::stringstream obj;

    // By default write float data with enough precision to make it possible to round trip from float64 to decimal and back
    // Note: Prism 0.5.1 stores mesh data using float32, we will move to float64 so we can show coordinate labels at full precision
    Obj() { set_precision_max_digits10<double>(); }

    //
    // Basic API. This API is small and verbose but it lets you do everything.
    //

    Obj& newline() { return ln(); }

    template <typename T> Obj& operator<<(T anything)     { obj << anything; return *this; }
    template <typename T> Obj& vector(T x, T y)           { obj << x << " " << y; return *this; }
    template <typename T> Obj& vector(T x, T y, T z)      { obj << x << " " << y << " " << z; return *this; }
    template <typename T> Obj& vector(T x, T y, T z, T w) { obj << x << " " << y << " " << z << " " << z; return *this; }

    Obj& vertex()                                         { return v(); }
    Obj& point(int i = -1)                                { return p(i); }
    Obj& segment(int i = -2, int j = -1)                  { return l(i, j); }
    Obj& triangle(int i = -3, int j = -2, int k = -1)     { return f(i, j, k); }

    Obj& annotation(std::string a = "")                   { if (a != "") { obj << "# " << a; } return *this; }

    // Write data in .obj format
    // Unreal tip: TCHAR_TO_UTF8(*FString::Printf(TEXT("E:\\Debug\\Debug_%05d.obj"), Counter)));
    void write(std::string filename) {
        std::ofstream file;
        file.open(filename, std::ofstream::out | std::ofstream::trunc);
        file << obj.str();
        file.close();
    }

    //
    // Advanced API. These are convenience functions
    //

    // Add an annotation. This short form also starts a newline
    Obj& an(std::string a = "") { return a == "" ? ln() : annotation(a).ln(); }

    // Add a vector.
    template <typename T> Obj& vector(Vec2<T> p) { return vector(p.x,p.y); }
    template <typename T> Obj& vector(Vec3<T> p) { return vector(p.x,p.y,p.z); }
    template <typename T> Obj& vector(Vec4<T> p) { return vector(p.x,p.y,p.z,p.w); }

    // Add a vertex.
    template <typename T> Obj& vertex(T x, T y)      { return v(x,y); }
    template <typename T> Obj& vertex(T x, T y, T z) { return v(x,y,z); }
    template <typename T> Obj& vertex(Vec2<T> p)     { return v(p.x,p.y); }
    template <typename T> Obj& vertex(Vec3<T> p)     { return v(p.x,p.y,p.z); }

    // Add a point.
    template <typename T> Obj& point(T x, T y)      { return p(x,y); }
    template <typename T> Obj& point(T x, T y, T z) { return p(x,y,z); }
    template <typename T> Obj& point(Vec2<T> p)     { return p(p.x,p.y); }
    template <typename T> Obj& point(Vec3<T> p)     { return p(p.x,p.y,p.z); }

    // Add a segment.
    template <typename T> Obj& segment(T x1,T y1,      T x2,T y2)      { return l(x1,y1,    x2,y2);    }
    template <typename T> Obj& segment(T x1,T y1,T z1, T x2,T y2,T z2) { return l(x1,y1,z1, x2,y2,z2); }
    template <typename T> Obj& segment(Vec2<T> p, Vec2<T> q)           { return l(p, q); }
    template <typename T> Obj& segment(Vec3<T> p, Vec3<T> q)           { return l(p, q); }

    // Add a triangle.
    template <typename T> Obj& triangle(T x1,T y1,      T x2,T y2,      T x3,T y3)      { return f(x1,y1,    x2,y2,    x3,y3); }
    template <typename T> Obj& triangle(T x1,T y1,T z1, T x2,T y2,T z2, T x3,T y3,T z3) { return f(x1,y1,z1, x2,y2,z2, x3,y3,z3); }
    template <typename T> Obj& triangle(Vec2<T> p, Vec2<T> q, Vec2<T> r)                { return f(p, q, r); }
    template <typename T> Obj& triangle(Vec3<T> p, Vec3<T> q, Vec3<T> r)                { return f(p, q, r); }

    // Add a box.
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
                          Obj& set_precision(int n = 6)     { obj.precision(n); return *this; }
    template <typename T> Obj& set_precision_digits10()     { return set_precision(std::numeric_limits<T>::digits10); }
    template <typename T> Obj& set_precision_max_digits10() { return set_precision(std::numeric_limits<T>::max_digits10); }

    //
    // Concise API. These are convenience functions
    //

    Obj& ln() { obj << "\n"; return *this; }

    // Add a vertex.
                          Obj& v()            { obj << "v "; return *this; }
    template <typename T> Obj& v(T x,T y)     { return v().vector(x,y); }
    template <typename T> Obj& v(T x,T y,T z) { return v().vector(x,y,z); }
    template <typename T> Obj& v(Vec2<T> p)   { return v().vector(p); }
    template <typename T> Obj& v(Vec3<T> p)   { return v().vector(p); }

    // Add a point.
                          Obj& p(int I = -1)    { obj << "p " << I; return *this; }
    template <typename T> Obj& p(T x, T y)      { return v(x,y)  .ln().p(); }
    template <typename T> Obj& p(T x, T y, T z) { return v(x,y,z).ln().p(); }
    template <typename T> Obj& p(Vec2<T> p)     { return v(p)    .ln().p(); }
    template <typename T> Obj& p(Vec3<T> p)     { return v(p)    .ln().p(); }

    // Add a segment.
                          Obj& l(int I = -2,     int J = -1    ) { obj << "l " << I << " " << J; return *this;   }
    template <typename T> Obj& l(T x1,T y1,      T x2,T y2     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().l(); }
    template <typename T> Obj& l(T x1,T y1,T z1, T x2,T y2,T z2) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().l(); }
    template <typename T> Obj& l(Vec2<T> p,      Vec2<T> q     ) { return v(p)       .ln().v(q)       .ln().l(); }
    template <typename T> Obj& l(Vec3<T> p,      Vec3<T> q     ) { return v(p)       .ln().v(q)       .ln().l(); }

    // Add a triangle.
                          Obj& f(int I = -3,     int J = -2,     int K = -1    ) { obj << "f " << I << " " << J << " " << K; return *this;        }
    template <typename T> Obj& f(T x1,T y1,      T x2,T y2,      T x3,T y3     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().v(x3,y3)   .ln().f(); }
    template <typename T> Obj& f(T x1,T y1,T z1, T x2,T y2,T Z2, T x3,T y3,T z3) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().v(x3,y3,z3).ln().f(); }
    template <typename T> Obj& f(Vec2<T> p,      Vec2<T> q,      Vec2<T> r     ) { return v(p)       .ln().v(q)       .ln().v(r)       .ln().f(); }
    template <typename T> Obj& f(Vec3<T> p,      Vec3<T> q,      Vec3<T> r     ) { return v(p)       .ln().v(q)       .ln().v(r)       .ln().f(); }

    // Add a box.
    template <typename T> Obj& lbox(Vec2<T> min,    Vec2<T> max,   std::string annotation = "") { return segment_box_min_max(min, max, annotation); }
    template <typename T> Obj& lbox(Vec2<T> center, T side_length, std::string annotation = "") { return segment_box_centered(center, side_length, annotation); }

    // TODO fbox, l/frect, l/faabb, l/fcircle, l/fball, l/fsphere, l/ftetrahedron, polyline, star (defined to neatly fit into a box or a circle with the same number of points)
    // TODO Add functions corresponding to command annotations e.g., to set item state/prism application state
};

template <typename T>
struct Vec2 {
    union { struct { T x; T y; }; T xy[2]; };

    Vec2() : x(0), y(0) {}

    // Eventually these will need to be in the macro below
    Vec2(TVector2<T> p) { x = p.X; y = p.Y; }
    Vec2(FVector2i   p) { x = p.X; y = p.Y; }

#ifdef PRISM_VEC2_CLASS_EXTRA
    PRISM_VEC2_CLASS_EXTRA
#endif
};

template <typename T>
struct Vec3 {
    union { struct { T x; T y; T z; }; T xyz[3]; };

    Vec3() : x(0), y(0), z(0) {}

    // Eventually these will need to be in the macro below
    Vec3(TVector<T> p) { x = p.X; y = p.Y, z = p.Z; }
    Vec3(FVector3i  p) { x = p.X; y = p.Y; z = p.Z; }

#ifdef PRISM_VEC3_CLASS_EXTRA
    PRISM_VEC3_CLASS_EXTRA
#endif
};

template <typename T>
struct Vec4 {
    union { struct { T x; T y; T z; T w; }; T xyzw[4]; };

    Vec4() : x(0), y(0), z(0), w(0) {}

    // Eventually these will need to be in the macro below
    Vec4(TVector4<T> p) { x = p.X; y = p.Y, z = p.Z; w = p.W; } 

#ifdef PRISM_VEC4_CLASS_EXTRA
    PRISM_VEC4_CLASS_EXTRA
#endif
};

void example_basic_api() {
    // The comments show the strings that are written to the obj file when write is called
    Obj obj;
    obj.vertex().vector(0., 0.).newline().point().newline();                       // "v 0 0\np -1\n"
    obj.vertex().vector(1., 0.).newline().point().newline();                       // "v 1 0\np -1\n"
    obj.vertex().vector(1., 1.).newline().point().newline();                       // "v 1 1\np -1\n"
    obj.triangle().annotation("Tri(1,2,3)").newline();                             // "f -3 -2 -1# Tri(1,2,3)\n"
    obj.vertex().vector(3., 3.).newline().point().annotation("Point 4").newline(); // "v 3 3\np -1# Point 4"
    obj.write("prism_example_basic_api.obj");
}

void example_advanced_api() {
    Obj obj;
    obj.triangle(0., 0., 1., 0., 1., 1.).an("Tri(1,2,3)");
    obj.point(3., 3.).an("Point 4");
    obj.write("prism_example_advanced_api.obj");
}

void example_concise_api() {
    Obj obj;
    obj.f(0., 0., 1., 0., 1., 1.).an("Tri(1,2,3)");
    obj.p(3., 3.).an("Point 4");
    obj.write("prism_example_concise_api.obj");
}

//void example_entire_api() {
//    Obj obj;
//    obj << "# Incomplete\n";
//    obj.write("prism_example_entire_api.obj");
//}


} // end namespace prism
