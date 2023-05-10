#ifndef PRISM_API
#define PRISM_API

#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>
#include <stdarg.h> // va_arg, va_list, va_end

// The following are only used in the documentation() function
#include <iostream> // std::cout
#include <cmath> // std::max, std::min

namespace Prism {

// A 2D vector type. Use PRISM_VEC2_CLASS_EXTRA to define additional constructors and implicit casts to your types
template <typename T>
struct Vec2 {
    union { struct { T x, y; }; T xy[2]; };

    Vec2() : x(0), y(0) {}
    Vec2(T x, T y) : x(x), y(y) {}

    template <typename T> friend std::ostream& operator<<(std::ostream& os, const Vec2<T>& v);

#ifdef PRISM_VEC2_CLASS_EXTRA
    PRISM_VEC2_CLASS_EXTRA
#endif
};

template <typename T> std::ostream& operator<<(std::ostream& os, const Vec2<T>& v) {
    os << v.x << ' ' << v.y;
    return os;
}

// A 3D vector type. Use PRISM_VEC3_CLASS_EXTRA to define additional constructors and implicit casts to your types
template <typename T>
struct Vec3 {
    union { struct { T x, y, z; }; T xyz[3]; };

    Vec3() : x(0), y(0), z(0) {}
    Vec3(T x, T y, T z) : x(x), y(y), z(z) {}

    template <typename T> friend std::ostream& operator<<(std::ostream& os, const Vec3<T>& v);

#ifdef PRISM_VEC3_CLASS_EXTRA
    PRISM_VEC3_CLASS_EXTRA
#endif
};

template <typename T> std::ostream& operator<<(std::ostream& os, const Vec3<T>& v) {
    os << v.x << ' ' << v.y << ' ' << v.z;
    return os;
}

// A 4D vector type. Use PRISM_VEC4_CLASS_EXTRA to define additional constructors and implicit casts to your types
template <typename T>
struct Vec4 {
    union { struct { T x, y, z, w; }; T xyzw[4]; };

    Vec4() : x(0), y(0), z(0), w(0) {}
    Vec4(T x, T y, T z, T w) : x(x), y(y), z(z), w(w) {}

    template <typename T> friend std::ostream& operator<<(std::ostream& os, const Vec4<T>& v);

#ifdef PRISM_VEC4_CLASS_EXTRA
    PRISM_VEC4_CLASS_EXTRA
#endif
};

template <typename T> std::ostream& operator<<(std::ostream& os, const Vec4<T>& v) {
    os << v.x << ' ' << v.y << ' ' << v.z << ' ' << v.w;
    return os;
}

// A linear color type. Use PRISM_COLOR_CLASS_EXTRA to define additional constructors and implicit casts to your types
struct Color {
    union { struct { uint8_t r, g, b, a; }; uint8_t rgba[4]; };

    Color() : r(0), g(0), b(0), a(255) {}
    Color(uint8_t r, uint8_t g, uint8_t b, uint8_t a) : r(r), g(g), b(b), a(a) {}

    friend std::ostream& operator<<(std::ostream& os, const Color& v);

#ifdef PRISM_COLOR_CLASS_EXTRA
    PRISM_COLOR_CLASS_EXTRA
#endif
};

std::ostream& operator<<(std::ostream& os, const Color& v) {
    // Cast to int so we don't write chars
    os << (int)v.r << ' ' << (int)v.g << ' ' << (int)v.b << ' ' << (int)v.a;
    return os;
}

// Convenience aliases for VecN types
using V2f = Vec2<float>;
using V3f = Vec3<float>;
using V4f = Vec4<float>;
using V2d = Vec2<double>;
using V3d = Vec3<double>;
using V4d = Vec4<double>;
using V2 = V2d;
using V3 = V3d;
using V4 = V4d;

// Built-in Colors
const Color BLACK{0, 0, 0, 255};
const Color WHITE{255, 255, 255, 255};
const Color RED{255, 0, 0, 255};
const Color GREEN{0, 255, 0, 255};
const Color BLUE{0, 0, 255, 255};
const Color YELLOW{255, 255, 0, 255};


// An example using the API and an explanation of the rationale behind it.
// Returns boolean to indicate if the documentation tests pass
bool documentation(bool write_files = false);

//
// Writes obj files and Prism-specific extensions.
//
// See the documentation() function for a demo of the api, athough it should be self-explanatory.
//
// The following page was the reference for the .obj format: http://paulbourke.net/dataformats/obj/
// (not everything on that page is implemented). Note Prism-specific extensions are designed so that
// .obj files containing such extensions will always open in other obj viewers.
//
// You can extend this class by defining a PRISM_OBJ_CLASS_EXTRA macro, this is mostly useful if
// you want to add functions chain calls (i.e., obj.function1().function2()). If you don't care
// about this you can make a regular function
//
struct Obj {

    //
    // State
    //

    // Current contents of the .obj file
    std::stringstream obj;

    // Number of hash characters on a line, these are significant for Prism:
    // 0 hash characters => writing geometry
    // 1 hash character  => writing an annotation. Prism stores the text between the first # and a newline/second # as an annotation
    // 2 hash characters => writing a comment. Prism ignores everything following the second # character on a line
    unsigned hash_count = 0;




    //
    // Basic functions
    //

    // Constructor. By default write with enough precision to round trip from float64 to decimal and back
    // Note: Prism currently stores mesh data using float32, we will move to float64 so we can show coordinate labels at full precision
    Obj() {
        set_precision_max_digits10<double>();
    }

    // Add anything to the obj file using operator<<
    template <typename T> Obj& add(const T& anything) {
        obj << anything;
        return *this;
    }

    // Add anything to the obj file using operator<< but prefix with a space character
    template <typename T> Obj& insert(const T& anything) {
        return space().add(anything);
    }

    // Add a newline, then add the `other` obj and then add another newline
    // Note: For this to work properly `other` must exclusively use negative (aka relative) indices
    Obj& append(const Obj& other) {
        return newline().add(other.obj.rdbuf()).newline();
    }





    //
    // Output functions
    //

