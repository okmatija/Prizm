
#include <VectorTypes.h> // Unreal

#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>
#include <stdarg.h> // for va_arg(), va_list()

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
void example_printf_logging();  // An example that demos using the prism::Obj struct for general printf debugging

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
// f 4 5 6 7 # This face will be triangle fan-ated with this annotation on each triangle
//
struct Obj {

    std::stringstream obj;

    // By default write float data with enough precision to make it possible to round trip from float64 to decimal and back
    // Note: Prism 0.5.1 stores mesh data using float32, we will move to float64 so we can show coordinate labels at full precision
    Obj() { set_precision_max_digits10<double>(); }

    //
    // Basic API. This API is small and verbose but it lets you do everything.
    //

    Obj& newline() { return ln(); }

    // Note the preceeding spaces which makes the functions each to cascade e.g., to write a polygon face???
    template <typename T> Obj& insert(T anything)         { obj << " " << anything; return *this; } // Useful for strings, scalars or anything with operator<<
    template <typename T> Obj& vector(T x, T y)           { obj << " " << x << " " << y; return *this; }
    template <typename T> Obj& vector(T x, T y, T z)      { obj << " " << x << " " << y << " " << z; return *this; }
    template <typename T> Obj& vector(T x, T y, T z, T w) { obj << " " << x << " " << y << " " << z << " " << z; return *this; }

    Obj& vertex()                                         { return v(); }
    Obj& point(int i = -1)                                { return p(i); }
    Obj& segment(int i = -2, int j = -1)                  { return l(i, j); }
    Obj& triangle(int i = -3, int j = -2, int k = -1)     { return f(i, j, k); }

    // TODO annotation(foo).annotation(bar) will NOT show bar in prism. Maybe we should make this work by tracking if we have a # written?
    Obj&                       annotation()    { obj << "#"; return *this; }
    template <typename T> Obj& annotation(T a) { return annotation().insert(a); }

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
    Obj&                       an(std::string a = "") { return a == "" ? ln() : an(a); }
    template <typename T> Obj& an(T a)                { return annotation(a).ln(); }

    // Add a vector.
    template <typename T> Obj& vector(Vec2<T> p) { return vector(p.x,p.y); }
    template <typename T> Obj& vector(Vec3<T> p) { return vector(p.x,p.y,p.z); }
    template <typename T> Obj& vector(Vec4<T> p) { return vector(p.x,p.y,p.z,p.w); }

    // Add a vertex.
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
    template <typename T> Obj& polygon2(int point_count, T* coord_buffer) { return polygon(point_count, coord_buffer, 2); }
    template <typename T> Obj& polygon2_xy(int point_count, T x1,T y1,  T x2,T y2,  T x3,T y3, ...) {

        v(x1, y1).ln().v(x2, y2).ln().v(x3, y3).ln();

        va_list va;
        va_start(va, y3);
        for (int i = 0; i < point_count - 3; i++) {
            T xn = va_arg(va, T);
            T yn = va_arg(va, T);
            v(xn, yn).ln();
        }
        va_end(va);

        // Write f-directive with no newline so the caller can add an annotation
        f();
        for (int i = -point_count; i < 0; i++) {
            insert(i);
        }

        return *this;
    }
    // template <typename T> Obj& polygon2_Vec(int point_count, Vec2 xy1, Vec2 xy2, Vec2 xy3, ...) { }

    // Add a 3D polygon.
    template <typename T> Obj& polygon3(int point_count, T* coord_buffer) { return polygon(point_count, coord_buffer, 3); }

    template <typename T> Obj& polygon (int point_count, T* coord_buffer, uint8_t point_dimension) {
        if (point_count <= 0) {
            return;
        }

        for (int i = 0; i < point_count; i++) {
            v();
            for (int d = 0; d < point_dimension; d++) {
                insert(coord_buffer[i * point_dimension + d]).ln();
            }
        }

        // Write f-directive with no newline so the caller can add an annotation
        f();
        for (int i = -point_count; i < 0; i++) {
            insert(i);
        }

        return *this;
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
                          Obj& set_precision(int n = 6)     { obj.precision(n); return *this; }
    template <typename T> Obj& set_precision_digits10()     { return set_precision(std::numeric_limits<T>::digits10); }
    template <typename T> Obj& set_precision_max_digits10() { return set_precision(std::numeric_limits<T>::max_digits10); }

    //
    // Concise API. These are convenience functions
    //

    Obj& ln() { obj << "\n"; return *this; }

    // Add a vertex.
    Obj&                       v()            { obj << "v"; return *this; }
    template <typename T> Obj& v(T x,T y)     { return v().vector(x,y);   }
    template <typename T> Obj& v(T x,T y,T z) { return v().vector(x,y,z); }
    template <typename T> Obj& v(Vec2<T> xy)  { return v().vector(xy);    }
    template <typename T> Obj& v(Vec3<T> xyz) { return v().vector(xyz);   }

    // Add a point.
    Obj&                       p()              { obj << "p"; return *this;  }
    Obj&                       pi(int i = -1)   { return p().insert(i);      }
    template <typename T> Obj& p(T x, T y)      { return v(x,y)  .ln().pi(); }
    template <typename T> Obj& p(T x, T y, T z) { return v(x,y,z).ln().pi(); }
    template <typename T> Obj& p(Vec2<T> xy)    { return v(xy)   .ln().pi(); }
    template <typename T> Obj& p(Vec3<T> xyz)   { return v(xyz)  .ln().pi(); }

    // Add a segment.
    Obj&                       l()                               { obj << "l"; return *this; }
    Obj&                       lij(int i = -2,   int j = -1    ) { return l().vector(i,j);   }
    template <typename T> Obj& l(T x1,T y1,      T x2,T y2     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().lij(); }
    template <typename T> Obj& l(T x1,T y1,T z1, T x2,T y2,T z2) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().lij(); }
    template <typename T> Obj& l(Vec2<T> xy1,      Vec2<T> xy2 ) { return v(xy1)     .ln().v(xy2)     .ln().lij(); }
    template <typename T> Obj& l(Vec3<T> xyz1,     Vec3<T> xyz2) { return v(xyz1)    .ln().v(xyz2)    .ln().lij(); }

