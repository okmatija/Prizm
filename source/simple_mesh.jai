Simple_Mesh :: struct {
    // Position
    positions : [..]Vector3;
    normals : [..]Vector3; // FIXME This should be an attribute!!

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
    attributes : [..]*Simple_Mesh_Attribute_Base;

    // We still don't support f i//a j//b k//c with i/j/k != a/b/c 
    // Normals should be dense attributes on faces, not verticies

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
    array_reset(*normals);
    array_reset(*points);
    array_reset(*segments);
    array_reset(*triangles);

    mesh = null;
}

clear :: (using mesh : *Simple_Mesh) {
    // Zeros all the counts, but keeps the memory
    array_reset_keeping_memory(*positions);
    array_reset_keeping_memory(*normals);
    array_reset_keeping_memory(*points);
    array_reset_keeping_memory(*segments);
    array_reset_keeping_memory(*triangles);

    // @FIXME Handle attributes here
}

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

add_triangle :: (using mesh : *Simple_Mesh, triangle : Triangle3) {
    tuple : *Tuple3(u32) = array_add(*mesh.triangles);

    tuple.x = xx mesh.positions.count;
    array_add(*mesh.positions, triangle.a);

    tuple.y = xx mesh.positions.count;
    array_add(*mesh.positions, triangle.b);

    tuple.z = xx mesh.positions.count;
    array_add(*mesh.positions, triangle.c);
}

add_segment :: (using mesh : *Simple_Mesh, segment : Segment3) {
    tuple : *Tuple2(u32) = array_add(*mesh.segments);

    tuple.x = xx mesh.positions.count;
    array_add(*mesh.positions, segment.start);

    tuple.y = xx mesh.positions.count;
    array_add(*mesh.positions, segment.end);
}

add_point :: (using mesh : *Simple_Mesh, position : Vector3) {
    index : *u32 = array_add(*mesh.points);

    <<index = xx mesh.positions.count;
    array_add(*mesh.positions, position);
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
    for <<elements {
        found := array_find(remove_indices, it_index);
        if !found {
            array_add(*new_elements, it);
        }
    }

    new_elements, <<elements = swap(new_elements, <<elements);

    array_free(new_elements);
}

// // @Incomplete see parshapes for a sample implementation
// weld :: (mesh : Simple_Mesh) -> Simple_Mesh { }
// unweld :: (mesh : Simple_Mesh) -> Simple_Mesh { }