    // Write data to a file
    //
    // Tip: Use format string "%05d" to write an int padded with zeros to width 5. This is useful for logging the
    // progress of an algorithm, you will also need to use the same prefix and you may need to run the
    // `sort_by_name` console command in Prism to put the item list into a state where you can use Ctrl LMB or
    // Shift LMB while sweeping the cursor over the visibility checkboxes to create a progress animation.
    void write(std::string filename) const {
        std::ofstream file;
        file.open(filename, std::ofstream::out | std::ofstream::trunc);
        file << obj.str();
        file.close();
    }

    // Returns the current state of the obj file as a std::string
    std::string to_std_string() const {
        return obj.str();
    }




    //
    // Directives and special characters/strings
    //

    // Add a vertex directive to start a vertex on the current line
    Obj& v() {
        return add('v');
    }

    // Add a vertex normal directive to the current line
    Obj& vn() {
        return add("vn");
    }

    // Add a texture vertex directive to the current line
    Obj& vt() {
        return add("vt");
    }

    // Add a point directive to start a point on the current line
    Obj& p() {
        return add('p');
    }

    // Add a line directive to start a segment/polyline on the current line
    Obj& l() {
        return add('l');
    }

    // Add a face directive to start a triangle/polygon on the current line
    Obj& f() {
        return add('f');
    }

    // Add a group directive.
    // Note: Currently Prism ignores these
    Obj& g() {
        return add('g');
    }

    // Add a newline to the obj and reset hash_count
    Obj& newline() {
        hash_count = 0;
        return add("\n");
    }

    // Add a space to the obj
    Obj& space() {
        return add(' ');
    }

    // Add a # character to the current line, this is used for annotations, comments and attributes
    Obj& hash() {
        hash_count++;
        return add('#');
    }

    // Add a ! character to the current line, this is used by command annotations
    Obj& bang() {
        return add('!');
    }

    // Add an @ character to the current line, this is used for attributes
    Obj& at() {
        return add('@');
    }

    // An abbreviated version of the newline function
    Obj& ln() {
        return newline();
    }






    //
    // Annotations.
    //
    // In Prism the text between the first # and a newline or second # is an 'annotation string' and can be shown in the viewport
    //

    // If there is no # character on the current line add one, otherwise do nothing
    Obj& annotation() {
        if (hash_count == 0) {
            // Add a space here to help other obj viewers which might fail to parse numbers not delimited by whitespace
            space().hash();
        }
        return *this;
    }

    // If there is no # character on the current line add one, otherwise do nothing. Then add " anything" to the obj
    template <typename T> Obj& annotation(const T& anything) {
        return annotation().insert(anything);
    }

    // Convenience function to write a newline if the given text is empty and write the text annotation followed by a newline otherwise
    Obj& an(const std::string& text = "") {
        return text == "" ? newline() : annotation(text).newline();
    }

    // Convenience function to write a generic annotation followed by a newline
    template <typename T> Obj& an(const T& anything) {
        return annotation(anything).newline();
    }

    // Add the data, prefixed with an @, to the current annotation string (start a new annotation if necessary)
    //
    // In a future version of Prism there will be function to parse numerical data types/colors written to annotations
    // in order to display or process them specially. Multiple distinct data types placed on the same geometry element
    // will be supported and the @ character will be used parse them.  Until this is implemented you might still want
    // to use this function rather than the plain annotation one if you find having the @ prefix helps you read your
    // annotations more clearly. See Prism::documentation() for more details.
    //
    template <typename T> Obj& attribute(const T& data) {
        // Add a space is for legibility.
        return annotation().space().at().insert(data);
    }





    //
    // Comments.
    //
    // In Prism any text that follows the second # on a line is ignored
    //

    // Ensure there are two # characters on the current line
    Obj& comment() {
        while (hash_count < 2) {
            hash();
        }
        return *this;
    }

    // Ensure there are two # characters on the current line then add "anything" to the obj
    template <typename T> Obj& comment(T anything) {
        return comment().add(anything);
    }




    //
    // Vectors
    //

    // Add 2D vector
    // Note: writes " x y" to the obj
    template <typename T> Obj& vector2(T x, T y) {
        return vector2(Vec2<T>(x, y));
    }

    // Add 2D vector
    // Note: writes " v.x v.y" to the obj
    template <typename T> Obj& vector2(Vec2<T> v) {
        return insert(v);
    }

    // Add 3D vector
    // Note: writes " x y z" to the obj
    template <typename T> Obj& vector3(T x, T y, T z) {
        return vector3(Vec3<T>(x, y, z));
    }

    // Add 3D vector
    // Note: writes " v.x v.y v.z" to the obj
    template <typename T> Obj& vector3(Vec3<T> v) {
        return insert(v);
    }

    // Add 4D vector
    // Note: writes " x y z w" to the obj
    template <typename T> Obj& vector4(T x, T y, T z, T w) {
        return vector4(Vec4<T>(x, y, z, w));
    }

    // Add 4D vector
    // Note: writes " v.x v.y v.z v.w" to the obj
    template <typename T> Obj& vector4(Vec4<T> v) {
        return insert(v);
    }




    //
    // Vertices/Positions.
    //
    // :ObjIndexing Vertex indexing is 1-based and can be negative:
    // * If index >  0 the index refers to the index-th added vertex
    // * If index <  0 the index refers to index-th preceeding vertex relative to line containing the element with the reference
    // * if index == 0 the index is invalid, this is a silent error
    // Vertices should be referenced by elements that are written later in the obj file
    //

    // Add a 2D position
    // Note: writes "v a.x a.y" to the obj
    template <typename T> Obj& vertex2(Vec2<T> a) {
        return v().vector2(a);
    }

    // Add a 3D position
    // Note: writes "v a.x a.y a.z" to the obj
    template <typename T> Obj& vertex3(Vec3<T> a) {
        return v().vector3(a);
    }




    //
    // Normals and Tangents. Indexing is 1-based, see :ObjIndexing
    //

    // Add a 3D normal
    // Note: writes "vn n.x n.y n.z" to the obj
    template <typename T> Obj& normal3(Vec3<T> n) {
        return vn().vector3(n);
    }

    // Add a UV coordinate (2D texture vertex)
    // Note: writes "vt t.x t.y" to the obj
    template <typename T> Obj& uv2(Vec2<T> t) {
        return vt().vector2(t);
    }

