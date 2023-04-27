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
#include <stdarg.h> // for va_arg(), va_list()
#include <iostream> // for std::cout, only used in usage_example()

namespace prism {

// A 2D vector type. Use PRISM_VEC2_CLASS_EXTRA to define additional constructors and implicit casts to your types
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

// A 3D vector type. Use PRISM_VEC3_CLASS_EXTRA to define additional constructors and implicit casts to your types
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

// A 4D vector type. Use PRISM_VEC4_CLASS_EXTRA to define additional constructors and implicit casts to your types
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

//
// Convenience aliases for VecN types
//

using V2 = Vec2<double>;
using V3 = Vec3<double>;
using V4 = Vec4<double>;
using V2f = Vec2<float>;
using V3f = Vec3<float>;
using V4f = Vec4<float>;
// TODO Add integer variants, note they must be separate to accomodate Unreal types which have a static assert on T


// An example using the API
void usage_example(bool write_files = false);

//
// Writes obj files and Prism-specific extensions.
//
// See usage_example() function for a demo of the api, athough it should be self-explanatory.
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

    // Construtor. By default write with enough precision to round trip from float64 to decimal and back
    // nocommit Note: Prism 0.5.1 stores mesh data using float32, we will move to float64 so we can show coordinate labels at full precision
    Obj() {
        set_precision_max_digits10<double>();
    }

    // Write data in .obj format.
    // Tip: Use format string "%05d" to write an int padded with zeros to width 5
    void write(std::string filename, bool skip = false) const {
        if (skip) return;
        std::ofstream file;
        file.open(filename, std::ofstream::out | std::ofstream::trunc);
        file << obj.str();
        file.close();
    }

    // Returns the current state of the obj file as a std::string
    std::string to_std_string() const {
        return obj.str();
    }

    // @Incomplete Removes negative indices and polylines/triangle fans to reduce the set of features other obj viewers need to support.
    // MeshLab for example does not support negative indices
    //Obj& simplify_obj() {} // @Incomplete

    // Add anything to the obj file with a given prefix, which defaults to space
    // Note: This function is intended to write structs the obj using operator<< e.g., for annotations
    template <typename T> Obj& insert(const T& anything, const std::string& prefix = " ") {
        obj << prefix << anything;
        return *this;
    }

    // Add an array of anything to the obj file with a given prefix
    template <typename T> Obj& insert(T* anything_array, int count, const std::string& prefix = " ") { 
        if (anything_array == nullptr || count <= 0) {
            return;
        }

        for (int i = 0; i < count; i++) {
            insert(anything_array[i], prefix);
        }

        return *this;
    }

    // Append the other Obj to this one
    // Note: For this to work properly other must be using negative (aka relative) indices
    Obj& append(const Obj& other_obj) {
    	newline();
    	obj << other_obj.obj.rdbuf();
    	return newline();
        // return newline().insert(other.to_std_string(), "").newline();
    }





    //
    // Directives and special characters
    //

    // Add a newline to the obj and reset hash_count
    Obj& newline() { obj << "\n"; hash_count = 0; return *this; }

    // An abbreviated version of the newline function
    Obj& ln() { return newline(); }

    // Add a # character to the current line, this is used for annotations, comments and attributes
    Obj& hash() { obj << "#"; hash_count++; return *this; }

    // Add a vertex directive to start a vertex on the current line
    Obj& v() { obj << "v"; return *this; }

    // Add a vertex normal directive to the current line
    Obj& vn() { obj << "vn"; return *this; }

    // Add a vertex tangent directive to the current line
    Obj& vt() { obj << "vt"; return *this; }

    // Add a point directive to start a point on the current line
    Obj& p() { obj << "p"; return *this;  }

    // Add a line directive to start a segment/polyline on the current line
    Obj& l() { obj << "l"; return *this; }

    // Add a face directive to start a triangle/polygon on the current line
    Obj& f() { obj << "f"; return *this; }

    // Add a group directive. @Incomplete Currently Prism ignores these
    Obj& g() { obj << "g"; return *this; }



    //
    // Annotations. In Prism the text between the first # and a newline or second # is an 'annotation' and can be shown in the viewport
    //

