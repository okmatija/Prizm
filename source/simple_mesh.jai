Simple_Mesh :: struct {
    // Position
    vertices : [..]Vector3;

    // Elements
    // .obj loading will fill these in from p, l and f directives respectively
    points : [..]u32;
    segments : [..]Tuple2(u32); // l's OR construct if we contruct special edge data
    triangles : [..]Tuple3(u32); // f's with 3 indices

    world_from_model : Matrix4 = .{_11 = 1, _22 = 1, _33 = 1, _44 = 1};
}

Simple_Mesh_Attribute :: struct {
    Element :: enum {
        VERTEX;
        POINT; // Kindof redundant
        SEGMENT;
        TRIANGLE;
        MESH; // For attributes for the whole file, probably only sparse make sense, and value index would be line number in the file
    }

    Attribute_Display_Info :: struct {
        // ...
    }

    name : string;
    value_type : Type;
    element : Element;
    display_info : Attribute_Display_Info;
}

// Dense attributes have values array with the same count as the corresponding element container in the mesh
Simple_Mesh_Dense_Attribute :: struct (Value_Type : Type) {
    using #as base : Simple_Mesh_Attribute;
    base.value_type = Value_Type;

    values : [..]Value_Type;
}

// Sparse attributes are only attached to a few elements of the mesh
Simple_Mesh_Sparse_Attribute :: struct (Value_Type : Type) {
    using #as base : Simple_Mesh_Attribute;
    base.value_type = Value_Type;

    Indexed_Value :: struct {
        index : int; // Index in the Simple_Mesh base.element array
        value : Value_Type;
    }

    indexed_values : [..]Indexed_Value;
}