    // Add a 3D tangent (3D texture vertex)
    // Note: writes "vt t.x t.y t.z" to the obj
    template <typename T> Obj& tangent3(Vec3<T> t) {
        return vt().vector3(t);
    }



    //
    // Point Elements.  Indices are 1-based, see :ObjIndexing
    //

    // Add a point element referencing the i-th vertex position
    // Note: writes "p i" to the obj
    Obj& point(int i = -1) {
        return p().insert(i);
    }

    // Add a vertex position and a point element that references it
    // Note: writes "v a.x a.y\np -1" to the obj
    template <typename T> Obj& point2(Vec2<T> a) {
        return vertex2(a).newline().point();
    }

    // Add a vertex position and a point element that references it
    // Note: writes "v a\np -1" to the obj
    template <typename T> Obj& point3(Vec3<T> a) {
        return vertex3(a).newline().point();
    }




    //
    // Segment Elements.  Indices are 1-based, see :ObjIndexing
    //

    // Add a segment element connecting vertices i and j
    // Note: writes "l i j" to the obj
    Obj& segment(int i = -2, int j = -1) {
        return l().insert(i).insert(j);
    }

    // Add 2 vertex positions and a segment element referencing them
    // Note: writes "v a.x a.y\nv b.x b.y\nl -2 -1" to the obj
    template <typename T> Obj& segment2(Vec2<T> a, Vec2<T> b) {
        return vertex2(a).newline().vertex2(b).newline().segment();
    }

    // Add 2 vertex positions and a segment element referencing them
    // Note: writes "v a.x a.y a.z\nv b.x b.y b.z\nl -2 -1" to the obj
    template <typename T> Obj& segment3(Vec3<T> a, Vec3<T> b) {
        return vertex2(a).newline().vertex2(b).newline().segment();
    }




    //
    // Triangle Elements.  Indices are 1-based, see :ObjIndexing
    //

    // Add a triangle element referencing the 3 previous vertex positions (default).
    // The user can provide explicit indicies to reference vertices vi, vj and vk
    Obj& triangle(int vi = -3, int vj = -2, int vk = -1) {
        return f().insert(vi).insert(vj).insert(vk);
    }

    // Add a triangle element referencing the 3 previous vertex positions and normals (default).
    // The user can provide explicit indicies to reference vertices vi, vj and vk; and normals ni, nj and nk
    Obj& triangle_vn(int vi = -3, int vj = -2, int vk = -1, int ni = -3, int nj = -2, int nk = -1) {
        f();
        insert(vi).add("//").add(ni);
        insert(vj).add("//").add(nj);
        insert(vk).add("//").add(nk);
        return *this;
    }

    // Add a triangle element referencing the 3 previous vertex positions and texture vertices (default).
    // The user can provide explicit indices to reference vertices vi, vj and vk; and texture vertices ti, tj and tk
    Obj& triangle_vt(int vi = -3, int vj = -2, int vk = -1, int ti = -3, int tj = -2, int tk = -1) {
        f();
        insert(vi).add("/").add(ti);
        insert(vj).add("/").add(tj);
        insert(vk).add("/").add(tk);
        return *this;
    }

    // Add a triangle element referencing the 3 previous vertex positions, vertex normals and texture vertices (default).
    // The user can provide explicit indices reference vertices vi, vj and vk; normals ni, nj and nk; and texture vertices ti, tj and tk
    Obj& triangle_vnt(int vi = -3, int vj = -2, int vk = -1, int ni = -3, int nj = -2, int nk = -1, int ti = -3, int tj = -2, int tk = -1) {
        f();
        insert(vi).add("/").add(ti).add("/").add(ni);
        insert(vj).add("/").add(tj).add("/").add(nj);
        insert(vk).add("/").add(tk).add("/").add(nk);
        return *this;
    }

    // Add 3 vertex positions and a triangle element referencing them
    template <typename T> Obj& triangle2(Vec2<T> va, Vec2<T> vb, Vec2<T> vc) {
        vertex2(va).newline();
        vertex2(vb).newline();
        vertex2(vc).newline();
        return triangle();
    }

    // Add 3 vertex positions and a triangle element referencing them
    template <typename T> Obj& triangle3(Vec3<T> va, Vec3<T> vb, Vec3<T> vc) {
        vertex3(va).newline();
        vertex3(vb).newline();
        vertex3(vc).newline();
        return triangle();
    }

    // Add 3 vertex positions, 3 vertex normals and a triangle element referencing them
    template <typename T> Obj& triangle3_vn(Vec3<T> va, Vec3<T> vb, Vec3<T> vc, Vec3<T> na, Vec3<T> nb, Vec3<T> nc) {
        vertex3(va).newline().vn().vector3(na).newline();
        vertex3(vb).newline().vn().vector3(nb).newline();
        vertex3(vc).newline().vn().vector3(nc).newline();
        return triangle_vn();
    }

    // Add 3 vertex positions, 3 texture vertices and a triangle element referencing them
    template <typename T> Obj& triangle3_vt(Vec3<T> va, Vec3<T> vb, Vec3<T> vc, Vec3<T> ta, Vec3<T> tb, Vec3<T> tc) {
        vertex3(va).newline().vt().vector3(ta).newline();
        vertex3(vb).newline().vt().vector3(tb).newline();
        vertex3(vc).newline().vt().vector3(tc).newline();
        return triangle_vt();
    }

    // Add 3 vertex positions, 3 vertex normals, 3 texture vertices and a triangle element referencing them
    template <typename T> Obj& triangle3_vnt(Vec3<T> va, Vec3<T> vb, Vec3<T> vc, Vec3<T> na, Vec3<T> nb, Vec3<T> nc, Vec3<T> ta, Vec3<T> tb, Vec3<T> tc) {
        vertex3(va).newline().vn().vector3(na).newline().vt().vector3(ta).newline();
        vertex3(vb).newline().vn().vector3(nb).newline().vt().vector3(tb).newline();
        vertex3(vc).newline().vn().vector3(nc).newline().vt().vector3(tc).newline();
        return triangle_vnt();
    }





    //
    // Polylines. These are sequences of segment elements
    //

