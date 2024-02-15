Triangle3 :: struct {}
Segment3 :: struct {}
Sphere :: struct {}
Point3 :: struct {}
AxisBox3 :: struct {}

Simple_Mesh :: struct {
    positions : [..]Vector3;

    // Elements. Performance note: having overlapping elements (e.g., when a position is common to a point and a segment/triangle, or when segment lies on a triangle edge) computations like ray-casting may compute distances between the same positions more than once.
    // .obj loading will fill these in from p, l and f directives respectively
    points : [..]u32; // Filled in by parsing p-directives, or with the item_find_unreferenced_positions
    segments : [..]Tuple2(u32); // l's OR construct if we contruct special edge data
    triangles : [..]Tuple3(u32); // f's with 3 indices
    //tetrahedra : [..]Tuple4(u32); // f's with 4 indices?

    // Mesh normals and tangents are stored as overlays attributes
    // Attributes are added via the item_add_attribute_XXX commands, which can/should be used in command obj comments
    // Then name is specified in a leading #! ? maybe also say if the annotations are sparse or dense to pick the datastructure
    // I need shaders for different types of data attached to vertices/segments/faces
    // List of data types I want to support
    // - scalars e.g., errors/costs
    // - vectors e.g., Vector2 for UVs, Vector3 for normals/tangents/displacements
    // - tensors e.g., Matrix4 for stresses
    // - string  e.g., debug comments
    // @Think maybe its better to have separate containers: vertex_attributes, point_attributes etc
    // @Think maybe have a map of attributes using unique names to identify them
    attributes : [..]*Simple_Mesh_Attribute_Base;

    // @Volatile Code in various places may need to change if this changes distances so they are not the same in world/model space
    world_from_model : Matrix4 = .{_11 = 1, _22 = 1, _33 = 1, _44 = 1};

    // @Incomplete cache Box_Sphere_Bounds here
    // @Incomplete store the spatial index
    // @Incomplete Maybe have the annotations attached to points, segments, triangles here
}

// @Cleanup, Don't need to pass pointers here, and remove setting to null

deinit :: (using mesh : *Simple_Mesh) {
}

// Intentionally not implemented: Keep it simple and just deinit the mesh!
// clear :: (using mesh : *Simple_Mesh) {}

no_elements :: (mesh : Simple_Mesh) -> bool {
    return mesh.points.count == 0 && mesh.segments.count == 0 && mesh.triangles.count == 0;
}

is_empty :: (mesh : Simple_Mesh) -> bool {
    return mesh.positions.count == 0;
    // return inline point_count(entity.mesh) == 0; // @CompilerBug? Error: Attempted use of keyword 'inline' on a non-procedure-call.
}

// copy_mesh :: (using mesh : Simple_Mesh) -> *Simple_Mesh {
//     result := Deep_Copy(*mesh, .{});
//     return result;
// }

valid_triangle_tuple :: (using mesh : *Simple_Mesh, tt : Tuple3(u32)) -> bool {
    return tt.i < positions.count && tt.j < positions.count && tt.k < positions.count;
}

valid_segment_tuple :: (using mesh : *Simple_Mesh, st : Tuple2(u32)) -> bool {
    return st.i < positions.count && st.j < positions.count;
}

valid_point_index :: (using mesh : *Simple_Mesh, pi : u32) -> bool {
    return pi < positions.count;
}

// @Warning This invalidates existing index references
remove_triangle_by_index :: (using mesh : *Simple_Mesh, remove_index : int) {
    if remove_index < 0 || remove_index > mesh.triangles.count {
        return;
    }

    array_unordered_remove_by_index(*mesh.triangles, remove_index);

    compact_mesh(mesh);
}

// @Warning This invalidates existing index references
remove_segment_by_index :: (using mesh : *Simple_Mesh, remove_index : int) {
    if remove_index < 0 || remove_index > mesh.segments.count {
        return;
    }

    array_unordered_remove_by_index(*mesh.segments, remove_index);

    compact_mesh(mesh);
}

// @Warning This invalidates existing index references
remove_point_by_index :: (using mesh : *Simple_Mesh, remove_index : int) {
    if remove_index < 0 || remove_index > mesh.points.count {
        return;
    }

    array_unordered_remove_by_index(*mesh.points, remove_index);

    compact_mesh(mesh);
}