    // If there is no # character on the current line add one, otherwise do nothing
    Obj& annotation() { if (hash_count == 0) { hash(); } return *this; }

    // If there is no # character on the current line add one, otherwise do nothing. Then add " anything" to the obj
    template <typename T> Obj& annotation(const T& anything) { return annotation().insert(anything); }

    // Convenience function to write a newline if the given text is empty and write the text annotation followed by a newline otherwise
    Obj& an(const std::string& text = "") { return text == "" ? newline() : annotation(text).newline(); }

    // Convenience function to write a generic annotation followed by a newline
    template <typename T> Obj& an(const T& anything) { return annotation(anything).newline(); }

    // Add an annotation prefixed with an @ character.
    //
    // In a future version of Prism there will be function to parse numerical data types/colors written to
    // annotations in order to display or process them specially. Multiple distinct data types placed on
    // the same geometry element will be supported and the @ character will be used parse them.  Until this
    // is implemented you might still want to use this function rather than the plain annotation one if you
    // find having the @ prefix helps you read your annotations more clearly.
    template <typename T> Obj& attribute(const T& data) { return annotation().insert(data, " @ "); }





    //
    // Comments. In Prism the text following the second # on a line is considered a comment and is totally ignored
    //

    // Ensure there are two # characters on the current line
    Obj& comment() { while (hash_count < 2) { hash(); } return *this; }

    // Ensure there are two # characters on the current line then add "anything" to the obj
    template <typename T> Obj& comment(T anything) { return comment().insert(anything, ""); }




    //
    // Vectors. Note the preceeding space and no newline
    //

    // Add 2D vector
    // Note: writes " x y" to the obj
    template <typename T> Obj& vector2(T x, T y) { return vector2(Vec2<T>(x, y)); }

    // Add 2D vector
    // Note: writes " v.x v.y" to the obj
    template <typename T> Obj& vector2(Vec2<T> v) { return insert(v); }

    // Add 3D vector
    // Note: writes " x y z" to the obj
    template <typename T> Obj& vector3(T x, T y, T z) { return vector3(Vec3<T>(x, y, z)); }

    // Add 3D vector
    // Note: writes " v.x v.y v.z" to the obj
    template <typename T> Obj& vector3(Vec3<T> v) { return insert(v); }

    // Add 4D vector
    // Note: writes " x y z w" to the obj
    template <typename T> Obj& vector4(T x, T y, T z, T w) { return vector4(Vec4<T>(x, y, z, w)); }

    // Add 4D vector
    // Note: writes " v.x v.y v.z v.w" to the obj
    template <typename T> Obj& vector4(Vec4<T> v) { return insert(v); }




    //
    // Vertices/positions.
    //
    // :ObjIndexing Vertex indexing is 1-based and can be negative:
    // * If index >  0 the index refers to the index-th added vertex
    // * If index <  0 the index refers to index-th preceeding vertex relative to line containing the element with the reference
    // * if index == 0 the index is invalid, this is a silent error
    // Vertices should be referenced by elements that are written later in the obj file
    //

    // Add a 2D position
    // Note: writes "v a.x a.y" to the obj
    template <typename T> Obj& vertex2(Vec2<T> a) { return v().vector2(a); }

    // Add a 3D position
    // Note: writes "v a.x a.y a.z" to the obj
    template <typename T> Obj& vertex3(Vec3<T> a) { return v().vector3(a); }




    //
    // Normals and tangents. Indexing is 1-based, see comment tagged :ObjIndexing
    //

    // Add a 3D normal
    // Note: writes "vn n.x n.y n.z" to the obj
    template <typename T> Obj& normal3(Vec3<T> n) { return vn().vector3(n); }

    // Add a 3D tangent
    // Note: writes "vt t.x t.y t.z" to the obj
    template <typename T> Obj& tangent3(Vec3<T> t) { return vt().vector3(t); }



    //
    // Point elements.  Indices are 1-based, see the comment marked :ObjIndexing
    //

    // Add a point element at i-th vertex
    // Note: writes "p i" to the obj
    Obj& point(int i = -1) { return p().insert(i); }