    // Add a polyline element referencing the previous N vertex positions
    Obj& polyline(int N, bool closed = false) {
        if (N < 2) return *this;
        l(); // Start the element
        for (int i = -N; i < 0; i++) insert(i); // Continue the element
        if (closed) insert(-N); // Close the polyline
        return *this;
    }

    // Add a polyline element referencing the vertices with the given indicies
    Obj& polyline(int N, int i, int j, ...) {
        segment(i, j); // Start the element
        va_list va;
        va_start(va, j);
        for (int n = 0; n < N-2; n++) insert(va_arg(va, int)); // Continue the element
        va_end(va);
        return *this;
    }

    // Add N vertex positions, described by the given 2D coordinate buffer, and a polyline element referencing them.
    // If closed is true write the first point index again to close the polyline
    template <typename T> Obj& polyline2(int N, T* XYs, bool closed = false) {
        return poly_impl('l', N, XYs, 2, closed);
    }

    // Add N vertex positions, described by the given 3D coordinate buffer, and a polyline element referencing them.
    // If closed is true write the first point index again to close the polyline
    template <typename T> Obj& polyline3(int N, T* XYZs, bool closed = false) {
        return poly_impl('l', N, XYZs, 3, closed);
    }

    // Add the given 2D vertex positions and a polyline element referencing them
    template <typename T> Obj& polyline2(int N, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex2_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polyline(N);
    }

    // Add the given 3D vertex positions and a polyline element referencing them
    template <typename T> Obj& polyline3(int N, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex3_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polyline(N);
    }





    //
    // Polygons. These are sequences of triangle elements aka triangle fans
    //

    // Add a polygon element referencing the previous N vertices
    Obj& polygon(int N) {
        f(); // Start the element
        for (int i = -N; i < 0; i++) insert(i); // Continue the element
        return *this;
    }

    // Add a polygon element referencing the vertices with the given indices
    Obj& polygon(int N, int i, int j, int k, ...) {
        triangle(i, j, k); // Start the element
        va_list va;
        va_start(va, k);
        for (int n = 0; n < N-3; n++) insert(va_arg(va, int)); // Continue the element
        va_end(va);
        return *this;
    }

    // Add N vertex positions, described by the given 2D coordinate buffer, and a polygon element referencing them
    template <typename T> Obj& polygon2(int N, T* XYs) {
        return poly_impl('f', N, XYs, 2);
    }

    // Add N vertex positions, described by the given 3D coordinate buffer, and a polygon element referencing them
    template <typename T> Obj& polygon3(int N, T* XYZs) {
        return poly_impl('f', N, XYZs, 3);
    }

    // Add the given 2D vertex positions and a polygon element referencing them
    template <typename T> Obj& polygon2(int N, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex2_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polygon(N);
    }

    // Add the given 3D vertex positions and a polygon element referencing them
    template <typename T> Obj& polygon3(int N, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex3_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polygon(N);
    }





    //
    // Axis-aligned Boxes.
    //

    // Add a 2D box region defined by min/max, visualized with segment elements
    template <typename T> Obj& box2_min_max(Vec2<T> min, Vec2<T> max) {
        return polyline2(5, min, Vec2<T>{max.x,min.y}, max, Vec2<T>{min.x,max.y}, min);
    }

    // Add a 3D box region defined by min/max, visualized with segment elements
    template <typename T> Obj& box3_min_max(Vec3<T> min, Vec3<T> max, bool use_segments = true) {
        // This has some redundant edges but having them means we can annotate all sgements in the shape conveniently
        Vec3<T> p000{min.x, min.y, min.z}, p100{max.x, min.y, min.z}, p010{min.x, max.y, min.z}, p110{max.x, max.y, min.z};
        Vec3<T> p001{min.x, min.y, max.z}, p101{max.x, min.y, max.z}, p011{min.x, max.y, max.z}, p111{max.x, max.y, max.z};
        return polyline3(16, p000, p100, p110, p010, p000, p001, p101, p100, p101, p111, p110, p111, p011, p010, p011, p001);
    }

    // Add a 2D box region defined by a center point and extents vector (box side lengths), visualized with segment elements
    template <typename T> Obj& box2_center_extents(Vec2<T> center, Vec2<T> extents) {
        return box2_min_max<T>(
            {center.x - extents.x/2, center.y - extents.y/2},
            {center.x + extents.x/2, center.y + extents.y/2});
    }

    // Add a 3D box region defined by a center point and extents vector (box side lengths), visualized with segment elements
    template <typename T> Obj& box3_center_extents(Vec3<T> center, Vec3<T> extents) {
        return box3_min_max<T>(
            {center.x - extents.x/2, center.y - extents.y/2, center.z - extents.z/2},
            {center.x + extents.x/2, center.y + extents.y/2, center.z + extents.z/2});
    }




    //
    // Obj file configuration functions
    //

    // Set the precision used to write floats to the obj.
    // Note: This is useful to improve readability if you're writing float data to annotations, after doing that you
    // will probably want to restore the previous precision e.g., by calling `set_precision_max_digits10<double>()`
    Obj& set_precision(int n = 6) {
        obj.precision(n); return *this;
    }

    // Set the precision used to write floats to the obj
    template <typename T> Obj& set_precision_digits10() {
        return set_precision(std::numeric_limits<T>::digits10);
    }

    // Set the precision used to write floats to the obj. Use this function to ensure you can round-trip from float to decimal and back
    // See https://randomascii.wordpress.com/2012/02/11/they-sure-look-equal/ for details
    template <typename T> Obj& set_precision_max_digits10() {
        return set_precision(std::numeric_limits<T>::max_digits10);
    }





    //
    // Command annotations (Prism post-load configuration functions)
    //
    // These functions configure the item's display settings after the obj file is loaded in Prism and are a convenient
    // way to save you a few clicks.  The functions are implemented using Prism's notation of _Command Annotations_
    // which is a facility in Prism which enables you to call any console command right after the entire file has been
    // loaded. If you know you want to look annotations for a file you can call `set_annotation_label_visible(true)`
    // to add a command annotation which will enable annotation visibility after the file is loaded (annotation
    // labelling is off by default). Note: You can call these functions whenever you like, the command will be written
    // to this->obj at the point you call them but Prism will defer execution until the entire file has been parsed.
    //