    // Add a triangle.
    Obj&                       f()                                               { obj << "f"; return *this; }
    Obj&                       fijk(int i = -3,  int j = -2,     int k = -1    ) { return f().vector(i,j,k); }
    template <typename T> Obj& f(T x1,T y1,      T x2,T y2,      T x3,T y3     ) { return v(x1,y1)   .ln().v(x2,y2)   .ln().v(x3,y3)   .ln().f(); }
    template <typename T> Obj& f(T x1,T y1,T z1, T x2,T y2,T z2, T x3,T y3,T z3) { return v(x1,y1,z1).ln().v(x2,y2,z2).ln().v(x3,y3,z3).ln().f(); }
    template <typename T> Obj& f(Vec2<T> xy1,    Vec2<T> xy2,    Vec2<T> xy3   ) { return v(xy1)     .ln().v(xy2)     .ln().v(xy3)     .ln().f(); }
    template <typename T> Obj& f(Vec3<T> xyz1,   Vec3<T> xyz2,   Vec3<T> xyz3  ) { return v(xyz1)    .ln().v(xyz2)    .ln().v(xyz3)    .ln().f(); }


    // Add a box.
    template <typename T> Obj& lbox(Vec2<T> min,    Vec2<T> max,   std::string annotation = "") { return segment_box_min_max(min, max, annotation); }
    template <typename T> Obj& lbox(Vec2<T> center, T side_length, std::string annotation = "") { return segment_box_centered(center, side_length, annotation); }

    // TODO fbox, l/frect, l/faabb, l/fcircle, l/fball, l/fsphere, l/ftetrahedron, polyline, star (defined to neatly fit into a box or a circle with the same number of points)
    // TODO Add functions corresponding to command annotations e.g., to set item state/prism application state
    // TODO Template the above on the annotation type?
};

template <typename T>
struct Vec2 {
    union { struct { T x; T y; }; T xy[2]; };

    Vec2() : x(0), y(0) {}
    Vec2(T x, T y) : x(x), y(y) {}

    // Eventually these will need to be in the macro below
    Vec2(UE::Math::TVector2<T>   p) { x = p.X; y = p.Y; }
    Vec2(UE::Geometry::FVector2i p) { x = p.X; y = p.Y; }

#ifdef PRISM_VEC2_CLASS_EXTRA
    PRISM_VEC2_CLASS_EXTRA
#endif
};

template <typename T>
struct Vec3 {
    union { struct { T x; T y; T z; }; T xyz[3]; };

    Vec3() : x(0), y(0), z(0) {}
    Vec3(T x, T y, T z) : x(x), y(y), z(z) {}

    // Eventually these will need to be in the macro below
    Vec3(UE::Math::TVector<T>    p) { x = p.X; y = p.Y, z = p.Z; }
    Vec3(UE::Geometry::FVector3i p) { x = p.X; y = p.Y; z = p.Z; }

#ifdef PRISM_VEC3_CLASS_EXTRA
    PRISM_VEC3_CLASS_EXTRA
#endif
};

template <typename T>
struct Vec4 {
    union { struct { T x; T y; T z; T w; }; T xyzw[4]; };

    Vec4() : x(0), y(0), z(0), w(0) {}
    Vec4(T x, T y, T z, T w) : x(x), y(y), z(z), w(w) {}

    // Eventually these will need to be in the macro below
    Vec4(UE::Math::TVector4<T> p) { x = p.X; y = p.Y, z = p.Z; w = p.W; } 

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

void example_printf_logging() {
    Obj obj;
    obj.insert("some int = ").insert(5).ln();
    if (true) {
        obj.insert("condition passed on line ").insert(__LINE__).ln();
    }
    obj.write("prism_example_printf_logging.obj");
}


} // end namespace prism