    // Add a position and a point element that references it
    // Note: writes "v a.x a.y\np -1" to the obj
    template <typename T> Obj& point2(Vec2<T> a) { return vertex2(a).newline().point(); }

    // Add a position and a point element that references it
    // Note: writes "v a\np -1" to the obj
    template <typename T> Obj& point3(Vec3<T> a) { return vertex3(a).newline().point(); }




    //
    // Segments elements.  Indices are 1-based, see the comment marked :ObjIndexing
    //

    // Add a segment element connecting vertices i and j
    // Note: writes "l i j" to the obj
    Obj& segment(int i = -2, int j = -1) { return l().insert(i).insert(j); }

    // Add a 2D segment
    // Note: writes "v a.x a.y\nv b.x b.y\nl -2 -1" to the obj
    template <typename T> Obj& segment2(Vec2<T> a, Vec2<T> b) { return vertex2(a).newline().vertex2(b).newline().segment(); }

    // Add a 3D segment == 3D positions and a segment element
    // Note: writes "v a.x a.y a.z\nv b.x b.y b.z\nl -2 -1" to the obj
    template <typename T> Obj& segment3(Vec3<T> a, Vec3<T> b) { return vertex2(a).newline().vertex2(b).newline().segment(); }




    //
    // Triangle elements.  Indices are 1-based, see the comment marked :ObjIndexing
    //

    // Add a triangle element connecting vertices vi, vj and vk
    // Note: with no parameters writes "f -3 -2 -1" to the obj to refernce the previous 3 vertices
    Obj& triangle(int vi = -3, int vj = -2, int vk = -1) {
        return f().insert(vi).insert(vj).insert(vk);
    }

    // Add a 2D triangle as vertex positions and a face element
    template <typename T> Obj& triangle2(Vec2<T> va, Vec2<T> vb, Vec2<T> vc) {
        vertex2(va).newline();
        vertex2(vb).newline();
        vertex2(vc).newline();
        return triangle();
    }

    // Add a 3D triangle as vertex positions and a face element
    template <typename T> Obj& triangle3(Vec3<T> va, Vec3<T> vb, Vec3<T> vc) {
        vertex3(va).newline();
        vertex3(vb).newline();
        vertex3(vc).newline();
        return triangle();
    }

    // Add a triangle element connecting vertices vi, vj and vk, with vertex normals ni, nj and nk
    // Note: with no parameters writes "f -3//-3 -2//-2 -1//-1" to the obj to reference the previous 3 vertices and normals
    Obj& triangle_vn(int vi = -3, int vj = -2, int vk = -1, int ni = -3, int nj = -2, int nk = -1) {
        f();
        insert(vi).insert("//", "").insert(ni, "");
        insert(vj).insert("//", "").insert(nj, "");
        insert(vk).insert("//", "").insert(nk, "");
        return *this;
    }

    // Add a triangle element connecting vertices vi, vj and vk with vertex normals ni, nj and nk and tangents ti, tj and tk
    // Note: with no parameters writes "f -3/-3/-3 -2/-2/-2 -1/-1/-1" to the obj to reference the previous 3 vertices, normals and tangents
    Obj& triangle_vnt(int vi = -3, int vj = -2, int vk = -1, int ni = -3, int nj = -2, int nk = -1, int ti = -3, int tj = -2, int tk = -1) {
        f();
        insert(vi).insert("/", "").insert(ti).insert("/", "").insert(ni, "");
        insert(vj).insert("/", "").insert(tj).insert("/", "").insert(nj, "");
        insert(vk).insert("/", "").insert(tk).insert("/", "").insert(nk, "");
        return *this;
    }

    // Add a 3D triangle as vertex positions, vertex normals and a face element
    template <typename T> Obj& triangle3_vn(Vec3<T> va, Vec3<T> vb, Vec3<T> vc, Vec3<T> na, Vec3<T> nb, Vec3<T> nc) {
        vertex3(va).newline().vn().vector3(na).newline();
        vertex3(vb).newline().vn().vector3(nb).newline();
        vertex3(vc).newline().vn().vector3(nc).newline();
        return triangle_vn();
    }