merge :: (dst : *Simple_Mesh, src : Simple_Mesh) {
    positions_offset := dst.positions.count;
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

    // @Incomplete Transform attributes

    if src.normals.count || dst.normals.count {
        array_resize(*dst.normals, dst.positions.count + src.positions.count);
        for i : 0..src.normals.count-1 {
            src_normal_world := transform_vector(src_world_from_model_vector, src.normals[i]);
            dst_normal_model := transform_vector(dst_model_from_world_vector, src_normal_world);
            dst.normals[positions_offset + i] = dst_normal_model;
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
        point_transformed := (transform * make_vector4(point_model, 1)).xyz;
        expand(*box, point_transformed);
    }
    return box;
}

// @FIXME This transform should just update world_from_model???
transform :: (using mesh : *Simple_Mesh, transform : Matrix4) {
    if !mesh return;

    for * mesh.positions {
        <<it = (transform * make_vector4(it, 1.)).xyz;
    }

    // @Incomplete Transform attributes

    if mesh.normals.count {
        inverse_transpose := transpose(inverse(transform));
        for * mesh.normals {
            <<it = (inverse_transpose * make_vector4(it, 0.)).xyz;
        }
    }
}

// Iterates over all triangles, computes the triangle normal and assigns it to the vertices
// - The normals will be in model space
// - Vertices which are referenced by more than one triangle, will be given the normal of the triangle with the largest triangle index
// - Vertices which are not referenced by any triangles will be assigned [0,0,0] as the normal
compute_vertex_normals_from_triangles :: (mesh : *Simple_Mesh) -> bool, string {
    if !mesh return false, "Null mesh";

    if mesh.triangles.count == 0 {
        return false, "No triangles";
    }

    {
        // Points not referenced by any triangle are assigned zero normals
        array_resize(*mesh.normals, mesh.positions.count, initialize=true);

        for :TriangleTupleIterator tt : mesh {
            if tt.i < mesh.positions.count && tt.i < mesh.positions.count && tt.i < mesh.positions.count {
                tri : Triangle3 = ---;
                tri.a = mesh.positions[tt.i];
                tri.b = mesh.positions[tt.j];
                tri.c = mesh.positions[tt.k];
                n := compute_normal(tri, normalize=true);
                mesh.normals[tt.i] = n;
                mesh.normals[tt.j] = n;
                mesh.normals[tt.k] = n;
            } else {
                array_reset(*mesh.normals); // Clear and free memory
                return false, tprint("Out-of-range indices in mesh connectivity array, got %, %, %, but max index is %", tt.i, tt.j, tt.k, mesh.positions.count-1);
            }
        }
    }

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

    // Rendering of attributes is @Incomplete
    Attribute_Render_Info :: struct {
        buffer : GLuint;
    }

    name : string;
    type : Type;
    display_info : Attribute_Display_Info;
    render_info : Attribute_Render_Info;
}

Simple_Mesh_Attribute :: struct (Value_Type : Type, Element_Kind : Simple_Mesh_Element) {
    using #as base : Simple_Mesh_Attribute_Base;
    base.type = Simple_Mesh_Attribute(Value_Type, Element_Kind);

    // count matches the element container in the mesh
    values : [..]Value_Type;
}

Simple_Mesh_Normals :: Simple_Mesh_Attribute(Matrix3, .TRIANGLE);
Simple_Mesh_UVs :: Simple_Mesh_Attribute(Matrix3, .TRIANGLE); // Filled by vt directives in obj files, which can have 3 components


// string  - renders as text near cursor, so build up text quads which is already supported
// float   - renders as colors on point/segment/face
// Vector2 - renders as texture/texture coordinate
// Vector3 - renders as vectors or colors in barycentric space of the face
// Matrix3 - renders as vectors on face vertices/edges
ATTRIBUTE_VALUE_TYPES :: Type.[string, float, Vector3, Matrix3];

// @Think Perhaps we want dynamic_ versions of these functions which have non-constant value_type??

// @Cleanup These functions should work on the mesh directly, not the entity

find_mesh_attribute :: (entity : *Entity, attribute_name : string, $attribute_type : Type) -> *attribute_type {
    for entity.mesh.attributes {
        if it.type == attribute_type && it.name == attribute_name {
            return xx it;
        }
    }
    return null;
}

add_mesh_attribute :: (entity : *Entity, attribute_name : string, $attribute_type : Type) -> *attribute_type {

    attribute := New(attribute_type);
    array_add(*entity.mesh.attributes, attribute);

    result : *Simple_Mesh_Attribute_Base = entity.mesh.attributes[entity.mesh.attributes.count - 1];
    result.name = attribute_name;
    result.display_info = .{};

    return xx result;
}

find_or_add_mesh_attribute :: (entity : *Entity, attribute_name : string, $attribute_type : Type) -> *attribute_type {
    found := find_mesh_attribute(entity, attribute_name, attribute_type);
    if !found {
        added := add_mesh_attribute(entity, attribute_name, attribute_type);
        return added;
    }
    return found;
}

//
// Element/Vertex accessors
//

// @Cleanup remove the _hack postfix

/* @CompilerBug
    E:/Dropbox/Prism/source/mesh.jai:82,66: Error: Internal compiler error: In #bake, we should be guaranteed to find an entry by this name, but we didn't.
    
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

mesh_point_model :: #bake_arguments mesh_position_hack(world_space=false);
mesh_point_world :: #bake_arguments mesh_position_hack(world_space=true);



mesh_segment3_tuple :: (mesh : Simple_Mesh, segment_index : int) -> Tuple2(u32) {
    return mesh.segments[segment_index];
}

mesh_segment3_hack :: (mesh : Simple_Mesh, segment_index : int, $world_space : bool) -> Segment3 {
    tuple := inline mesh_segment3_tuple(mesh, segment_index);

    result : Segment3 = ---;
    result.start = mesh_position_hack(mesh, tuple.component[0], world_space); 
    result.end   = mesh_position_hack(mesh, tuple.component[1], world_space); 
    return result;
}

mesh_segment3_model :: #bake_arguments mesh_segment3_hack(world_space=false);
mesh_segment3_world :: #bake_arguments mesh_segment3_hack(world_space=true);





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
        `it := inline mesh_triangle_hack(mesh, i, world_space);
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
                if <<position_index == i then <<position_index = cursor;
            }

            cursor += 1;
        }
    }

    // Update the number of vertices
    mesh.positions.count = cursor;

}