remove_elements_by_index :: (elements : *[..]$T, remove_indices : ..int) {
    new_elements : [..]T;
    array_reserve(*new_elements, elements.count - remove_indices.count);

    // @Speed
    for elements.* {
        found := array_find(remove_indices, it_index);
        if !found {
            array_add(*new_elements, it);
        }
    }

    new_elements, elements.* = swap(new_elements, elements.*);

    array_free(new_elements);
}

// // @Incomplete see parshapes for a sample implementation
// weld :: (mesh : Simple_Mesh) -> Simple_Mesh { }
// unweld :: (mesh : Simple_Mesh) -> Simple_Mesh { }

merge :: (dst : *Simple_Mesh, src : Simple_Mesh) {
}


// @FIXME This transform should just update world_from_model???
transform :: (using mesh : *Simple_Mesh, transform : Matrix4) {
}

// Iterates over all triangles, computes the triangle normal and assigns it to the vertices
// - The normals will be in model space
// - Vertices which are referenced by more than one triangle, will be given the normal of the triangle with the largest triangle index
// - Vertices which are not referenced by any triangles will be assigned [0,0,0] as the normal
compute_vertex_normals_from_triangles :: (mesh : *Simple_Mesh, triangle_normals : *Simple_Mesh_Triangle_Normals) -> bool, string {
    return true, "";
}


Simple_Mesh_Element :: enum {
    VERTEX;   // a.k.a "position". Set via the v-directive (not really an element, just position data)

    POINT;    // Set via the p-directive
    SEGMENT;  // Set via the l-directive
    TRIANGLE; // Set via the f-directive

    MESH; // For attributes for the whole file, probably only sparse make sense, and value index would be line number in the file
}

Simple_Mesh_Attribute_Base :: struct {
    Attribute_Display_Info :: struct {
        theme : Attribute_Theme;
    }

    // Rendering of attributes is @Incomplete study the implementation in Polyscope/GraphiteThree?
    Attribute_Render_Info :: struct {
        buffer : GLuint;
    }

    name : string;
    type : Type;
    display_info : Attribute_Display_Info;
    render_info : Attribute_Render_Info;
}

/// Maybe we need a Simple_Mesh_Attribute_Element which only has point,segment, triangle members, to constrain what can have an annotation
Simple_Mesh_Attribute :: struct (Value_Type : Type, Element_Kind : Simple_Mesh_Element) {
    using #as base : Simple_Mesh_Attribute_Base;
    base.type = Simple_Mesh_Attribute(Value_Type, Element_Kind);

    // count matches the element container in the mesh
    values : [..]Value_Type;
}

Matrix3x2 :: struct {
    _11, _12, _13 : float;
    _21, _22, _23 : float;

    #place _11; v:      [2]    Vector3 = ---; // These are row vectors.
    #place _11; coef:   [2][3] float   = ---;
    #place _11; floats: [6]    float   = ---;

    Row_Type    :: Vector3;
    Column_Type :: Vector2;

    IsMatrixFromMathModule :: false;
} 

// These are all in model space
POINT_NORMALS_ATTRIBUTE_NAME :: "Obj Point Normals";
SEGMENT_NORMALS_ATTRIBUTE_NAME :: "Obj Segment Normals";
TRIANGLE_NORMALS_ATTRIBUTE_NAME :: "Obj Triangle Normals";

Simple_Mesh_Point_Normals :: Simple_Mesh_Attribute(Vector3, .POINT);
Simple_Mesh_Segment_Normals :: Simple_Mesh_Attribute(Matrix3x2, .SEGMENT);
Simple_Mesh_Triangle_Normals :: Simple_Mesh_Attribute(Matrix3, .TRIANGLE);
//Simple_Mesh_UVs :: Simple_Mesh_Attribute(Matrix3, .TRIANGLE); // Filled by vt directives in obj files, which can have 3 components


// string  - renders as text near cursor, so build up text quads which is already supported
// float   - renders as colors on point/segment/face
// Vector2 - renders as texture/texture coordinate
// Vector3 - renders as vectors or colors in barycentric space of the face
// Matrix3 - renders as vectors on face vertices/edges
ATTRIBUTE_VALUE_TYPES :: Type.[string, float, Vector3, Matrix3];

