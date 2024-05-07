"""A Python API for Prizm.

Usage example:

    import sys
    sys.path.append("/path/to/Prizm/api/python/")
    import Prizm

    import Prizm as pz # nocommit How to get this included wherever?
    Prizm.documentation()

nocommit Run pylint

"""

import dataclasses
import io

from typing import Self, Any

# Internal data used to control the precision with which float data is written to the OBJ file
# This should be manipulated via the Obj.set_precision function. By default write with enough
# precision to round-trip from float64 to decimal and back Note: Prizm currently stores mesh
# data using float32, we will move to float64 so we can show coordinate labels at full precision
_prizm_float_precision: int = 17

@dataclasses.dataclass
class Vec2:
    x: float = 0
    y: float = 0

    def __str__(self) -> str:
        return f'{self.x:.{_prizm_float_precision}g} {self.y:.{_prizm_float_precision}g}'

    @classmethod
    def from_other(cls, other):
        return cls(x=other.x, y=other.y)


@dataclasses.dataclass
class Vec3:
    x: float = 0
    y: float = 0
    z: float = 0

    def __str__(self) -> str:
        return f'{self.x:.{_prizm_float_precision}g} {self.y:.{_prizm_float_precision}g} {self.z:.{_prizm_float_precision}g}'

    @classmethod
    def from_other(cls, other):
        return cls(x=other.x, y=other.y, z=other.z)


@dataclasses.dataclass
class Vec4:
    x: float = 0
    y: float = 0
    z: float = 0
    w: float = 0

    def __str__(self) -> str:
        return f'{self.x:.{_prizm_float_precision}g} {self.y:.{_prizm_float_precision}g} {self.z:.{_prizm_float_precision}g} {self.w:.{_prizm_float_precision}g}'

    @classmethod
    def from_other(cls, other):
        return cls(x=other.x, y=other.y, z=other.z, w=other.w)

@dataclasses.dataclass
class Color:
    """A linear color type. rgba components should be integers in the range [0,255]"""
    r: int = 0
    g: int = 0
    b: int = 0
    a: int = 0

    def __str__(self) -> str:
        return f'{self.r} {self.g} {self.b} {self.a}'

    def __post_init__(self):
        components = [self.r, self.g, self.b, self.a]
        if any(not isinstance(c, int) for c in components):
            raise TypeError("rgba components must be integers.")
        if any(c < 0 or c > 255 for c in components):
            raise ValueError("rgba components must be in the range [0, 255].")

    @classmethod
    def from_other(cls, other):
        # nocommit Check that __post_init__ is called in this case
        return cls(r=other.r, g=other.g, b=other.b, a=other.a)

    @classmethod
    def from_matplotlib(cls, color):
        """Create a Color instance from a matplotlib color e.g., 'skyblue', "#00FF00", (.5, .2, .8)"""

        # We delay this import so we only depend on matplotlib if you actually use this function
        import matplotlib.colors as mcolors

        rgba = mcolors.to_rgba(color)
        # Convert from float (0 to 1 range) to int (0 to 255 range)
        rgba_scaled = [int(255 * c) for c in rgba]
        return cls(*rgba_scaled)

# Convenience aliases for VecN types
V2 = Vec2
V3 = Vec3
V4 = Vec4

## Built-in Colors
#BLACK  = Color(0, 0, 0, 255)
#WHITE  = Color(255, 255, 255, 255)
#RED    = Color(255, 0, 0, 255)
#GREEN  = Color(0, 255, 0, 255)
#BLUE   = Color(0, 0, 255, 255)
#YELLOW = Color(255, 255, 0, 255)

# Map from input types to the corresponding conversion functions
# You can use this function directly or use the auto_convert_types decorator to apply it implicitly
# nocommit See documentation() for more details
conversion_map = {
    Vec2: Vec2.from_other,
    Vec3: Vec3.from_other,
    Vec4: Vec4.from_other,
    Color: Color.from_other,
}

def auto_convert_types(type_map):

    # We delay this import so we only depend on functools if you actually use this function
    from functools import wraps

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            new_args = [
                type_map.get(type(arg), lambda x: x)(arg) if type(arg) not in type_map.values() else arg
                for arg in args
            ]
            new_kwargs = {
                k: type_map.get(type(v), lambda x: x)(v) if type(v) not in type_map.values() else v
                for k, v in kwargs.items()
            }
            return func(*new_args, **new_kwargs)
        return wrapper
    return decorator



