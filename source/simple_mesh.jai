/*

Vertex :: struct {
    position : Vector3;
    normal : Vector3;
    color : Vector4;
    uv0 : Vector2;
    //uv1 : Vector2;
}

triangles : [..]Vertex;
segments : [..]Vertex;
points : [..]Vertex;
unreferenced_vertices : [..]Vertex;

*/


Simple_Mesh :: struct {
    // @Cleanup We should really have a vertex struct... not sure the mesh attribute thing was a good idea either...
    positions : [..]Vector3;
    colors : [..]Vector3;

    // Elements. Performance note: having overlapping elements (e.g., when a position is common to a point and a segment/triangle, or when segment lies on a triangle edge) computations like ray-casting may compute distances between the same positions more than once.
    // .obj loading will fill these in from p, l and f directives respectively
    points : [..]u32; // Filled in by parsing p-directives, or with the item_find_unreferenced_positions
    segments : [..]Tuple2(u32); // l's OR construct if we contruct special edge data
    triangles : [..]Tuple3(u32); // f's with 3 indices

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
    if !mesh return;

    // Note: array_reset frees memory and zeros members
    array_reset(*positions);
    array_reset(*colors);
    array_reset(*points);
    array_reset(*segments);
    array_reset(*triangles);

    // @Cleanup it sucks to have a switch here, use an iterator or use a pool which can just be dropped, so we don't need to cast to the right type
    for base_attr : attributes {
        if base_attr.type == {
            case Simple_Mesh_Triangle_Normals;
                attr := cast(*Simple_Mesh_Triangle_Normals)base_attr;
                deinit(attr);
            case Simple_Mesh_Segment_Normals;
                attr := cast(*Simple_Mesh_Segment_Normals)base_attr;
                deinit(attr);
            case Simple_Mesh_Point_Normals;
                attr := cast(*Simple_Mesh_Point_Normals)base_attr;
                deinit(attr);
            case;
                log_warning("Unhandled attribute type '%' deinit function", base_attr.type);
        }
    }
    array_reset(*attributes);
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

add_triangle :: (mesh : *Simple_Mesh, triangle : Triangle3, color : Triangle_Color = .{}) {
    tuple : *Tuple3(u32) = array_add(*mesh.triangles);

    tuple.x = cast(u32)mesh.positions.count;
    array_add(*mesh.positions, triangle.a);
    array_add(*mesh.colors, color.a);

    tuple.y = cast(u32)mesh.positions.count;
    array_add(*mesh.positions, triangle.b);
    array_add(*mesh.colors, color.b);

    tuple.z = cast(u32)mesh.positions.count;
    array_add(*mesh.positions, triangle.c);
    array_add(*mesh.colors, color.c);

    // triangle_normals : *Simple_Mesh_Triangle_Normals = find_or_add_triangle_normals_attribute(mesh);
    // array_add(*triangle_normals.values, normals);
}

add_segment :: (mesh : *Simple_Mesh, segment : Segment3, color : Segment_Color = .{}) {

    tuple : *Tuple2(u32) = array_add(*mesh.segments);

    tuple.x = cast(u32)mesh.positions.count;
    array_add(*mesh.positions, segment.start);
    array_add(*mesh.colors, color.start);

    tuple.y = cast(u32)mesh.positions.count;
    array_add(*mesh.positions, segment.end);
    array_add(*mesh.colors, color.end);

    // segment_normals : *Simple_Mesh_Segment_Normals = find_or_add_segment_normals_attribute(mesh);
    // array_add(*segment_normals.values, normals);
}

add_point :: (using mesh : *Simple_Mesh, position : Vector3, color : Point_Color = DEFAULT_VERTEX_COLOR) {
    index : *u32 = array_add(*mesh.points);

    index.* = cast(u32)mesh.positions.count;
    array_add(*mesh.positions, position);
    array_add(*mesh.colors, color);

    // point_normals : *Simple_Mesh_Point_Normals = find_or_add_point_normals_attribute(mesh);
    // array_add(*point_normals.values, normal);
}

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

    new_elements, elements.* = elements.*, new_elements;

    array_free(new_elements);
}