// @Think Perhaps we want dynamic_ versions of these functions which have non-constant value_type??
// @Think Use /interface here

find_mesh_attribute :: (mesh : *Simple_Mesh, attribute_name : string, $attribute_type : Type) -> *attribute_type {
    for mesh.attributes {
        if it.type == attribute_type && it.name == attribute_name {
            return xx it;
        }
    }
    return null;
}

find_triangle_normals_attribute :: (mesh : *Simple_Mesh) -> *Simple_Mesh_Triangle_Normals {
    return find_mesh_attribute(mesh, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
}

find_segment_normals_attribute :: (mesh : *Simple_Mesh) -> *Simple_Mesh_Segment_Normals {
    return find_mesh_attribute(mesh, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
}

find_point_normals_attribute :: (mesh : *Simple_Mesh) -> *Simple_Mesh_Point_Normals {
    return find_mesh_attribute(mesh, POINT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Point_Normals);
}

add_mesh_attribute :: (mesh : *Simple_Mesh, attribute_name : string, $attribute_type : Type) -> *attribute_type {

    attribute := New(attribute_type);
    array_add(*mesh.attributes, attribute);

    result : *Simple_Mesh_Attribute_Base = mesh.attributes[mesh.attributes.count - 1];
    result.name = attribute_name;
    result.display_info = .{};

    return xx result;
}

remove_mesh_attribute :: (mesh : *Simple_Mesh, attribute_name : string, $attribute_type : Type)  {}

find_or_add_mesh_attribute :: (mesh : *Simple_Mesh, attribute_name : string, $attribute_type : Type) -> *attribute_type {
    return null;
}

find_or_add_triangle_normals_attribute :: (mesh : *Simple_Mesh) -> *Simple_Mesh_Triangle_Normals {
    return find_or_add_mesh_attribute(mesh, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
}

find_or_add_segment_normals_attribute :: (mesh : *Simple_Mesh) -> *Simple_Mesh_Segment_Normals {
    return find_or_add_mesh_attribute(mesh, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
}

find_or_add_point_normals_attribute :: (mesh : *Simple_Mesh) -> *Simple_Mesh_Point_Normals {
    return find_or_add_mesh_attribute(mesh, POINT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Point_Normals);
}


mesh_position_hack :: inline (using mesh : Simple_Mesh, position_index : int, $world_space : bool) -> Vector3 {
    #if world_space {
        return transform_point(world_from_model, positions[position_index]);
    }
    return positions[position_index];
}

mesh_position_model :: #bake_arguments mesh_position_hack(world_space=false);
mesh_position_world :: #bake_arguments mesh_position_hack(world_space=true);


mesh_point_hack :: inline (using mesh : Simple_Mesh, point_index : int, $world_space : bool) -> Vector3 {
    position_index := mesh.points[point_index];
    return inline mesh_position_hack(mesh, position_index, world_space);
}

mesh_point_model :: #bake_arguments mesh_position_hack(world_space=false);
mesh_point_world :: #bake_arguments mesh_position_hack(world_space=true);



mesh_segment3_tuple :: (mesh : Simple_Mesh, segment_index : int) -> Tuple2(u32) {
    return .{};
}

mesh_segment3_hack :: (mesh : Simple_Mesh, segment_index : int, $world_space : bool) -> Segment3 {
    return .{};
}

mesh_segment3_model :: #bake_arguments mesh_segment3_hack(world_space=false);
mesh_segment3_world :: #bake_arguments mesh_segment3_hack(world_space=true);





// @Cleanup Remove this
mesh_triangle_tuple :: (using mesh : Simple_Mesh, triangle_index : int) -> Tuple3(u32) {
    return .{};
}

mesh_triangle_hack :: (mesh : Simple_Mesh, triangle_index : int, $world_space : bool) -> Triangle3 {
    return .{};
}

mesh_triangle_model :: #bake_arguments mesh_triangle_hack(world_space=false);
mesh_triangle_world :: #bake_arguments mesh_triangle_hack(world_space=true);




mesh_triangle_edges_tuple :: (using mesh : Simple_Mesh, triangle_index : int) -> Tuple3(Tuple2(u32)) {
    triangle_indices : Tuple3(u32) = inline mesh_triangle_tuple(mesh, triangle_index);

    result : Tuple3(Tuple2(u32)) = ---;
    for e : 0..2 {
        TRIANGLE_EDGES :: Tuple2i.[.{0, 1}, .{1, 2}, .{2, 0}];
        result.component[e].x = triangle_indices.component[TRIANGLE_EDGES[e].x];
        result.component[e].y = triangle_indices.component[TRIANGLE_EDGES[e].y];
    }
    return result;
}


mesh_triangle_edges_hack :: (mesh : Simple_Mesh, triangle_index : int, $world_space : bool) -> Tuple3(Segment3) {
    result : Tuple3(Segment3) = ---;
    return result;
}

mesh_triangle_edges_model :: #bake_arguments mesh_triangle_edges_hack(world_space=false);
mesh_triangle_edges_world :: #bake_arguments mesh_triangle_edges_hack(world_space=true);






//
// Iterators
//

TriangleTupleIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags) #expand {
    for *=cast(bool)(flags & .POINTER), <=cast(bool)(flags & .REVERSE) triangle_tuple, triangle_index : mesh.triangles {
        `it_index := triangle_index;
        `it := triangle_tuple;
        #insert (remove=#assert(false)) body;
    }
}

// Reserve the ambiguous name for this iterator which won't compile if used directly
TriangleIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported

    for i : 0..mesh.triangles.count-1 {
        `it_index := i;
        `it : Triangle3 = inline mesh_triangle_hack(mesh, i, world_space);
        #insert (remove=#assert(false)) body;
    }
}