    // Start a command annotation, arguments should be `insert`ed after this
    Obj& command(const std::string& command_name) {
        return newline().hash().bang().insert(command_name);
    }

    // (Advanced) Start a command annotation whose first argument is the Prism item index
    //
    // The Prism application has a global array of items (aka shapes/geometry) the index into this list is often used as
    // the first argument in console commands.  When console commands are executed by the function which load .obj
    // files as command annotations a _local_ array of items is created, the item with local index 0 is the item with
    // geometry given in the .obj, if a console command which has a side effect of generating a new item is executed as
    // a command annotation then this item will have index >0 and you can pass that value as `item_index` to run a
    // console command of one of these generated items which are not explicitly in the .obj file.
    //
    // Note: This complexity is intentionally avoided in the Prism::Obj command annotation API, so the rest of the
    // functions below work with `item_index == 0`.
    Obj& item_command(const std::string& command_name, int item_index = 0) {
        return command(command_name).insert(item_index);
    }

    // Annotation labels

    // Set visibility of annotations
    Obj& set_annotations_visible(bool visible) {
        return item_command("set_annotations_visible").insert((int)visible);
    }

    // Set color of annotation text
    Obj& set_annotations_color(Color color) {
        return item_command("set_annotations_color").insert(color);
    }

    // Set scale of annotation text
    // The scale parameter is a float in the range [0.2, 1.0], by default Prism uses 0.4.
    // TODO :FixScaleParameter The scale parameter is weird, use size in pixels instead
    Obj& set_annotations_scale(float scale) {
        return item_command("set_annotations_scale").insert(scale);
    }


    // Vertex labels

    // Set visibility of vertex index labels i.e., 0-based indices into the obj file v-directive data
    Obj& set_vertex_index_labels_visible(bool visible) {
        return item_command("set_vertex_index_labels_visible").insert((int)visible);
    }

    // Set visibility of vertex position labels i.e., the coordinates of the obj file v-directive data
    Obj& set_vertex_position_labels_visible(bool visible) {
        return item_command("set_vertex_position_labels_visible").insert((int)visible);
    }

    // Set color of vertex index/position labels
    Obj& set_vertex_label_color(Color color) {
        return item_command("set_vertex_label_color").insert(color);
    }

    // Set scale of vertex index/position labels
    // The scale parameter is a float in the range [0.2, 1.0], by default Prism uses 0.4 (see :FixScaleParameter)
    Obj& set_vertex_label_scale(float scale) {
        return item_command("set_vertex_label_scale").insert(scale);
    }


    // Point labels

    // Set visibility of point element index labels i.e., 0-based indices into the obj file p-directive data
    // Note: set_vertex_index_labels_visible is probably the function you want!
    Obj& set_point_index_labels_visible(bool visible) {
        return item_command("set_point_index_labels_visible").insert((int)visible);
    }

    // Set color of point index labels
    // Note: set_vertex_label_color is probably the function you want!
    Obj& set_point_label_color(Color color) {
        return item_command("set_point_label_color").insert(color);
    }

    // Set scale of point index labels
    // The scale parameter is a float in the range [0.2, 1.0], by default Prism uses 0.4 (see :FixScaleParameter)
    // Note: set_vertex_label_scale is probably the function you want!
    Obj& set_point_label_scale(float scale) {
        return item_command("set_point_label_scale").insert(scale);
    }


    // Segment labels

    // Set visibility of segment element index labels i.e., 0-based indices into the obj file l-directive data
    Obj& set_segment_index_labels_visible(bool visible = true) {
        return item_command("set_segment_index_labels_visible").insert((int)visible);
    }

    // Set color of segment index labels
    Obj& set_segment_label_color(Color color) {
        return item_command("set_segment_label_color").insert(color);
    }

    // Set scale of segment index labels
    // The scale parameter is a float in the range [0.2, 1.0], by default Prism uses 0.4 (see :FixScaleParameter)
    Obj& set_segment_label_scale(float scale) {
        return item_command("set_segment_label_scale").insert(scale);
    }


    // Triangle labels

    // Set visibility of triangle element index labels i.e., 0-based indices into the obj file f-directive data
    Obj& set_triangle_index_labels_visible(bool visible = true) {
        return item_command("set_triangle_index_labels_visible").insert((int)visible);
    }

    // Set color of triangle index labels
    Obj& set_triangle_label_color(Color color) {
        return item_command("set_triangle_label_color").insert(color);
    }

    // Set scale of triangle index labels
    // The scale parameter is a float in the range [0.2, 1.0], by default Prism uses 0.4 (see :FixScaleParameter)
    Obj& set_triangle_label_scale(float scale) {
        return item_command("set_triangle_label_scale").insert(scale);
    }


    // Vertex rendering

    // Set visibility of vertices i.e., obj file v-directive data
    Obj& set_vertices_visible(bool visible = true) {
        return item_command("set_vertices_visible").insert((int)visible);
    }

    // Set color of vertices i.e., obj file v-directive data
    Obj& set_vertices_color(Color color) {
        return item_command("set_vertices_color").insert(color);
    }

    // Set size/radius of vertices i.e., obj file v-directive data
    Obj& set_vertices_size(int size) {
        return item_command("set_vertices_size").insert(size);
    }


    // Point rendering

    // Set visibility of points i.e., obj file p-directive data
    // Note: set_vertices_visible is probably the function you want!
    Obj& set_points_visible(bool visible) {
        return item_command("set_points_visible").insert((int)visible);
    }

    // Set color of points i.e., obj file p-directive data
    // Note: set_vertices_color is probably the function you want!
    Obj& set_points_color(Color color) {
        return item_command("set_points_color").insert(color);
    }

    // Set size/radius of points i.e., obj file p-directive data
    // Note: set_vertices_size is probably the function you want!
    Obj& set_points_size(int size) {
        return item_command("set_points_size").insert(size);
    }


    // Segment rendering

    // Set visibility of segments i.e., obj file l-directive data
    Obj& set_segments_visible(bool visible) {
        return item_command("set_segments_visible").insert((int)visible);
    }

    // Set color of segments i.e., obj file l-directive data
    Obj& set_segments_color(Color color) {
        return item_command("set_segments_color").insert(color);
    }

    // Set width of segments i.e., obj file l-directive data
    Obj& set_segments_width(float width) {
        return item_command("set_segments_width").insert(width);
    }