    // Add a 3D triangle as vertex positions, normals, tangents and a face element
    template <typename T> Obj& triangle3_vnt(Vec3<T> va, Vec3<T> vb, Vec3<T> vc, Vec3<T> na, Vec3<T> nb, Vec3<T> nc, Vec3<T> ta, Vec3<T> tb, Vec3<T> tc) {
        vertex3(va).newline().vn().vector3(na).newline().vt().vector3(ta).newline();
        vertex3(vb).newline().vn().vector3(nb).newline().vt().vector3(tb).newline();
        vertex3(vc).newline().vn().vector3(nc).newline().vt().vector3(tc).newline();
        return triangle_vnt();
    }





    //
    // Polylines. These are sequences of segment elements
    //

    // Add a polyline element to the obj which refers to the previous N vertices
    Obj& polyline(int N) {
        l();
        for (int i = -N; i < 0; i++) insert(i);
        return *this;
    }

    // Add a polyline element to the obj which refers to the given vertex indices
    Obj& polyline(int N, int i, int j, ...) {
        segment(i, j);
        va_list va;
        va_start(va, j);
        for (int n = 0; n < N-2; n++) insert(va_arg(va, int));
        va_end(va);
        return *this;
    }

    // Add a 2D polyline as a point count and a pointer to a [X1, Y1, X2, Y2, ... XN, YN] coordinate buffer.
    // If closed write the first point index again at the end o the l-directive
    template <typename T> Obj& polyline2(int N, T* XYs, bool closed = false) {
        return poly_impl('l', N, XYs, 2, closed);
    }

    // Add a 3D polyline as a point count and a pointer to a [X1, Y1, Z1, X2, Y2, Z2, ... XN, YN, ZN] coordinate buffer.
    // If closed write the first point index again at the end of the l-directive
    template <typename T> Obj& polyline3(int N, T* XYs, bool closed = false) {
        return poly_impl('l', N, XYs, 3, closed);
    }

    // Add a 2D polyline [p1, p2, p3, ... pN] as a variadic call
    template <typename T> Obj& polyline2(int N, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex2_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polyline(N);
    }

    // Add a 3D polyline [p1, p2, p3, ... pN] as a variadic call
    template <typename T> Obj& polyline3(int N, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex3_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polyline(N);
    }





    //
    // Axis-aligned boxes.
    //

    // Add a box region defined by min/max visualized with edges (default) or single polygon
    template <typename T> Obj& box2_min_max(Vec2<T> min, Vec2<T> max, bool use_segments = true) {
        if (use_segments) {
            return polyline2(5, min, Vec2<T>{max.x,min.y}, max, Vec2<T>{min.x,max.y}, min);
        }
        return polygon2(5, min, Vec2<T>{max.x,min.y}, max, Vec2<T>{min.x,max.y}, min);
    }

    // Add a box region defined by min/max visualized with edges (default) or single polygon
    // Note: This function 
    template <typename T> Obj& box3_min_max(Vec3<T> min, Vec3<T> max, bool use_segments = true) {
        if (use_segments) {
        	// This has some redundant edges but having them means we can annotate the shape conveniently
            Vec3<T> p000{min.x, min.y, min.z}, p100{max.x, min.y, min.z}, p010{min.x, max.y, min.z}, p110{max.x, max.y, min.z};
            Vec3<T> p001{min.x, min.y, max.z}, p101{max.x, min.y, max.z}, p011{min.x, max.y, max.z}, p111{max.x, max.y, max.z};
        	polyline3(16, p000, p100, p110, p010, p000, p001, p101, p100, p101, p111, p110, p111, p011, p010, p011, p001);
            return *this;
        }
        // polygon3().newline();
        // polygon3().newline();
        // polygon3().newline();
        // polygon3().newline();
        // polygon3().newline();
        // polygon3().newline();
        return *this;
    }

