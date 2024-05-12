"""A Python API to write OBJ files with Prizm-specific extensions.

See the documentation() function for a demo of the API, although it should be self-explanatory.
"""

import dataclasses
import io
from typing import Self, Any, Tuple


@dataclasses.dataclass
class Vec2:
    """A 2D vector class which converts to a string suitable for writing to an OBJ file"""

    __slots__=('x','y')
    x: float
    y: float

    def __str__(self) -> str:
        """Return an OBJ string representation with the configured precision"""
        return f'{self.x:.{_prizm_float_precision}g} {self.y:.{_prizm_float_precision}g}'

    @classmethod
    def from_xy(cls, other):
        """Construct from objects with .x and .y attributes"""
        return cls(x=other.x, y=other.y)


@dataclasses.dataclass
class Vec3:
    """A 3D vector class which converts to a string suitable for writing to an OBJ file"""

    __slots__=('x','y','z')
    x: float
    y: float
    z: float

    def __str__(self) -> str:
        """Return an OBJ string representation with the configured precision"""
        return f'{self.x:.{_prizm_float_precision}g} {self.y:.{_prizm_float_precision}g} {self.z:.{_prizm_float_precision}g}'

    @classmethod
    def from_xyz(cls, other):
        """Construct from objects with .x, .y and .z attributes"""
        return cls(x=other.x, y=other.y, z=other.z)


@dataclasses.dataclass
class Vec4:
    """A 4D vector class which converts to a string suitable for writing to an OBJ file"""

    __slots__=('x','y','z','w')
    x: float
    y: float
    z: float
    w: float

    def __str__(self) -> str:
        """Return an OBJ string representation with the configured precision"""
        return f'{self.x:.{_prizm_float_precision}g} {self.y:.{_prizm_float_precision}g} {self.z:.{_prizm_float_precision}g} {self.w:.{_prizm_float_precision}g}'

    @classmethod
    def from_xyzw(cls, other):
        """Construct from objects with .x, .y, .z and .w attributes"""
        return cls(x=other.x, y=other.y, z=other.z, w=other.w)

@dataclasses.dataclass
class Color:
    """A linear color type with integer rgba components in the range [0,255] which converts
    to a string suitable for writing to an OBJ as the color argument of a command annotation"""

    __slots__=('r','g','b','a')
    r: int
    g: int
    b: int
    a: int

    def __str__(self) -> str:
        """Return an OBJ string representation usable as color arguments of command annotations"""
        return f'{self.r} {self.g} {self.b} {self.a}'

    def __post_init__(self):
        components = [self.r, self.g, self.b, self.a]
        if any(not isinstance(c, int) for c in components):
            raise TypeError("rgba components must be integers.")
        if any(c < 0 or c > 255 for c in components):
            raise ValueError("rgba components must be in the range [0, 255].")

    @classmethod
    def from_rgba(cls, rgba):
        """Construct from objects with .r, .g, .b and .a attributes"""
        return cls(r=rgba.r, y=rgba.y)

    @classmethod
    def from_matplotlib(cls, color):
        """Create a Color instance from a matplotlib color e.g., 'skyblue', "#00FF00", (.5, .2, .8)"""

        # We delay this import so we only depend on/wait for matplotlib if you actually use this function
        import matplotlib.colors as mcolors

        rgba = mcolors.to_rgba(color)
        rgba_scaled = [int(255 * c) for c in rgba]
        return cls(*rgba_scaled)



# Built-in Colors
BLACK   = Color(  0,   0,   0, 255)
WHITE   = Color(255, 255, 255, 255)
RED     = Color(255,   0,   0, 255)
GREEN   = Color(  0, 255,   0, 255)
BLUE    = Color(  0,   0, 255, 255)
AQUA    = Color(  0, 255, 255, 255)
MAGENTA = Color(255,   0, 255, 255)
YELLOW  = Color(255, 255,   0, 255)