    // Edges rendering. Applies to triangle edges, but not segment elements.

    // Set visibility of triangle edges i.e., obj file f-directive data
    Obj& set_edges_visible(bool visible) {
        return item_command("set_edges_visible").insert((int)visible);
    }

    // Set color of triangle edges i.e., obj file f-directive data
    Obj& set_edges_color(Color color) {
        return item_command("set_edges_color").insert(color);
    }

    // Set width of triangle edges i.e., obj file f-directive data
    Obj& set_edges_width(float width) {
        return item_command("set_edges_width").insert(width);
    }


    // Triangle rendering

    // Set visibility of triangles i.e., obj file f-directive data
    Obj& set_triangles_visible(bool visible) {
        return item_command("set_triangles_visible").insert((int)visible);
    }

    // Set color of triangles i.e., obj file f-directive data
    Obj& set_triangles_color(Color color) {
        return item_command("set_triangles_color").insert(color);
    }


    // Miscellaneous

    // Save a copy of the current obj *after it is loaded in Prism* but modify the contents to make the file work with
    // more obj viewers/readers. This function works by applying the following simplifications:
    //
    // 1) Replace negative indices with positive indices (some viewers do not support negative indices)
    //
    // 2) Replace polyline/polygon elements (l-directives with >2 indices/f-directives with >4 indices respespectively)
    //    with segment/triangle elements (l-directives with 2 indices/f-directives with 3 indices respectively)
    //
    // 3) Reindex positions/textures/normals so that directives referencing them have common indicies so that things
    //    like f 1/2/3 2/7/3 3/18/77 become f 1/1/1 2/2/2 3/3/3.
    //
    // TODO Implement this command in Prism
    // TODO Prism also doesn't support 3) so we should fix that as well...!
    // TODO Maybe its a bit weird to expose this function as a command annotation since to get the simplified file you
    //      need to load the current file in Prism. We could instead just mention it exists in Obj::write documentation?
    //
    //Obj& save_simplified_obj(std::string filename) {
    //    return item_command("save_simplified_obj").insert(filename);
    //}



    //
    // Implementation methods
    //

    // Writes a polyline or a triangle fan
    template <typename T> Obj& poly_impl(char directive, int point_count, T* coords, uint8_t point_dimension, bool repeat_last = false) {
        if (point_count <= 0) {
            return *this;
        }

        for (int i = 0; i < point_count; i++) {
            v();
            for (int d = 0; d < point_dimension; d++) {
                insert<T>(*(coords + i * point_dimension + d));
            }
            newline();
        }

        directive == 'f' ? f() : l();
        for (int i = -point_count; i < 0; i++) {
            insert(i);
        }

        if (repeat_last) insert(-point_count);

        // No newline so the caller can add an annotation

        return *this;
    }

    // Write 2D vertex positions as a variadic call
    template <typename T> Obj& vertex2_variadic(int point_count, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, va_list va) {
        vertex2(p1).newline().vertex2(p2).newline().vertex2(p3).newline();
        for (int i = 0; i < point_count-3; i++) {
            Vec2<T> pn = va_arg(va, Vec2<T>);
            vertex2(pn).newline();
        }
        return *this;
    }

    // Write 3D vertex positions as a variadic call
    template <typename T> Obj& vertex3_variadic(int point_count, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, va_list va) {
        vertex3(p1).newline().vertex3(p2).newline().vertex3(p3).newline();
        for (int i = 0; i < point_count-3; i++) {
            Vec3<T> pn = va_arg(va, Vec3<T>);
            vertex3(pn).newline();
        }
        return *this;
    }