    // Add a box region defined by a center point and extents vector (the side lengths of the box)
    template <typename T> Obj& box2_center_extents(Vec2<T> center, Vec2<T> extents, bool use_segments = true) {
        if (use_segments) {
            return polyline2<T>({center.x - extents.x/2, center.y - extents.y/2}, {center.x + extents.x/2, center.y + extents.y/2});
        }
        return polygon2<T>({center.x - extents.x/2, center.y - extents.y/2}, {center.x + extents.x/2, center.y + extents.y/2});
    }




    //
    // Polygons. These are sequences of triangle elements aka triangle fans
    //

    // Add a polygon element to the obj which refers to the previous N vertices
    Obj& polygon(int N) {
        f();
        for (int i = -N; i < 0; i++) insert(i);
        return *this;
    }

    // Add a polygon element to the obj which refers to the given vertex indices
    Obj& polygon(int N, int i, int j, int k, ...) {
        triangle(i, j, k);
        va_list va;
        va_start(va, k);
        for (int n = 0; n < N-3; n++) insert(va_arg(va, int));
        va_end(va);
        return *this;
    }

    // Add a 2D polygon as a point count and a pointer to a [X1, Y1, X2, Y2, ... XN, YN] coordinate buffer
    template <typename T> Obj& polygon2(int N, T* XYs) { return poly_impl('f', N, XYs, 2); }

    // Add a 3D polygon as a point count and a pointer to a [X1, Y1, Z1, X2, Y2, Z2, ... XN, YN, ZN] coordinate buffer
    template <typename T> Obj& polygon3(int N, T* XYs) { return poly_impl('f', N, XYs, 3); }

    // Add a 2D polygon [p1, p2, p3, ... pN] as a variadic call
    template <typename T> Obj& polygon2(int N, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex2_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polygon(N);
    }

    // Add a 3D polygon [p1, p2, p3, ... pN] as a variadic call
    template <typename T> Obj& polygon3(int N, Vec3<T> p1, Vec3<T> p2, Vec3<T> p3, ...) {
        va_list va;
        va_start(va, p3);
        vertex3_variadic(N, p1, p2, p3, va);
        va_end(va);
        return polygon(N);
    }





    //
    // Configuration functions
    //

    // Set the precision used to write floats to the obj
    Obj& set_precision(int n = 6) { obj.precision(n); return *this; }

    // Set the precision used to write floats to the obj
    template <typename T> Obj& set_precision_digits10() { return set_precision(std::numeric_limits<T>::digits10); }

    // Set the precision used to write floats to the obj. Use this function to ensure you can round-trip from float to decimal and back
    // See https://randomascii.wordpress.com/2012/02/11/they-sure-look-equal/ for details
    template <typename T> Obj& set_precision_max_digits10() { return set_precision(std::numeric_limits<T>::max_digits10); }

	// struct Item_Style
 //    {
	//     Vec4 Color;
 //    };



    //
    // Implementation methods
    //

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