// // @Incomplete see parshapes for a sample implementation
// weld :: (mesh : Simple_Mesh) -> Simple_Mesh { }
// unweld :: (mesh : Simple_Mesh) -> Simple_Mesh { }

merge :: (dst : *Simple_Mesh, src : Simple_Mesh) {

    assert(src.colors.count == src.positions.count);
    assert(dst.colors.count == dst.positions.count);

    positions_offset := dst.positions.count;
    colors_offset :=    dst.colors.count;
    points_offset :=    dst.points.count;
    segments_offset :=  dst.segments.count;
    triangles_offset := dst.triangles.count;

    dst_model_from_world := inverse(dst.world_from_model);
    dst_model_from_world_vector := transpose(inverse(dst_model_from_world));
    src_world_from_model_vector := transpose(inverse(src.world_from_model));

    array_resize(*dst.positions, dst.positions.count + src.positions.count);
    for i : 0..src.positions.count-1 {
        dst.positions[positions_offset + i] = transform_point(dst_model_from_world, mesh_position_world(src, i));
    }

    array_resize(*dst.colors, dst.colors.count + src.colors.count);
    for i : 0..src.colors.count-1 {
        dst.colors[colors_offset + i] = src.colors[i];
    }

    assert(dst.colors.count == dst.positions.count);

    array_resize(*dst.points, dst.points.count + src.points.count);
    for i : 0..src.points.count-1 {
        dst.points[points_offset + i] = xx positions_offset + src.points[i];
    }

    array_resize(*dst.segments,  dst.segments.count +  src.segments.count);
    for i : 0..src.segments.count-1 {
        dst.segments[segments_offset + i].x = xx positions_offset + src.segments[i].x;
        dst.segments[segments_offset + i].y = xx positions_offset + src.segments[i].y;
    }

    array_resize(*dst.triangles, dst.triangles.count + src.triangles.count);
    for i : 0..src.triangles.count-1 {
        dst.triangles[triangles_offset + i].x = xx positions_offset + src.triangles[i].x;
        dst.triangles[triangles_offset + i].y = xx positions_offset + src.triangles[i].y;
        dst.triangles[triangles_offset + i].z = xx positions_offset + src.triangles[i].z;
    }

    // @Incomplete We don't currently support merging (and correctly transforming) attributes, normals in particular, see also :NormalsInGeometrySelectionMode for required support in selection mode (one place this merge function can be called)
    // @TODOO Fix this code
#if false {

    //if src.normals.count || dst.normals.count {
    //    array_resize(*dst.normals, dst.positions.count + src.positions.count);
    //    for i : 0..src.normals.count-1 {
    //        src_normal_world := transform_vector(src_world_from_model_vector, src.normals[i]);
    //        dst_normal_model := transform_vector(dst_model_from_world_vector, src_normal_world);
    //        dst.normals[positions_offset + i] = dst_normal_model;
    //    }
    //}

    src_triangle_normals : *Simple_Mesh_Triangle_Normals = find_mesh_attribute(*src, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
    if (src_triangle_normals && src_triangle_normals.values.count) {
        dst_triangle_normals : *Simple_Mesh_Triangle_Normals = find_or_add_mesh_attribute(dst, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);

        normals_offset := dst_triangle_normals.values.count;
        array_resize(*dst_triangle_normals.values, dst_triangle_normals.values.count + src_triangle_normals.values.count);
        for i : 0..src_triangle_normals.values.count-1 {
            for d : 0..2 {
                src_normal_world := transform_vector(src_world_from_model_vector, src_triangle_normals.values[i].v[d]);
                dst_normal_model := transform_vector(dst_model_from_world_vector, src_normal_world);
                dst_triangle_normals.values[normals_offset + i].v[d] = dst_normal_model;
            }
        }
    }

    src_segment_normals : *Simple_Mesh_Segment_Normals = find_mesh_attribute(*src, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
    dst_segment_normals : *Simple_Mesh_Segment_Normals = find_mesh_attribute(dst, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
    if (src_segment_normals && src_segment_normals.values.count) && (dst_segment_normals && dst_segment_normals.values.count) {
        normals_offset := dst_segment_normals.values.count;
        array_resize(*dst_segment_normals.values, dst_segment_normals.values.count + src_segment_normals.values.count);
        for i : 0..src_segment_normals.values.count-1 {
            for d : 0..1 {
                src_normal_world := transform_vector(src_world_from_model_vector, src_segment_normals.values[i].v[d]);
                dst_normal_model := transform_vector(dst_model_from_world_vector, src_normal_world);
                dst_segment_normals.values[normals_offset + i].v[d] = dst_normal_model;
            }
        }
    }

    src_point_normals : *Simple_Mesh_Point_Normals = find_mesh_attribute(*src, POINT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Point_Normals);
    dst_point_normals : *Simple_Mesh_Point_Normals = find_mesh_attribute(dst, POINT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Point_Normals);
    if (src_point_normals && src_point_normals.values.count) && (dst_point_normals && dst_point_normals.values.count) {
        normals_offset := dst_point_normals.values.count;
        array_resize(*dst_point_normals.values, dst_point_normals.values.count + src_point_normals.values.count);
        for i : 0..src_point_normals.values.count-1 {
            src_normal_world := transform_vector(src_world_from_model_vector, src_point_normals.values[i]);
            dst_normal_model := transform_vector(dst_model_from_world_vector, src_normal_world);
            dst_point_normals.values[normals_offset + i] = dst_normal_model;
        }
    }
}

}

// @FIXME Add a $world_space argument
bounding_box :: (using mesh : Simple_Mesh) -> AxisBox3 #must {
    box : AxisBox3;
    for * mesh.positions {
        expand(*box, it);
    }
    return box;
}

// @FIXME Add a $world_space argument. WTF is the transform argument??
bounding_box :: (using mesh : Simple_Mesh, transform : Matrix4) -> AxisBox3 #must {
    box : AxisBox3;
    for point_model : mesh.positions {
        point_transformed := (transform * Vector4.{xyz=point_model, w=1.}).xyz;
        expand(*box, point_transformed);
    }
    return box;
}