    //
    // User-provided extension methods
    //

#ifdef PRISM_OBJ_CLASS_EXTRA
    PRISM_OBJ_CLASS_EXTRA
#endif
};


bool documentation(bool write_files) {

    // This `documentation` function is also used a test suite, hence this lambda
    bool tests_pass = true;
    auto test = [&write_files](std::string filename, std::string got, std::string wanted) {
        bool passed = true;
        if (wanted == got) {
            std::cout << "Test  " << filename << " PASSED..." << std::endl;
        } else {
            std::cout << "Test  " << filename << " FAILED..." << std::endl;
            std::cout << "Wanted:" << wanted << "\nGot:" << got << std::endl;
            passed = false;
        }
        if (!passed || write_files) {
            std::ofstream file;
            file.open(filename, std::ofstream::out | std::ofstream::trunc);
            file << got;
            file.close();
            std::cout << "Wrote " << filename << std::endl;
        }
        return passed;
    };




    // This block illustrates most of the API
    {
        using namespace Prism; // Access Obj struct and typedefs

        // Create an Obj instance and start the file with a newline to make formatting of the raw string literal
        // `output` a bit nicer
        Obj obj;
        obj.newline();

        // First we'll add a comment at the top of the file. If you look at the `output` string below you can see that
        // the provided text is prefixed by ## in the obj file, the obj spec uses a # to start a comment. Note that most
        // functions in the `Obj` API return `Obj&` which allows you to chain calls which can be handy if you like your
        // debugging code to be concise
        obj.comment("This file tests the Prism C++ API").newline();

        // Now we'll write 3 vertices and a triangle element in a very verbose way
        obj.vertex3(V3{0., 0., 1.}).annotation("Vertex A").newline();
        obj.vertex3(V3{3., 0., 1.}).annotation("Vertex B").newline();
        obj.vertex3(V3{3., 3., 1.}).annotation("Vertex C").newline();
        obj.triangle().annotation("Triangle ABC").newline();

        // The previous block had a lot of typing... you can do something similar as a one-liner as follows:
        obj.triangle3(V3{0., 0., 2.}, V3{3., 0., 2.}, V3{3., 3., 2.}).an("Triangle ABC");

        // The triangle element and vertex positions we just added to the obj all have _Annotation_ strings associated
        // with them. These strings can be visualized in Prism by turning on annotation labelling.  The annotations are
        // written to the obj file using obj comment syntax which means that adding them doesn't prevent the geometry
        // loading in a different obj viewer (but, of course, in a different viewer you won't be able to see the
        // annotations). Note we need to use the verbose version we want to annotate the vertices.

        // The Obj class will have a bunch of functions for writing compound shapes for now polylines, polygons and
        // boxes are supported but more will be added. To demo these functions we'll use the following data which
        // represents a 2D star shape; we use a union so we can illustrate different APIs.
        union {
            double coords[8*2] = {
                2, 2,   10, 0,   2, -2,   0, -10,   -2, -2,   -10, 0,   -2, 2,   0, 10
            };
            struct {
                V2 a, b, c, d, e, f, g, h;
            } points;
        } star;

        // First we'll write the star as a polyline boundary using a pointer-to-coordinate-buffer API:
        obj.polyline2(8, star.coords, true).an("star boundary");

        // Next, we'll write the star as a polygon using a variadic function call, a similar variadic function also
        // exists for writing polyline2 geometry
        obj.polygon2(8,
            star.points.a,
            star.points.b,
            star.points.c,
            star.points.d,
            star.points.e,
            star.points.f,
            star.points.g,
            star.points.h).an("star polygon");

        // The previous line wrote the coordinate data again even though we wrote it when we called polygon2, this
        // is probably fine for debugging code but, just to illustrate another function, we can write only an obj
        // f-directive references the previous vertices as follows:
        obj.polygon(8).an("star polygon again");

        // Note the obj spec allows you to reference previous vertices by using negative indices.  This feature is
        // pretty handy for not having to track the current vertex index and also for enabling you to concatenate obj
        // files into a single jumbo file, which we'll illustrate later.  One downside of using this feature is that
        // it appears not to be well supported by other viewers so in a future update of this API we'll add a function
        // to convert files into some well-supported subset of the spec e.g., by converting negative indices into
        // positive ones and converting l-/f-directives with more than 2/3 indices on a single line into a list of
        // l-/f-directives with exactly 2/3 indices on each line.

        // In general functions ending with a number have 2D/3D vector arguments and write both v-directives and the
        // relevant element directives. If you want to just write the element directive you can use the functions with
        // no number postfix. Note for some functions the number indicating dimension is redundant but we write it
        // anyway for consistency.

        // Here we write a bounding box for the star we just logged:
        constexpr double inf = std::numeric_limits<double>::infinity();
        V2 star_min{inf, inf}, star_max{-inf, -inf};
        for (int i = 0; i < 8; i++) {
            double x = star.coords[2*i + 0], y = star.coords[2*i + 1];
            star_max.x = std::max(star_max.x , x);
            star_min.x = std::min(star_min.x , x);
            star_max.y = std::max(star_max.y , y);
            star_min.y = std::min(star_min.y , y);
        }
        obj.box2_min_max(star_min, star_max).an("star bounding box");

        // So far we've only had one annotation per geometric entity (vertex/element), this is because Prism
        // represents annotations with a single string and there are no plans to change this. If you call the
        // annotation function more than once per line each call concatenates into a single annotation string
        obj.point2(V2{4., 7.}).annotation("these").annotation("are").annotation("concatenated").newline();

        // In some cases it can be useful attach more one or pieces of typed numerical data to the each geometric
        // entity of a mesh e.g., a scalar cost of a triangle edge collapse or a vertex displacement in a finite
        // element mesh.  A future version of Prism will support this by adding _Attributes_ to its internal mesh
        // datastructure along with UI for inspecting and rendering them.  The current plan for attributes is that
        // they will be set by parsing and extracting data stored in the annotation strings.  This extraction step
        // will require users to execute a console command explicity or by adding a _Command Annotation_ to the
        // obj file (command annotations are explained later but they are essentially console commands executed by
        // the obj file).  In order to facilitate this parsing Prism will assume attributes are prefixed by an @
        // and as part of the attribute extraction the relevant portion of the annotation string will be trimmed.
        // After extraction, the data structure you can inspect in Prism will have typed attributes as well as
        // annotations corresponding to the part of the raw in-file annotation strings before the first @.
        //
        // Although there is no special rendering/UI for attributes yet (you can only view attributes as the raw
        // annotation strings) you might still prefer to call the attribute function when adding multiple pieces
        // of data to a geometric entity because the @'s make the separate data more distinguishable. Here is an
        // example of point with an annotation and two attributes of different types. Note the attribute function
        // supports any type which defines an operator<<. Actually, the annotation function in this API also
        // supports writing non-string data using operator<< but this is just for convenience; rendering/UI support
        // for annotations in Prism is built around the assumption that they contain only string data).
        obj.point2(V2{3., 3.}).annotation("some string").attribute(42).attribute(V2{0.,0.}).newline();

        // Next we'll demonstrate how you can configure how Prism displays the obj file when it is loaded by writing
        // command annotations to the obj file.  This is handy because, depending on your debugging use-case, you
        // will want to see different things.  You could configure the display settings you want by clicking around
        // in the UI, or by calling the relevant console commands after the file is loaded but this can be slow or
        // annoying so to save you having to do this manually Prism's command annotation facility enables you to
        // execute console commands immediately after the file is loaded.
        //
        // For the obj we have been creating so far we are probably only interested in seeing the annotations we added,
        // so in practice we would probably only want to call the following functions...
        obj.set_annotations_visible(true);
        obj.set_annotations_scale(1.);
        obj.set_annotations_color(BLUE);

        // ...but since we are using this documentation for testing as well we'll just call all the config functions
        // to verify they are executed with no errors.  First we'll set the precision of the floats we write to the obj
        // file so that the `output` string looks a bit nicer.
        obj.set_precision(2);
        obj.set_vertex_index_labels_visible(false);
        obj.set_vertex_position_labels_visible(false);
        obj.set_vertex_label_color(BLACK);
        obj.set_vertex_label_scale(.4);
        obj.set_point_index_labels_visible(false);
        obj.set_point_label_color(RED);
        obj.set_point_label_scale(.4);
        obj.set_segment_index_labels_visible(false);
        obj.set_segment_label_color(GREEN);
        obj.set_segment_label_scale(.4);
        obj.set_triangle_index_labels_visible(false);
        obj.set_triangle_label_color(BLUE);
        obj.set_triangle_label_scale(.4);
        obj.set_vertices_visible(true);
        obj.set_vertices_color(BLUE);
        obj.set_vertices_size(7);
        obj.set_points_visible(true);
        obj.set_points_color(RED);
        obj.set_points_size(3);
        obj.set_segments_visible(true);
        obj.set_segments_color(RED);
        obj.set_segments_width(3.);
        obj.set_edges_visible(true);
        obj.set_edges_color(BLACK);
        obj.set_edges_width(4.);
        obj.set_triangles_visible(true);
        obj.set_triangles_color(GREEN);

        // Note we didn't need to explicitly call newline() after each command annotation. Command annotations must be
        // on a newline so this is called internally by the implementation

        // End the obj with a newline to make the formatting of the `output` string nicer
        obj.newline();

        // Once we have finished adding to the obj file we can write it out using the `write` function. If we called
        // this here we would generate a file containing the `output` string.  I personally find using absolute paths
        // convenient when working in Unreal because I can never remember the directory the Editor is running in.
        // obj.write("C:/path/to/my/debug/folder/debug_file.obj");

        std::string output = R"DONE(
##This file tests the Prism C++ API
v 0 0 1 # Vertex A
v 3 0 1 # Vertex B
v 3 3 1 # Vertex C
f -3 -2 -1 # Triangle ABC
v 0 0 2
v 3 0 2
v 3 3 2
f -3 -2 -1 # Triangle ABC
v 2 2
v 10 0
v 2 -2
v 0 -10
v -2 -2
v -10 0
v -2 2
v 0 10
l -8 -7 -6 -5 -4 -3 -2 -1 -8 # star boundary
v 2 2
v 10 0
v 2 -2
v 0 -10
v -2 -2
v -10 0
v -2 2
v 0 10
f -8 -7 -6 -5 -4 -3 -2 -1 # star polygon
f -8 -7 -6 -5 -4 -3 -2 -1 # star polygon again
v -10 -10
v 10 -10
v 10 10
v -10 10
v -10 -10
l -5 -4 -3 -2 -1 # star bounding box
v 4 7
p -1 # these are concatenated
v 3 3
p -1 # some string @ 42 @ 0 0

#! set_annotations_visible 0 1
#! set_annotations_scale 0 1
#! set_annotations_color 0 0 0 255 255
#! set_vertex_index_labels_visible 0 0
#! set_vertex_position_labels_visible 0 0
#! set_vertex_label_color 0 0 0 0 255
#! set_vertex_label_scale 0 0.4
#! set_point_index_labels_visible 0 0
#! set_point_label_color 0 255 0 0 255
#! set_point_label_scale 0 0.4
#! set_segment_index_labels_visible 0 0
#! set_segment_label_color 0 0 255 0 255
#! set_segment_label_scale 0 0.4
#! set_triangle_index_labels_visible 0 0
#! set_triangle_label_color 0 0 0 255 255
#! set_triangle_label_scale 0 0.4
#! set_vertices_visible 0 1
#! set_vertices_color 0 0 0 255 255
#! set_vertices_size 0 7
#! set_points_visible 0 1
#! set_points_color 0 255 0 0 255
#! set_points_size 0 3
#! set_segments_visible 0 1
#! set_segments_color 0 255 0 0 255
#! set_segments_width 0 3
#! set_edges_visible 0 1
#! set_edges_color 0 0 0 0 255
#! set_edges_width 0 4
#! set_triangles_visible 0 1
#! set_triangles_color 0 0 255 0 255
)DONE";

        // Since this` documentation` function you are reading is used for testing we actually call the `to_std_string`
        // function here to generate a string to compare with `output`
        if (!test("prism_documentation_ex1.obj", obj.to_std_string(), output)) {
            tests_pass = false;
        }
    }