    template <typename T> Obj& vertex2_variadic(int point_count, Vec2<T> p1, Vec2<T> p2, Vec2<T> p3, va_list va) {
        vertex2(p1).newline().vertex2(p2).newline().vertex2(p3).newline();
        for (int i = 0; i < point_count-3; i++) {
            Vec2<T> pn = va_arg(va, Vec2<T>);
            vertex2(pn).newline();
        }
        return *this;
    }

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


void usage_example(bool write_files) {

    auto test = [&write_files](std::string filename, std::string got, std::string wanted) {
        bool passed = true;
        if (wanted == got) {
            std::cout << "Test " << filename << "() PASSED..." << std::endl;
        } else {
            std::cout << "Test " << filename << "() FAILED..." << std::endl;
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
    };

    // Basic example
    {
        using namespace prism; // Access Obj struct and vector typedefs

        // Data for a star-shape. Use a union so we can demo two different APIs
        union {
            double coords[8*2] = {
                2, 2, 10, 0, 2, -2, 0, -10, -2, -2, -10, 0, -2, 2, 0, 10
            };
            struct {
                V2 a, b, c, d, e, f, g, h;
            } points;
        } star;

    	// First create an Obj and add a comment at the top of the file
        Obj obj;
        obj.comment("This file tests a the Prism C++ API").newline();

        // Now we'll write 3 vertices and a triangle element in a very verbose way
        obj.vertex2(V2{0., 0.}).newline();
        obj.vertex2(V2{1., 0.}).newline();
        obj.vertex2(V2{1., 1.}).newline();
        obj.triangle().annotation("2D triangle").newline();

        // That was a lot of typing... you can do something similar in 1 line.
        obj.triangle3(V3{0., 0., 2.}, V3{1., 0., 2.}, V3{1., 1., 2.}).an("3D triangle");
        // (You would need to use the verbose version if you wanted to annotate the triangle vertices)

        // Write a star shaped polygon written using a variadic function call
        obj.polygon2(8, star.points.a, star.points.b, star.points.c, star.points.d, star.points.e, star.points.f, star.points.g, star.points.h).an("star polygon");
        
        // Write the boundary of the above polygon using a pointer-to-buffer API 
        obj.polyline2(8, star.coords, true).an("star boundary");

    	obj.box3_min_max(V3{3, 3, 3}, V3{7, 7, 7}).newline();

        // Here we'll write a 2D point with some attributes, which are annotations prefixed with an @ to
        // make them distinguishable. Note that both the annotation and attribute functions support any
        // type which has an operator<< defined.
    	V2 bla;
        obj.point2(V2{3., 3.}).attribute("some string").attribute(42).attribute(V2{0.,0.}).newline();


    	std::string wanted = R"DONE(##This file tests a the Prism C++ API
v 0 0
v 1 0
v 1 1
f -3 -2 -1# 2D triangle
v 0 0 2
v 1 0 2
v 1 1 2
f -3 -2 -1# 3D triangle
v 2 2
v 10 0
v 2 -2
v 0 -10
v -2 -2
v -10 0
v -2 2
v 0 10
f -8 -7 -6 -5 -4 -3 -2 -1# star polygon
v 2 2
v 10 0
v 2 -2
v 0 -10
v -2 -2
v -10 0
v -2 2
v 0 10
l -8 -7 -6 -5 -4 -3 -2 -1 -8# star boundary
v 3 3
p -1# @ some string @ 42 @ 0 0
)DONE";

        test("prism_example_overview_api.obj", obj.to_std_string(), wanted);
    }

    // If you use relative indexing you can use the append function to concatenate different obj files
    {
        using namespace prism; // Access Obj struct and vector typedefs

        Obj first, second;
    	
		// Add some geometry to the first obj
    	first.segment2(V2{0, 0}, V2{1, 0});
    	
		// Add some geometry to the second obj
    	second.point3(V3{1, 2, 3});

    	// Concatenate the first and second obj
    	Obj combined;
    	combined.comment("The first obj:").append(first).comment("The second obj:").append(second);

    	std::string wanted = R"DONE(##The first obj:
v 0 0
v 1 0
l -2 -1
##The second obj:
v 1 2 3
p -1
)DONE";
    
        test("prism_example_combined.obj", combined.to_std_string(), wanted);
    }

    // One-liner example
    {
        using namespace prism; // Access Obj and vector typedefs

        // We don't test this function to keep everything on a single line
        if (write_files) {
            std::string filename = "prism_example_oneliner.obj";
            Obj().triangle2(V2{0., 0.}, V2{1., 0.}, V2{1., 1.}).an("triangle").point2(V2{3., 3.}).an("point").write(filename);
            std::cout << "Wrote " << filename << std::endl;
        }
    }

    // This is a bit wacky but you could also use the Obj class as a file logger
	// that has nothing to do with the obj format
    {
        Obj obj;
        obj.insert("some int = ").insert(5).newline();
        obj.insert("some type with operator<< = ").insert(V2{2, 3}).newline();
        if (true) {
            obj.insert("condition passed on line ").insert(__LINE__);
            obj.insert("\n"); // We don't care about tracking # chars so just log special characters directly
        }

        // We don't test this function because the __LINE__ macro makes it brittle
        if (write_files) {
            std::string filename = "prism_example_printf_logging.obj";
            obj.write(filename);
            std::cout << "Wrote " << filename << std::endl;
        }
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