class Obj:
    """
    Writes OBJ files and Prizm-specific extensions.

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
        self.obj.write(str(anything))
        return self

    def insert(self, anything: Any) -> Self:
        """Add anything to the obj file but prefix with a space character"""
        self.space().add(str(anything))
        return self

    def append(self, other: Self) -> Self:
        """Add a newline, then add the `other` obj and then add another newline
        Note: `other` must exclusively use negative (aka relative) indices"""
        buf = other.obj.getvalue()
        if buf:
            self.newline().add(buf)
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
        with open(filename, mode="w", encoding='ascii') as file:
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

    def comment(self, content: str) -> Self:
        """Ensure there are two # characters on the current line then insert the comment content"""
        while self.hash_count < 2:
            self.hash()
        self.insert(content)
        return self




    #
    # Vectors
    #

    def vector2(self, v: Vec2) -> Self:
        """Add 2D vector. Writes " v.x v.y" to the obj"""
        assert type(v) == Vec2, f"Expected {Vec2}, got {type(v)}"
        return self.insert(v)

    def vector3(self, v: Vec3) -> Self:
        """Add 3D vector. Writes " v.x v.y v.z" to the obj"""
        assert type(v) == Vec3, f"Expected {Vec3}, got {type(v)}"
        return self.insert(v)

    def vector4(self, v: Vec4) -> Self:
        """Add 4D vector. Writes " v.x v.y v.z v.w" to the obj"""
        assert type(v) == Vec4, f"Expected {Vec4}, got {type(v)}"
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



    #
    # Point Elements.  Indices are 1-based, see :ObjIndexing
    #


    def point(self, i:int = -1) -> Self:
        """Add a point element referencing the i-th vertex position"""
        return self.p().insert(self.v_index(i))

    def point_vn(self, vi:int = -1, ni:int = -1) -> Self:
        """Add a oriented point element referencing the previous vertex position and normal (default).
        The user can provide explicit indicies to reference vertex vi and normal ni"""
        return self.p().insert(self.v_index(vi)).add("//").add(self.vn_index(ni))

    def point2(self, a: Vec2) -> Self:
        """Add a vertex position and a point element that references it"""
        return self.vertex2(a).point()

    def point3(self, a: Vec3) -> Self:
        """Add a vertex position and a point element that references it"""
        return self.vertex3(a).point()

    def point3_vn(self, va: Vec3, na: Vec3) -> Self:
        """Add a vertex position, a normal and an oriented point element referencing them"""
        return self.vertex3(va).normal3(na).point_vn()


    #
    # Segment Elements.  Indices are 1-based, see :ObjIndexing
    #

    def segment(self, vi:int = -2, vj:int = -1) -> Self:
        """Add a segment element connecting vertices vi and vj"""
        return self.l().insert(self.v_index(vi)).insert(self.v_index(vj))

    def segment_vn(self, vi:int = -2, vj:int = -1, ni:int = -2, nj:int = -1) -> Self:
        """Add an oriented segment element referencing the 2 previous vertex positions and normals (default).
        The user can provide explicit indicies to reference vertices vi/ vj and normals ni/nj"""
        self.l()
        self.insert(self.v_index(vi)).add("//").add(self.vn_index(ni))
        self.insert(self.v_index(vj)).add("//").add(self.vn_index(nj))
        return self

    def segment2(self, a:Vec2, b:Vec2) -> Self:
        """Add 2 vertex positions and a segment element referencing them"""
        return self.vertex2(a).vertex2(b).segment()

    def segment3(self, a:Vec3, b:Vec3) -> Self:
        """Add 2 vertex positions and a segment element referencing them"""
        return self.vertex3(a).vertex3(b).segment()

    def segment3_vn(self, va:Vec3, vb:Vec3, na:Vec3, nb:Vec3) -> Self:
        """Add 2 vertex positions, 2 vertex normals and an oriented segment element referencing them"""
        return self.vertex3(va).normal3(na).vertex3(vb).normal3(nb).segment_vn()



    #
    # Triangle Elements.  Indices are 1-based, see :ObjIndexing
    #

    def triangle(self,
        vi: int = -3, vj: int = -2, vk: int = -1
        ) -> Self:
        """Add a triangle element referencing the 3 previous vertex positions (default).
        The user can provide explicit indicies to reference vertices vi, vj and vk.
        Tip: Use this function with unpacked sequences i.e., call triangle(*(1,2,3))"""
        self.f()
        self.insert(self.v_index(vi))
        self.insert(self.v_index(vj))
        self.insert(self.v_index(vk))
        return self


    def triangle_vn(self,
        vi: int = -3, vj: int = -2, vk: int = -1, # vertex v-directive  references
        ni: int = -3, nj: int = -2, nk: int = -1, # vertex vn-directive references
        ) -> Self:
        """Add a triangle element referencing the 3 previous vertex positions and normals (default).
        The user can provide explicit indicies to reference vertices (vi, vj, vk); and normals (ni, nj, nk)
        Tip: Use this function with unpacked sequences i.e., call triangle_vn(*(1,2,3), *(1,2,3))"""
        self.f()
        self.insert(self.v_index(vi)).add("//").add(self.vn_index(ni))
        self.insert(self.v_index(vj)).add("//").add(self.vn_index(nj))
        self.insert(self.v_index(vk)).add("//").add(self.vn_index(nk))
        return self

    def triangle_vt(self,
        vi: int = -3, vj: int = -2, vk: int = -1, # vertex v-directive  references
        ti: int = -3, tj: int = -2, tk: int = -1, # vertex vt-directive references
        ) -> Self:
        """Add a triangle element referencing the 3 previous vertex positions and texture vertices (default).
        The user can provide explicit indices to reference vertices (vi, vj, vk); and texture vertices (ti, tj, tk)
        Tip: Use this function with unpacked sequences i.e., call triangle_vt(*(1,2,3), *(1,2,3))"""
        self.f()
        self.insert(self.v_index(vi)).add("/").add(self.vt_index(ti))
        self.insert(self.v_index(vj)).add("/").add(self.vt_index(tj))
        self.insert(self.v_index(vk)).add("/").add(self.vt_index(tk))
        return self

    def triangle_vnt(self,
        vi: int = -3, vj: int = -2, vk: int = -1, # vertex v-directive  references
        ni: int = -3, nj: int = -2, nk: int = -1, # vertex vn-directive references
        ti: int = -3, tj: int = -2, tk: int = -1, # vertex vt-directive references
        ) -> Self:
        """Add a triangle element referencing the 3 previous vertex positions, vertex normals and texture vertices (default).
        The user can provide explicit indices reference vertices (vi, vj, vk); normals (ni, nj, nk); and texture vertices (ti, tj, tk)
        Tip: Use this function with unpacked sequences i.e., call triangle_vt(*(1,2,3), *(1,2,3), *(1,2,3))"""
        self.f()
        self.insert(self.v_index(vi)).add("/").add(self.vt_index(ti)).add("/").add(self.vn_index(ni))
        self.insert(self.v_index(vj)).add("/").add(self.vt_index(tj)).add("/").add(self.vn_index(nj))
        self.insert(self.v_index(vk)).add("/").add(self.vt_index(tk)).add("/").add(self.vn_index(nk))
        return self

    def triangle2(self, va: Vec2, vb: Vec2, vc: Vec2) -> Self:
        """Add 3 vertex positions and a triangle element referencing them"""
        return self.vertex2(va).vertex2(vb).vertex2(vc).triangle()

    def triangle3(self, va: Vec3, vb: Vec3, vc: Vec3) -> Self:
        """Add 3 vertex positions and a triangle element referencing them"""
        return self.vertex3(va).vertex3(vb).vertex3(vc).triangle()

    def triangle3_vn(self,
        va: Vec3, vb: Vec3, vc: Vec3,
        na: Vec3, nb: Vec3, nc: Vec3
        ) -> Self:
        """Add 3 vertex positions, 3 vertex normals and a triangle element referencing them"""
        return self.vertex3(va).normal3(na).vertex3(vb).normal3(nb).vertex3(vc).normal3(nc).triangle_vn()

    def triangle3_vt(self,
        va: Vec3, vb: Vec3, vc: Vec3,
        ta: Vec2, tb: Vec2, tc: Vec2
        ) -> Self:
        """Add 3 vertex positions, 3 uvs and a triangle element referencing them"""
        return self.vertex3(va).uv2(ta).vertex3(vb).uv2(tb).vertex3(vc).uv2(tc).triangle_vt()

    def triangle3_vnt(self,
        va: Vec3, vb: Vec3, vc: Vec3,
        na: Vec3, nb: Vec3, nc: Vec3,
        ta: Vec3, tb: Vec3, tc: Vec3
    ) -> Self:
        """Add 3 vertex positions, 3 vertex normals, 3 texture vertices and a triangle element referencing them"""
        return self.vertex3(va).normal3(na).tangent3(ta).vertex3(vb).normal3(nb).tangent3(tb).vertex3(vc).normal3(nc).tangent3(tc).triangle_vnt()


    #
    # Polylines. These are sequences of segment elements
    #

    def polyline(self, N: int, closed: bool = False) -> Self:
        """Add a polyline element referencing the previous N vertex positions. N should be at least 2"""
        if N < 2:
            return self
        self.l() # Start the element
        for i in range(-N, 0):
            self.insert(self.v_index(i)) # Continue the element
        if closed:
            self.insert(self.v_index(-N)) # Close the polyline
        return self

    def polyline_ids(self, i: int, j: int, *ks : int) -> Self:
        """Add a polyline element referencing the vertices with the given indicies"""
        self.segment(i, j) # Start the element
        for k in ks:
            self.insert(self.v_index(k)) # Continue the element
        return self

    def polyline_vn(self, N: int, closed: bool = False) -> Self:
        """Add an oriented polyline element referencing the previous N vertex positions and normals. N should be at least 2"""
        if N < 2:
            return self
        self.l() # Start the element
        for i in range(-N, 0):
            self.insert(self.v_index(i)).add("//").add(self.vn_index(i)) # Continue the element
        if closed:
            self.insert(self.v_index(-N)).add("//").add(self.vn_index(-N)) # Close the polyline
        return self

    def polyline2(self, a: Vec2, b: Vec2, *cs : Vec2) -> Self:
        """Add the given 2D vertex positions and a polyline element referencing them"""
        self.vertex2(a).vertex2(b)
        for c in cs:
            self.vertex2(c)
        self.polyline(2 + len(cs))
        return self

    def polyline3(self, a: Vec3, b: Vec3, *cs : Vec3) -> Self:
        """Add the given 3D vertex positions and a polyline element referencing them"""
        self.vertex3(a).vertex3(b)
        for c in cs:
            self.vertex3(c)
        self.polyline(2 + len(cs))
        return self



    #
    # Convex Polygons. These are sequences of triangle elements aka triangle fans
    #

    def polygon(self, N: int) -> Self:
        """Add a polygon element referencing the previous N vertices. N should be at least 3"""
        if N < 3:
            return self
        self.f() # Start the element
        for i in range(-N, 0):
            self.insert(self.v_index(i)) # Continue the element
        return self

    def polygon_ids(self, i: int, j: int, k: int, *ls : int) -> Self:
        """Add a polygon element referencing the vertices with the given indices"""
        self.triangle(i, j, k) # Start the element
        for l in ls:
            self.insert(self.v_index(l)) # Continue the element
        return self

    def polygon2(self, a: Vec2, b: Vec2, c: Vec2, *ds : Vec2) -> Self:
        """Add the given 2D vertex positions and a polygon element referencing them"""
        self.vertex2(a).vertex2(b).vertex2(c)
        for d in ds:
            self.vertex2(d)
        self.polygon(3 + len(ds))
        return self

    def polygon3(self, a: Vec3, b: Vec3, c: Vec3, *ds : Vec3) -> Self:
        """Add the given 3D vertex positions and a polygon element referencing them"""
        self.vertex3(a).vertex3(b).vertex3(c)
        for d in ds:
            self.vertex3(d)
        self.polygon(3 + len(ds))
        return self





    #
    # Axis-aligned Boxes.
    #

    def box2_min_max(self, min: Vec2, max: Vec2) -> Self:
        """Add a 2D box region defined by min/max, visualized with segment elements"""
        self.polyline2(min, Vec2(max.x,min.y), max, Vec2(min.x,max.y), min)
        return self

    def box3_min_max(self, min: Vec3, max: Vec3) -> Self:
        """Add a 3D box region defined by min/max, visualized with segment elements"""
        # This has some redundant edges but having them means we could annotate all sgements in the shape conveniently
        p000, p100, p010, p110 = Vec3(min.x, min.y, min.z), Vec3(max.x, min.y, min.z), Vec3(min.x, max.y, min.z), Vec3(max.x, max.y, min.z)
        p001, p101, p011, p111 = Vec3(min.x, min.y, max.z), Vec3(max.x, min.y, max.z), Vec3(min.x, max.y, max.z), Vec3(max.x, max.y, max.z)
        return self.polyline3(p000, p100, p110, p010, p000, p001, p101, p100, p101, p111, p110, p111, p011, p010, p011, p001)

    def box2_center_extents(self, center: Vec2, extents: Vec2) -> Self:
        """Add a 2D box region defined by a center point and extents vector (box side lengths), visualized with segment elements"""
        a = Vec2(center.x - extents.x/2, center.y - extents.y/2)
        b = Vec2(center.x + extents.x/2, center.y + extents.y/2)
        return self.box2_min_max(a, b)

    def box3_center_extents(self, center: Vec3, extents: Vec3) -> Self:
        """Add a 3D box region defined by a center point and extents vector (box side lengths), visualized with segment elements"""
        a = Vec3(center.x - extents.x/2, center.y - extents.y/2, center.z - extents.z/2)
        b = Vec3(center.x + extents.x/2, center.y + extents.y/2, center.z + extents.z/2)
        return self.box3_min_max(a, b)



    #
    # Obj file configuration functions
    #

    def set_precision(self, n = 17) -> Self:
        """Set the number of base-10 digits used to write floating-point numbers to the obj. By default this function is
        equivalent to calling `set_precision_to_roundtrip_floats()`.

        This function is useful to improve annotation readability by reducing the number of base-10 digits used to write
        float data.  After writing such an annotation you will probably want to restore the value used for coordinate
        data, probably by calling this function with no arguments, to restore the precision that round-trips from double
        to decimal text to double.

        This function doesn't need to be in the Obj interface but its convenient to have it here for chained calls.
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
        #
        # Since python uses 64-bit floats we use 17 digits
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
    # Attributes.
    #
    # Attributes are special annotions which are intended to encode numerical data types/colors in annotation strings
    # by prefixing them with an @ character.  In a future version of Prizm there will be function to parse the encoded
    # data in order to display or process them specially. Multiple distinct data types placed on the same geometry
    # element will be supported and the @ character will be used parse them.  Even before this is implemented you might
    # still prefer to use attributes to annotations if you find having the @ prefix helps you read your annotations
    # strings more clearly. See Prizm::documentation() for more details.
    #

    def attribute(self) -> Self:
        """Start an attribute: Start an annotation string if needed, then add an @ to introduce a new attribute"""
        return self.annotation().space().at()

    def attribute(self, data: Any) -> Self:
        """Add an attribute containing the given data to the obj.  Data should be a numerical data type, see attribute()"""
        return self.attribute().insert(data) # Use insert to add a space is for legibility.






    #
    # Command Annotations.
    #
    # Command Annotations are special annotations which start with #! on a newline (this syntax is inspired by the
    # "hashbang" character sequence used to introduce an interpreter directive on Unix) and allow you specify Prizm
    # console commands, with arguments, which should be executed immediately after an the obj file has been loaded.
    # Command annotations provide a convenient way to configure the item display settings and save you a few clicks.
    # For example, if you know you want to look annotations you can call `set_annotation_label_visible(true)` to add
    # a command annotation which will enable annotation visibility after the file is loaded (annotation labelling is
    # off by default). Note: You can call these functions whenever you like, the command will be written to this->obj
    # at the point you call them but Prizm will defer execution until the entire file has been parsed.
    #
    # (Advanced Note) If you look at the output OBJ file you will notice that command annotations which configure
    # item state start with a 0, this is a Prizm item index.  The Prizm application has a global array of items
    # (aka meshes) and the index into this list is often used as the first argument in console commands. When console
    # commands are executed by the function which load OBJ files as command annotations a _local_ array of items is
    # created, the item with local index 0 is the item with geometry given in the OBJ if a console command which has
    # a side effect of generating a new item is executed as a command annotation then this item will have index >0 and
    # you can pass that value (e.g., to the `item_command` function) to run a console command on one of these
    # generated items which are not explicitly in the OBJ file.  Note: This complexity is intentionally avoided in
    # the Prizm::Obj command annotation API, so the functions below are hardcoded to work with item 0 only, but you
    # can do something like `obj.command("my_command").insert(1).insert("string_argument")` to run "my_command" on the
    # item with index 1.
    #

    def command(self, command_name: str) -> Self:
        """Start a command annotation, arguments should be `insert`ed after this"""
        return self.newline().hash().bang().insert(command_name)


    def item_command(self, command_name: str, item_index: int = 0) -> Self:
        """Start a command annotation whose first argument is a Prizm item index (See the Advanced Note above)"""
        return self.command(command_name).insert(item_index);


    # Annotation labels.  These functions affect annotations on every geometric entity, there are more granular functions as well

    def set_annotations_visible(self, visible: bool) -> Self:
        """Set visibility of all annotations"""
        return self.item_command("set_annotations_visible").insert(visible)


    def set_annotations_color(self, color: Color) -> Self:
        """Set color of all annotation text"""
        return self.item_command("set_annotations_color").insert(color)


    def set_annotations_scale(self, scale: float) -> Self:
        """Set scale of all annotation text.  The scale parameter is a float in the range [0.2, 1.0], by default Prizm uses 0.4."""
        # TODO :FixScaleParameter The scale parameter is weird, use size in pixels instead
        return self.item_command("set_annotations_scale").insert(scale)



    # Vertex labels

    def set_vertex_annotations_visible(self, visible: bool) -> Self:
        """Set visibility of vertex annotations i.e., annotations on obj file v-directive data"""
        return self.item_command("set_vertex_annotations_visible").insert(visible)


    #set_vertex_annotations_color not implemented (do we want this granularity? using set_annotations_color seems sufficient)
    #set_vertex_annotations_scale not implemented (do we want this granularity? using set_annotations_scale seems sufficient)

    def set_vertex_index_labels_visible(self, visible: bool) -> Self:
        """Set visibility of vertex index labels i.e., 0-based indices into the obj file v-directive data"""
        return self.item_command("set_vertex_index_labels_visible").insert(visible)


    def set_vertex_position_labels_visible(self, visible: bool) -> Self:
        """Set visibility of vertex position labels i.e., the coordinates of the obj file v-directive data"""
        return self.item_command("set_vertex_position_labels_visible").insert(visible)


    def set_vertex_label_color(self, color: Color) -> Self:
        """Set color of vertex index/position labels"""
        return self.item_command("set_vertex_label_color").insert(color)


    def set_vertex_label_scale(self, scale: float) -> Self:
        """Set scale of vertex index/position labels. The scale parameter is a float in the range [0.2, 1.0], by default Prizm uses 0.4"""
        # See :FixScaleParameter
        return self.item_command("set_vertex_label_scale").insert(scale)



    # Point labels

    def set_point_annotations_visible(self, visible: bool) -> Self:
        """Set visibility of point annotations i.e., annotations on obj file p-directive data"""
        return self.item_command("set_point_annotations_visible").insert(visible)


    #set_point_annotations_color not implemented (do we want this granularity? using set_annotations_color seems sufficient)
    #set_point_annotations_scale not implemented (do we want this granularity? using set_annotations_scale seems sufficient)

    def set_point_index_labels_visible(self, visible: bool) -> Self:
        """Set visibility of point element index labels i.e., 0-based indices into the obj file p-directive data
        Note: set_vertex_index_labels_visible is probably the function you want!"""
        return self.item_command("set_point_index_labels_visible").insert(visible)


    def set_point_label_color(self, color: Color) -> Self:
        """Set color of point index labels
        Note: set_vertex_label_color is probably the function you want!"""
        return self.item_command("set_point_label_color").insert(color)


    def set_point_label_scale(self, scale: float) -> Self:
        """Set scale of point index labels. The scale parameter is a float in the range [0.2, 1.0], by default Prizm uses 0.4
        Note: set_vertex_label_scale is probably the function you want!"""
        # See :FixScaleParameter
        return self.item_command("set_point_label_scale").insert(scale)



    # Segment labels

    def set_segment_annotations_visible(self, visible: bool) -> Self:
        """Set visibility of segment annotations i.e., annotations on obj file l-directive data"""
        return self.item_command("set_segment_annotations_visible").insert(visible)


    #set_segment_annotations_color not implemented (do we want this granularity? using set_annotations_color seems sufficient)
    #set_segment_annotations_scale not implemented (do we want this granularity? using set_annotations_scale seems sufficient)

    def set_segment_index_labels_visible(self, visible: bool = True) -> Self:
        """Set visibility of segment element index labels i.e., 0-based indices into the obj file l-directive data"""
        return self.item_command("set_segment_index_labels_visible").insert(visible)


    def set_segment_label_color(self, color: Color) -> Self:
        """Set color of segment index labels"""
        return self.item_command("set_segment_label_color").insert(color)


    def set_segment_label_scale(self, scale: float) -> Self:
        """Set scale of segment index labels.  The scale parameter is a float in the range [0.2, 1.0], by default Prizm uses 0.4"""
        # See :FixScaleParameter
        return self.item_command("set_segment_label_scale").insert(scale)



    # Triangle labels

    def set_triangle_annotations_visible(self, visible: bool) -> Self:
        """Set visibility of triangle annotations i.e., annotations on obj file f-directive data"""
        return self.item_command("set_triangle_annotations_visible").insert(visible)


    #set_triangle_annotations_color not implemented (do we want this granularity? using set_annotations_color seems sufficient)
    #set_triangle_annotations_scale not implemented (do we want this granularity? using set_annotations_scale seems sufficient)

    def set_triangle_index_labels_visible(self, visible: bool = True) -> Self:
        """Set visibility of triangle element index labels i.e., 0-based indices into the obj file f-directive data"""
        return self.item_command("set_triangle_index_labels_visible").insert(visible)


    def set_triangle_label_color(self, color: Color) -> Self:
        """Set color of triangle index labels"""
        return self.item_command("set_triangle_label_color").insert(color)


    def set_triangle_label_scale(self, scale: float) -> Self:
        """Set scale of triangle index labels. The scale parameter is a float in the range [0.2, 1.0], by default Prizm uses 0.4"""
        # See :FixScaleParameter
        return self.item_command("set_triangle_label_scale").insert(scale)



    # Vertex rendering

    def set_vertices_visible(self, visible: bool = True) -> Self:
        """Set visibility of vertices i.e., obj file v-directive data"""
        return self.item_command("set_vertices_visible").insert(visible)


    def set_vertices_color(self, color: Color) -> Self:
        """Set color of vertices i.e., obj file v-directive data"""
        return self.item_command("set_vertices_color").insert(color)


    def set_vertices_size(self, size: int) -> Self:
        """Set size/radius of vertices i.e., obj file v-directive data"""
        return self.item_command("set_vertices_size").insert(size)



    # Point rendering

    def set_points_visible(self, visible: bool) -> Self:
        """Set visibility of points i.e., obj file p-directive data. Note: set_vertices_visible is probably the function you want!"""
        return self.item_command("set_points_visible").insert(visible)


    def set_points_color(self, color: Color) -> Self:
        """Set color of points i.e., obj file p-directive data. Note: set_vertices_color is probably the function you want!"""
        return self.item_command("set_points_color").insert(color)


    def set_points_size(self, size: int) -> Self:
        """Set size/radius of points i.e., obj file p-directive data. Note: set_vertices_size is probably the function you want!"""
        return self.item_command("set_points_size").insert(size)



   # Segment rendering

    def set_segments_visible(self, visible: bool) -> Self:
        """Set visibility of segments i.e., obj file l-directive data"""
        return self.item_command("set_segments_visible").insert(visible)


    def set_segments_color(self, color: Color) -> Self:
        """Set color of segments i.e., obj file l-directive data"""
        return self.item_command("set_segments_color").insert(color)


    def set_segments_width(self, width: float) -> Self:
        """Set width of segments i.e., obj file l-directive data"""
        return self.item_command("set_segments_width").insert(width)



    # Edges rendering. Applies to triangle edges, but not segment elements.

    def set_edges_visible(self, visible: bool) -> Self:
        """Set visibility of triangle edges i.e., obj file f-directive data"""
        return self.item_command("set_edges_visible").insert(visible)


    def set_edges_color(self, color: Color) -> Self:
        """Set color of triangle edges i.e., obj file f-directive data"""
        return self.item_command("set_edges_color").insert(color)


    def set_edges_width(self, width: float) -> Self:
        """Set width of triangle edges i.e., obj file f-directive data"""
        return self.item_command("set_edges_width").insert(width)



    # Triangle rendering

    def set_triangles_visible(self, visible: bool) -> Self:
        """Set visibility of triangles i.e., obj file f-directive data"""
        return self.item_command("set_triangles_visible").insert(visible)


    def set_triangles_color(self, color: Color) -> Self:
        """Set color of triangles i.e., obj file f-directive data"""
        return self.item_command("set_triangles_color").insert(color)







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



# Internal data used to control the precision with which float data is written to the OBJ file.
# This should be manipulated via the Obj.set_precision function. By default write with enough
# precision to round-trip from float64 to decimal and back Note: Prizm currently stores mesh
# data using float32, we will move to float64 so we can show coordinate labels at full precision
# Note: It might be better to store the precision in the Obj class directly, but then we'd need
# to reimplement the __str__ methods in the VecN types.
_prizm_float_precision: int = 17





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
    obj.vertex3(Vec3(0., 0., 1.)).annotation("Vertex A");
    obj.vertex3(Vec3(3., 0., 1.)).annotation("Vertex B");
    obj.vertex3(Vec3(3., 3., 1.)).annotation("Vertex C");
    obj.triangle().annotation("Triangle ABC");











    obj.triangle(vis=(-3,-2,-1)).comment([1,2,3])

    v = Vec3(0,0,0)
    v.x = 42
    # obj.vector3(*v)
    obj.newline().vector3(v)
    obj.newline().vector3(Vec3(11,22,33))

    w = (1,2,333)
    ww = Vec3(*w)
    print(ww)
    print(ww.z)
    obj.comment("heeeere")
    obj.newline().vector3(ww)

    print(obj)

    # obj.write("test.obj")
    # obj.obj.close()




if __name__ == "__main__":
    # We delay this import so we only depend on/wait for argparse if you run this module as main
    import argparse

    parser = argparse.ArgumentParser(description='A Python API to write OBJ files with Prizm-specific extensions.')
    parser.add_argument('--demo', action='store_true', help='Runs the documentation() function to demo the API')

    args = parser.parse_args()
    if args.demo:
        documentation()


# TODO Consider addressing the unidiomatic-typecheck pylint complaint, what we use now seems faster though...
# TODO Add some shapes e.g., sphere
# TODO Consider reporting error/warnings when elements reference vertices that don't exist (Prizm checks this on load though...)

# Usage example:
#     import sys
#     sys.path.append("/path/to/Prizm/api/python/")
#     import Prizm
# nocommit type check when done
# nocommit add the UI
# nocommit update the wiki