// @FIXME This transform should just update world_from_model???
transform :: (using mesh : *Simple_Mesh, transform : Matrix4) {
    if !mesh return;

    for * mesh.positions {
        it.* = (transform * Vector4.{xyz=it, w=1.}).xyz;
    }

    // @Incomplete Transform attributes

    vn : *Simple_Mesh_Triangle_Normals = find_or_add_mesh_attribute(mesh, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
    if vn {
        inverse_transpose := transpose(inverse(transform));
        for *matrix : vn.values {
            for i : 0..2 {
                matrix.v[i] = (inverse_transpose * Vector4.{xyz=matrix.v[i]}).xyz;
            }
        }
    }
}

// Iterates over all triangles, computes the triangle normal and assigns it to the vertices
// - The normals will be in model space
// - Vertices which are referenced by more than one triangle, will be given the normal of the triangle with the largest triangle index
// - Vertices which are not referenced by any triangles will be assigned [0,0,0] as the normal
compute_vertex_normals_from_triangles :: (mesh : *Simple_Mesh, triangle_normals : *Simple_Mesh_Triangle_Normals) -> bool, string {
    assert(mesh != null);
    assert(triangle_normals != null);
    assert(triangle_normals.values.count == 0);

    // Initialize to zero normals
    array_resize(*triangle_normals.values, mesh.triangles.count, initialize=true);

    for :TriangleTupleIterator tt, tid : mesh {
        if valid_triangle_tuple(mesh, tt) {
            tri : Triangle3 = ---;
            tri.a = mesh.positions[tt.i];
            tri.b = mesh.positions[tt.j];
            tri.c = mesh.positions[tt.k];
            n := compute_normal(tri, normalize=true);
            triangle_normals.values[tid].v[0] = n;
            triangle_normals.values[tid].v[1] = n;
            triangle_normals.values[tid].v[2] = n;
        } else {
            array_reset(*triangle_normals.values); // Clear and free memory
            return false, tprint("Triangle % has out-of-range vertex indices. Got %, %, % but max index is %", tid, tt.i, tt.j, tt.k, mesh.positions.count-1);
        }
    }

    return true, "";
}


Simple_Mesh_Element :: enum s8 {
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

remove_mesh_attribute :: (mesh : *Simple_Mesh, attribute_name : string, $attribute_type : Type)  {
    for mesh.attributes {
        if it.type == attribute_type && it.name == attribute_name {
            attr := cast(*attribute_type)it;
            deinit(attr);
            remove it;
            break;
        }
    }
}

find_or_add_mesh_attribute :: (mesh : *Simple_Mesh, attribute_name : string, $attribute_type : Type) -> *attribute_type {
    found := find_mesh_attribute(mesh, attribute_name, attribute_type);
    if !found {
        added := add_mesh_attribute(mesh, attribute_name, attribute_type);
        return added;
    }
    return found;
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


// Element/Vertex accessors
//

// @Cleanup remove the _hack postfix

/* @CompilerBug
    E:/Dropbox/Prizm/source/mesh.jai:82,66: Error: Internal compiler error: In #bake, we should be guaranteed to find an entry by this name, but we didn't.
    
        get_point_bake_arguments_proc :: #procedure_of_call get_point(Mesh.{}, 0, false);
        get_point_model :: #bake_arguments get_point_bake_arguments_proc(world_space=false);
        get_point_world :: #bake_arguments get_point_bake_arguments_proc(world_space=true);

get_point :: (using mesh : Mesh, vid : int, $world_space : bool) -> Vector3 {
    #if world_space {
        return transform_point(world_from_model, positions[vid]);
    }
    return positions[vid];
}

get_point_bake_arguments_proc :: #procedure_of_call get_point(Mesh.{}, 0, false);
get_point_model :: #bake_arguments get_point_bake_arguments_proc(world_space=false);
get_point_world :: #bake_arguments get_point_bake_arguments_proc(world_space=true);
*/

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

mesh_point_model :: #bake_arguments mesh_point_hack(world_space=false);
mesh_point_world :: #bake_arguments mesh_point_hack(world_space=true);

mesh_point_color :: (mesh : Simple_Mesh, point_index : int) -> Point_Color {
    position_index := mesh.points[point_index];
    return mesh.colors[position_index]; 
}



mesh_segment_tuple :: (mesh : Simple_Mesh, segment_index : int) -> Tuple2(u32) {
    return mesh.segments[segment_index];
}

mesh_segment_hack :: (mesh : Simple_Mesh, segment_index : int, $world_space : bool) -> Segment3 {
    tuple := inline mesh_segment_tuple(mesh, segment_index);

    result : Segment3 = ---;
    result.start = mesh_position_hack(mesh, tuple.component[0], world_space); 
    result.end   = mesh_position_hack(mesh, tuple.component[1], world_space); 
    return result;
}

mesh_segment_model :: #bake_arguments mesh_segment_hack(world_space=false);
mesh_segment_world :: #bake_arguments mesh_segment_hack(world_space=true);

mesh_segment_color :: (mesh : Simple_Mesh, segment_index : int) -> Segment_Color {
    tuple := inline mesh_segment_tuple(mesh, segment_index);

    result : Segment_Color = ---;
    result.start = mesh.colors[tuple.x];
    result.end = mesh.colors[tuple.y];
    return result;
}



// @Cleanup Remove this
mesh_triangle_tuple :: (using mesh : Simple_Mesh, triangle_index : int) -> Tuple3(u32) {
    return mesh.triangles[triangle_index];
}

mesh_triangle_hack :: (mesh : Simple_Mesh, triangle_index : int, $world_space : bool) -> Triangle3 {
    tuple := inline mesh_triangle_tuple(mesh, triangle_index);

    result : Triangle3 = ---;
    result.a = mesh_position_hack(mesh, tuple.component[0], world_space);
    result.b = mesh_position_hack(mesh, tuple.component[1], world_space);
    result.c = mesh_position_hack(mesh, tuple.component[2], world_space);
    return result;
}

mesh_triangle_model :: #bake_arguments mesh_triangle_hack(world_space=false);
mesh_triangle_world :: #bake_arguments mesh_triangle_hack(world_space=true);

mesh_triangle_color :: (mesh : Simple_Mesh, triangle_index : int) -> Triangle_Color {
    tuple := inline mesh_triangle_tuple(mesh, triangle_index);

    result : Triangle_Color = ---;
    result.a = mesh.colors[tuple.x];
    result.b = mesh.colors[tuple.y];
    result.c = mesh.colors[tuple.z];
    return result;
}




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
    edge_indices : Tuple3(Tuple2(u32)) = inline mesh_triangle_edges_tuple(mesh, triangle_index);

    result : Tuple3(Segment3) = ---;
    for e : 0..2 {
        result.component[e].start = mesh_position_hack(mesh, edge_indices.component[e].x, world_space);
        result.component[e].end =   mesh_position_hack(mesh, edge_indices.component[e].y, world_space);
    }
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
        edges : Tuple3(Segment3) = inline mesh_triangle_edges_hack(mesh, triangle_index, world_space);
        for e : 0..2 {
            `it_index := 3 * triangle_index + e;
            `it : Segment3 = edges.component[e]; 
            #insert (remove=#assert(false), break=break i) body;
        }
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
        `it : Segment3 = inline mesh_segment_hack(mesh, segment_index, world_space);
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

    // Keep track of which vertices are still being used by at least one triangle
    used_positions : [..]bool;
    defer array_free(used_positions);
    array_resize(*used_positions, mesh.positions.count);

    for :TriangleTupleIterator triangle_tuple : mesh {
        used_positions[triangle_tuple.x] = true;
        used_positions[triangle_tuple.y] = true;
        used_positions[triangle_tuple.z] = true;
    }

    for :SegmentTupleIterator segment_tuple : mesh {
        used_positions[segment_tuple.x] = true;
        used_positions[segment_tuple.y] = true;
    }

    for :PointIndexIterator position_index : mesh {
        used_positions[position_index] = true;
    }

    // Shift all the vertices that are not being used to the end of the array
    cursor : u32 = 0;
    for i : 0..mesh.positions.count-1 {
        if used_positions[i] {
            mesh.positions[cursor] = mesh.positions[i];
            mesh.colors[cursor] = mesh.colors[i];

            // Update the vertex indices of the remaining triangles
            for * :TriangleTupleIterator triangle_tuple : mesh {
                if triangle_tuple.x == i then triangle_tuple.x = cursor;
                if triangle_tuple.y == i then triangle_tuple.y = cursor;
                if triangle_tuple.z == i then triangle_tuple.z = cursor;
            }

            // Update the vertex indices of the remaining segments
            for * :SegmentTupleIterator segment_tuple : mesh {
                if segment_tuple.x == i then segment_tuple.x = cursor;
                if segment_tuple.y == i then segment_tuple.y = cursor;
            }

            // Update the vertex indices of the remaining points
            for * :PointIndexIterator position_index : mesh {
                if position_index.* == i then position_index.* = cursor;
            }

            cursor += 1;
        }
    }

    // Update the number of vertices
    mesh.positions.count = cursor;
    mesh.colors.count = cursor;

}

#scope_file

deinit :: (attr : *$T/Simple_Mesh_Attribute) {
    array_reset(*attr.values);
    free(attr);
}