    // This block illustrates how, if you use only relative indexing for point/segment/triangle elements, you can use
    // the `append` function to concatenate different obj files
    {
        using namespace Prism;

        Obj first, second;

        // Add some geometry to the first obj
        first.segment2(V2{0, 0}, V2{1, 0});

        // Add some geometry to the second obj
        second.point3(V3{1, 2, 3});

        // Concatenate the first and second obj
        Obj combined;
        combined.newline().comment("The first obj:").append(first).comment("The second obj:").append(second);

        std::string output = R"DONE(
##The first obj:
v 0 0
v 1 0
l -2 -1
##The second obj:
v 1 2 3
p -1
)DONE";

        if (!test("prism_documentation_ex2.obj", combined.to_std_string(), output)) {
            tests_pass = false;
        }
    }





    // This block illustrates a possibly handy use-case where you can create and write an obj file in one line
    {
        using namespace Prism;

        // We don't test this function to keep everything on a single line
        if (write_files) {
            std::string filename = "prism_documentation_ex3.obj";
            Obj().triangle2(V2{0., 0.}, V2{1., 0.}, V2{1., 1.}).an("triangle").point2(V2{3., 3.}).an("point").write(filename);
            std::cout << "Wrote " << filename << std::endl;
        }
    }






    // This block illustrates another kinda wacky use-case where you could use the Obj class as a debug file logger
    // for files which have nothing to do with the obj format
    {
        Obj obj;
        obj.add("some int =").insert(5).newline();
        obj.add("some type with operator<< =").insert(V2{2, 3}).newline();
        if (true) {
            obj.add("condition passed on line").insert(__LINE__);
            obj.add("\n"); // We don't care about tracking # chars so just log special characters directly
        }

        // We don't test this function because the __LINE__ macro makes it brittle
        if (write_files) {
            std::string filename = "prism_documentation_ex4.obj";
            obj.write(filename);
            std::cout << "Wrote " << filename << std::endl;
        }
    }

    return tests_pass;
}

#ifdef PRISM_VEC2_CLASS_EXTRA
#undef PRISM_VEC2_CLASS_EXTRA
#endif

#ifdef PRISM_VEC3_CLASS_EXTRA
#undef PRISM_VEC3_CLASS_EXTRA
#endif

#ifdef PRISM_VEC4_CLASS_EXTRA
#undef PRISM_VEC4_CLASS_EXTRA
#endif

#ifdef PRISM_COLOR_CLASS_EXTRA
#undef PRISM_COLOR_CLASS_EXTRA
#endif

#ifdef PRISM_OBJ_CLASS_EXTRA
#undef PRISM_OBJ_CLASS_EXTRA
#endif

} // namespace Prism

#endif // PRISM_API