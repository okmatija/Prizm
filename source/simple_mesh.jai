Simple_Mesh :: struct {
    // Position
    vertices : [..]Vector3;

    // Elements
    // .obj loading will fill these in from p, l and f directives respectively
    points : [..]u32; // Point clouds must set these, and thse are the only thing checked for 
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
    attributes : [..]*Simple_Mesh_Attribute;

    // We still don't support f i//a j//b k//c with i/j/k != a/b/c 
    // Normals should be dense attributes on faces, not verticies

    // @Volatile Code in various places may need to change if this changes distances so they are not the same in world/model space
    world_from_model : Matrix4 = .{_11 = 1, _22 = 1, _33 = 1, _44 = 1};

    // @Incomplete cache Box_Sphere_Bounds here
    // @Incomplete store the spatial index
    // @Incomplete Maybe have the annotations attached to points, segments, triangles here
}

Simple_Mesh_Element :: enum {
    VERTEX; // Set via the v-directive
    POINT; // Set via the p-directive
    SEGMENT;
    TRIANGLE;
    MESH; // For attributes for the whole file, probably only sparse make sense, and value index would be line number in the file
}

Simple_Mesh_Attribute :: struct {
    Attribute_Display_Info :: struct {
        // @Incomplete nocommit Only show the relevant parts of the format options depending on the type of the values
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

Simple_Mesh_Normals :: Simple_Mesh_Dense_Attribute(Matrix3, .TRIANGLE);
Simple_Mesh_UVs :: Simple_Mesh_Dense_Attribute(Matrix3, .TRIANGLE); // Filled by vt directives in obj files, which can have 3 components

// Dense attributes have values array with the same count as the corresponding element container in the mesh
Simple_Mesh_Dense_Attribute :: struct (Value_Type : Type, Element_Kind : Simple_Mesh_Element) {
    using #as base : Simple_Mesh_Attribute;
    base.type = Simple_Mesh_Dense_Attribute(Value_Type, Element_Kind);

    values : [..]Value_Type;
}

// nocommit Remove these entirely! Annotations will be the sparse version of attributes, and they will only be string types!
// Sparse attributes are only attached to a few elements of the mesh
Simple_Mesh_Sparse_Attribute :: struct (Value_Type : Type, Element_Kind : Simple_Mesh_Element) {
    using #as base : Simple_Mesh_Attribute;
    base.type = Simple_Mesh_Sparse_Attribute(Value_Type, Element_Kind);

    Indexed_Value :: struct {
        index : int; // Index in the Simple_Mesh base.element array
        value : Value_Type;
    }

    indexed_values : [..]Indexed_Value;
}

// string  - renders as text near cursor, so build up text quads which is already supported
// float   - renders as colors on point/segment/face
// Vector2 - renders as texture/texture coordinate
// Vector3 - renders as vectors or colors in barycentric space of the face
// Matrix3 - renders as vectors on face vertices/edges
ATTRIBUTE_VALUE_TYPES :: Type.[string, float, Vector3, Matrix3];

// @Think Perhaps we want dynamic_ versions of these functions which have non-constant value_type??

// nocommit These functions should work on the mesh directly, not the entity

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

    result : *Simple_Mesh_Attribute = entity.mesh.attributes[entity.mesh.attributes.count - 1];
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


// nocommit remove this
/*
get_simple_mesh_attribute_type :: (base : *Simple_Mesh_Attribute) -> Type {
    // @Cleanup Auto-generate this code
    if base.is_dense {
        if base.value_type == {
            case string;
                attribute := cast(*Simple_Mesh_Dense_Attribute(string))base;
                #insert body; 
            case float;
                return Simple_Mesh_Dense_Attribute(float);
            case Vector2;
                return Simple_Mesh_Dense_Attribute(Vector2);
            case Vector3;
                return Simple_Mesh_Dense_Attribute(Vector3);
            case Vector4;
                return Simple_Mesh_Dense_Attribute(Vector4);
        }
    } else {
        if base.value_type == {
            case string;
                return Simple_Mesh_Sparse_Attribute(string);
            case float;
                return Simple_Mesh_Sparse_Attribute(float);
            case Vector2;
                return Simple_Mesh_Sparse_Attribute(Vector2);
            case Vector3;
                return Simple_Mesh_Sparse_Attribute(Vector3);
            case Vector4;
                return Simple_Mesh_Sparse_Attribute(Vector4);
        }
    }
}
*/