ModelTriangleIterator :: #bake_arguments TriangleIterator(world_space=false);
WorldTriangleIterator :: #bake_arguments TriangleIterator(world_space=true);




// @Think Warning! Not sure we're doing the right thing with break/continue here
TriangleEdgeIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported

    for triangle_index : 0..mesh.triangles.count-1 {
        `it_index := triangle_index;
        `it : Segment3; 
        #insert (remove=#assert(false), break=break i) body;
    }
}


ModelTriangleEdgeIterator :: #bake_arguments TriangleEdgeIterator(world_space=false);
WorldTriangleEdgeIterator :: #bake_arguments TriangleEdgeIterator(world_space=true);


SegmentTupleIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags) #expand {
    for *=cast(bool)(flags & .POINTER), <=cast(bool)(flags & .REVERSE) segment_tuple, segment_index : mesh.segments {
        `it_index := segment_index;
        `it := segment_tuple;
        #insert (remove=#assert(false)) body;
    }
}

// Reserve the ambiguous name for this iterator which won't compile if used directly
SegmentIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported

    for segment_index : 0..mesh.segments.count-1 {
        `it_index := segment_index;
        `it : Segment3 = inline mesh_segment3_hack(mesh, segment_index, world_space);
        #insert (remove=#assert(false)) body;
    }
}

ModelSegmentIterator :: #bake_arguments SegmentIterator(world_space=false);
WorldSegmentIterator :: #bake_arguments SegmentIterator(world_space=true);


PointIndexIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags) #expand {
    for *=cast(bool)(flags & .POINTER), <=cast(bool)(flags & .REVERSE) position_index, point_index : mesh.points {
        `it_index := point_index;
        `it := position_index;
        #insert (remove=#assert(false)) body;
    }
}

// Reserve the ambiguous name for this iterator which won't compile if used directly
PointIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported

    for point_index : 0..mesh.points.count-1 {
        position_index := mesh.points[point_index]; 
        `it_index := point_index;
        `it : Vector3 = mesh_position_hack(mesh, position_index, world_space);
        #insert (remove=#assert(false)) body;
    }
}

ModelPointIterator :: #bake_arguments PointIterator(world_space=false);
WorldPointIterator :: #bake_arguments PointIterator(world_space=true);


// Reserve the ambiguous name for this iterator which won't compile if used directly
VertexIterator :: (using mesh : *Simple_Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported

    for position_model, position_index : mesh.positions {
        `it_index := position_index;
        `it : Vector3 = mesh_position_hack(mesh, position_index, world_space);
        #insert (remove=#assert(false)) body;
    }
}

ModelVertexIterator :: #bake_arguments VertexIterator(world_space=false);
WorldVertexIterator :: #bake_arguments VertexIterator(world_space=true);


compact_mesh :: (mesh : *Simple_Mesh) {
}