// Based on jai/modules/Tagged_Union.jai but stores an enum rather than a Type:
//
// Advantages:
// - Can be usable with if #complete
// - Is bit smaller
//
// Disadvantages:
// - set function needs to search the value_types to find the right enum
// - Tagged_Union(float) creates an enum entry named .float32

// #module_parameters (DEBUG := false);  // Enable DEBUG for extra checking.
DEBUG :: true;

Tagged_Union :: struct (value_types: .. Type) {
    #insert -> string {
        builder : String_Builder;

        // Generate Kind which is an enum corresponding to the value_types
        print_to_builder(*builder, "Kind :: enum #specified {\n");
        for value_types {
            print_to_builder(*builder, "    _% :: %;\n", type_to_string(cast(*Type_Info)it), it_index);
        }
        print_to_builder(*builder, "}\n");
        print_to_builder(*builder, "kind : Kind;\n\n");

        // Generate Kind_To_Type which maps the enum to the type
        print_to_builder(*builder, "Kind_To_Type : [%]Type : .[\n", value_types.count);
        for value_types {
            print_to_builder(*builder, "    %,\n", type_to_string(cast(*Type_Info)it));
        }
        print_to_builder(*builder, "];\n\n");

        return builder_to_string(*builder);
    } 
    
    bytes: [NUM_VALUE_BYTES] u8;
    
    NUM_VALUE_BYTES : s64 : #run get_biggest_size(value_types);
}

get_type :: (using u : Tagged_Union) -> Type {
    return value_types[cast(int)kind];
}

set :: (using u: *Tagged_Union, value: $T) {

    #if DEBUG == true {
        #run {
            found := false;
            for value_types  if it == T { found = true; break; }

            assert(found);
        }
    }

    for 0..value_types.count-1 if value_types[it] == T {
        kind = cast(Kind)it;
        break;
    }

    pointer := cast(*T) bytes.data;
    pointer.* = value;
}

isa :: (using u: Tagged_Union, $T: Type) -> *T {
    if get_type(u) == T  return cast(*T) bytes.data;
    return null;
}

#scope_file

#import "Basic"; 

// get_biggest_size is used at compile-time by the #run in Tagged_Union.
get_biggest_size :: (types: [] Type) -> s64 {
    biggest: s64;

    // This cast to *Type_Info requires runtime_storageless_type_info to be disabled,
    // or for us to be running at compile-time. We know for sure in this case that we are
    // calling this routine at compile-time, but in runtime use, this kind of cast
    // presumes that Type_Info has been exported for all runtime types.
    for types  biggest = max(biggest, (cast(*Type_Info)(it)).runtime_size); 

    return biggest;
}