class Obj:
    """
    Writes OBJ files and Prizm-specific extensions.

    See the documentation() function for a demo of the API, although it should be self-explanatory.

    The following page was the reference for the OBJ format: http://paulbourke.net/dataformats/obj/
    (not everything on that page is implemented). Note Prizm-specific extensions are designed so that
    OBJ files containing such extensions will always open in other OBJ viewers.
    """

    #
    # Basic functions
    #

    def __init__(self):
        # Current contents of the OBJ file
        self.obj = io.StringIO()

        # Number of hash characters on the current line, these are significant for Prizm:
        # 0 hash characters => writing geometry
        # 1 hash character  => writing an annotation. Prizm stores the text between the first hash and a newline/second hash as an annotation
        # 2 hash characters => writing a comment. Prizm ignores everything following the second hash character on a line
        self.hash_count = 0

        # Number of v-directives written to `obj`
        self.v_count = 0

        # Number of vn-directives written to `obj`
        self.vn_count = 0

        # Number of vt-directives written to `obj`
        self.vt_count = 0

        # See the docstring for set_use_negative_indices()
        self.use_negative_indices = True

        self.set_precision()



    def add(self, anything: Any) -> Self:
        """Add anything to the obj file"""
        if anything:
            self.obj.write(str(anything))
        return self

    def insert(self, anything: Any) -> Self:
        """Add anything to the obj file but prefix with a space character"""
        if anything:
            self.space().add(str(anything))
        return self

    def append(self, other: Self) -> Self:
        """Add a newline, then add the `other` obj and then add another newline
        Note: `other` must exclusively use negative (aka relative) indices"""
        other_content = other.obj.getvalue()
        if other_content:
            self.newline().add(other_content)
        return self



    #
    # Output functions
    #

    def write(self, filename: str) -> Self:
        """
        Write data to a file

        Tip: Use format string "{N:05}" to write N padded with zeros to width 5. This is useful for logging the
        progress of an algorithm, you will also need to use the same prefix and you may need to run the
        `sort_by_name` console command in Prizm to put the item list into a state where you can use Ctrl LMB or
        Shift LMB while sweeping the cursor over the visibility checkboxes to create a progress animation.
        """
        with open(filename, mode="w") as file:
            file.write(self.obj.getvalue())
            self.obj.close()
        return self

    def __str__(self) -> str:
        """Returns the current state of the obj file as a string"""
        return self.obj.getvalue()



    #
    # Directives and special characters/strings
    #


    def v(self) -> Self:
        """Add a vertex directive to start a vertex on a new line"""
        self.v_count += 1
        self.newline().add('v')
        return self

    def vn(self) -> Self:
        """Add a vertex normal directive on a new line"""
        self.vn_count += 1
        self.newline().add("vn")
        return self

    def vt(self) -> Self:
        """Add a texture vertex directive on a new line"""
        self.vt_count += 1
        self.newline().add("vt")
        return self

    def p(self) -> Self:
        """Add a point directive to start a point on a new line"""
        self.newline().add('p')
        return self

    def l(self) -> Self:
        """Add a line directive to start a segment/polyline on a new line"""
        self.newline().add('l')
        return self

    def f(self) -> Self:
        """Add a face directive to start a triangle/polygon on a new line"""
        self.newline().add('f')
        return self

    def g(self) -> Self:
        """Add a group directive on the current line.  Note: Currently Prizm ignores these"""
        self.newline().add('g')
        return self

    def newline(self, count = 1) -> Self:
        """Add a newline to the obj and reset hash_count"""
        while count > 0:
            self.hash_count = 0
            self.add("\n")
            count -= 1
        return self

    def space(self) -> Self:
        """Add a space to the obj"""
        self.add(' ')
        return self

    def hash(self, count: int = 1) -> Self:
        """Add a # character to the current line, this is used for annotations, comments and attributes"""
        while count > 0:
            self.hash_count += 1
            self.add("#")
            count -= 1
        return self

    def bang(self) -> Self:
        """Add a ! character to the current line, this is used by command annotations"""
        self.add('!')
        return self

    def at(self) -> Self:
        """Add an @ character to the current line, this is used for attributes"""
        self.add('@')
        return self






    #
    # Annotations.
    #
    # In Prizm the text between the first hash and a newline or second hash is an 'annotation string' and can be shown in the viewport.

    def annotation(self, data: Any) -> Self:
        """Start an annotation (if there is no hash character on the current line add one, otherwise do nothing)
        and then add an annotation containing the given data to the obj."""
        if self.hash_count == 0:
            # Add a space here to help other obj viewers which might fail to parse numbers not delimited by whitespace
            self.space().hash()
        self.insert(data)
        return self





    #
    # Comments.
    #
    # In Prizm any text that follows the second # on a line is ignored
    #

    def comment(self, content: str = "") -> Self:
        """Ensure there are two # characters on the current line then insert the comment content"""
        while self.hash_count < 2: self.hash()
        if str: self.insert(content)
        else: self.add(content)
        return self




    #
    # Vectors
    #

    def vector2(self, x: float, y: float) -> Self:
        """Add 2D vector. Writes " x y" to the obj"""
        return self.vector2(Vec2(x, y))

    def vector2(self, v: Vec2) -> Self:
        """Add 2D vector. Writes " v.x v.y" to the obj"""
        return self.insert(v)

    def vector3(self, x: float, y: float, z: float) -> Self:
        """Add 3D vector. Writes " x y z" to the obj"""
        return self.vector3(Vec3(x, y, z))

    def vector3(self, v: Vec3) -> Self:
        """Add 3D vector. Writes " v.x v.y v.z" to the obj"""
        return self.insert(v)

    def vector4(self, x: float, y: float, z: float, w: float) -> Self:
        """Add 4D vector. Writes " x y z w" to the obj"""
        return self.vector4(Vec4(x, y, z, w))

    def vector4(self, v: Vec4) -> Self:
        """Add 4D vector. Writes " v.x v.y v.z v.w" to the obj"""
        return self.insert(v)




    #
    # Vertices/Positions.
    #
    # :ObjIndexing Vertex indexing is 1-based and can be negative:
    # * If index >  0 the index refers to the index-th added vertex
    # * If index <  0 the index refers to index-th preceeding vertex relative to line containing the element with the reference
    # * if index == 0 the index is invalid, this is a (silent!) error
    # Vertices should be referenced by elements that are written later in the obj file
    #

    def vertex2(self, a: Vec2) -> Self:
        """Add a 2D position. Writes "\nv a.x a.y" to the obj"""
        return self.v().vector2(a)

    def vertex3(self, a: Vec3) -> Self:
        """Add a 3D position. Writes "\nv a.x a.y a.z" to the obj"""
        return self.v().vector3(a)




    #
    # Normals, Textures, Tangents. Indexing is 1-based, see :ObjIndexing
    #

    def normal3(self, n: Vec3) -> Self:
        """Add a 3D normal. Writes "\nvn n.x n.y n.z" to the obj"""
        return self.vn().vector3(n)

    def uv2(self, t: Vec2) -> Self:
        """Add a UV coordinate (2D texture vertex). Writes "\nvt t.x t.y" to the obj"""
        return self.vt().vector2(t)

    def tangent3(self, t: Vec3) -> Self:
        """Add a 3D tangent (3D texture vertex). Writes "\nvt t.x t.y t.z" to the obj"""
        return self.vt().vector3(t)



    //
    // Point Elements.  Indices are 1-based, see :ObjIndexing
    //

    // Add a point element referencing the i-th vertex position
    Obj& point(int i = -1) {
        return p().insert(v_index(i));
    }

    // Add a oriented point element referencing the previous vertex position and normal (default).
    // The user can provide explicit indicies to reference vertex vi and normal ni
    Obj& point_vn(int vi = -1, int ni = -1) {
        return p().insert(v_index(vi)).add("//").add(vn_index(ni));
    }

    // Add a vertex position and a point element that references it
    template <typename T> Obj& point2(Vec2<T> a) {
        return vertex2(a).point();
    }

    // Add a vertex position and a point element that references it
    template <typename T> Obj& point3(Vec3<T> a) {
        return vertex3(a).point();
    }

    // Add a vertex position, a normal and an oriented point element referencing them
    template <typename T> Obj& point3_vn(Vec3<T> va, Vec3<T> na) {
        return vertex3(va).normal3(na).point_vn();
    }


    //
    // Segment Elements.  Indices are 1-based, see :ObjIndexing
    //

    // Add a segment element connecting vertices vi and vj
    Obj& segment(int vi = -2, int vj = -1) {
        return l().insert(v_index(vi)).insert(v_index(vj));
    }

    // Add an oriented segment element referencing the 2 previous vertex positions and normals (default).
    // The user can provide explicit indicies to reference vertices vi/ vj and normals ni/nj
    Obj& segment_vn(int vi = -2, int vj = -1, int ni = -2, int nj = -1) {
        return l().insert(v_index(vi)).add("//").add(vn_index(ni)).insert(v_index(vj)).add("//").add(vn_index(nj));
    }

    // Add 2 vertex positions and a segment element referencing them
    template <typename T> Obj& segment2(Vec2<T> a, Vec2<T> b) {
        return vertex2(a).vertex2(b).segment();
    }

    // Add 2 vertex positions and a segment element referencing them
    template <typename T> Obj& segment3(Vec3<T> a, Vec3<T> b) {
        return vertex3(a).vertex3(b).segment();
    }

    // Add 2 vertex positions, 2 vertex normals and an oriented segment element referencing them
    template <typename T> Obj& segment3_vn(Vec3<T> va, Vec3<T> vb, Vec3<T> na, Vec3<T> nb) {
        return vertex3(va).normal3(na).vertex3(vb).normal3(nb).segment_vn();
    }




    #
    # Triangle Elements.  Indices are 1-based, see :ObjIndexing
    #

    def triangle(self, vi: int = -3, vj: int = -2, vk: int = -1) -> Self:
        """Add a triangle element referencing the 3 previous vertex positions (default).
        The user can provide explicit indicies to reference vertices vi, vj and vk"""
        self.f()
        self.insert(self.v_index(vi))
        self.insert(self.v_index(vj))
        self.insert(self.v_index(vk))
        return self




    #
    # Obj file configuration functions
    #

    def set_precision(self, n = 17) -> Self:
        """Set the number of base-10 digits used to write floating-point numbers to the obj. By default this function is
        equivalent to calling `set_precision_to_roundtrip_floats()`

        This function is useful to improve annotation readability by reducing the number of base-10 digits used to write
        float data.  After writing such an annotation you will probably want to restore the value used for coordinate
        data, probably by calling this function with no arguments, to restore the precision that round-trips from double
        to decimal text to double.

        This function doesn't need to be in the Obj interface but its convenient to have it here for chained calls
        """
        global _prizm_float_precision
        _prizm_float_precision = n
        return self


    def set_precision_to_roundtrip_floats(self) -> Self:
        """Set the number of base-10 digits used to write floating-point numbers to the obj to a value which can round-trip
        from Float to decimal text to Float."""

        # "Unlike most mathematical operations, the conversion of a floating-point value to text and back is exact as long
        # as at least max_digits10 were used (9 for float, 17 for double): it is guaranteed to produce the same
        # floating-point value, even though the intermediate text representation is not exact. It may take over a hundred
        # decimal digits to represent the precise value of a float in decimal notation."
        # https://en.cppreference.com/w/cpp/types/numeric_limits/max_digits10
        self.set_precision(17)
        return self

    def set_use_negative_indices(self, value: bool) -> Self:
        """If true (default) then functions where the user has not explicity passed indices will use negative indices to refer to vertex data
        If false then the the above counts will be used to use positive indices when referring to vertex data.

        Using negative indices is the default because it means the Obj can be concatenated with other Objs (which
        must also be using negative indices) to write a single file (see Prizm::Obj::append). The downsides of doing
        this is are i) the obj file may not load in viewers other than Prizm since negative indices seem not to be
        well supported, and ii) triangles are written as a disconnected soup which increases file size due to
        duplicated vertex data"""
        self.use_negative_indices = value
        return self




    #
    # Implementation methods
    #

    def v_index(self, i: int) -> int:
        """Return the v-directive index to use"""
        return i if (i > 0 or self.use_negative_indices) else self.v_count + 1 + i

    def vn_index(self, i: int) -> int:
        """Return the vn-directive index to use"""
        return i if (i > 0 or self.use_negative_indices) else self.vn_count + 1 + i

    def vt_index(self, i: int) -> int:
        """Return the vt-directive index to use"""
        return i if (i > 0 or self.use_negative_indices) else self.vt_count + 1 + i



def documentation():
    """An example using the API and an explanation of the rationale behind it.
    Returns boolean to indicate if the documentation tests pass"""

    # First we'll add a comment at the top of the file. If you look at the `output` string below you can see that
    # the provided text is prefixed by ## in the obj file, the obj spec uses a # to start a comment.
    obj = Obj()

    # First we'll add a comment at the top of the file. If you look at the `output` string below you can see that
    # the provided text is prefixed by ## in the obj file, the obj spec uses a # to start a comment.
    obj.comment("This file tests the Prizm Python API")

    # Now we'll write 3 vertices and a triangle element in a very verbose way. Note that most functions in the
    # `Obj` API return `Obj&` which allows you to chain calls which can be handy if you like your debugging code
    # to be concise
    obj.vertex3(V3(0., 0., 1.)).annotation("Vertex A");
    obj.vertex3(V3(3., 0., 1.)).annotation("Vertex B");
    obj.vertex3(V3(3., 3., 1.)).annotation("Vertex C");
    obj.triangle().annotation("Triangle ABC");

    print(obj)

    obj.write("test.obj")
    obj.obj.close()


if __name__ == "__main__":
    documentation()