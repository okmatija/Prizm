show_inspector := false;

inspect :: (name: *u8, t : *$T, new_window : bool = false) {
    if new_window ImGui.Begin(name, *show_inspector);
    inspect(name, t, type_info(T));
    if new_window ImGui.End();
}

#scope_file

inspect :: (name: *u8, data: *void, info:*Type_Info) {

    if #complete info.type == {
        case .INTEGER;

            // @Incomplete Add support for unsigned, and larger int types.
            info_int := cast(*Type_Info_Integer) info;
            ImGui.InputInt(name, data);

        case .FLOAT;

            if info.runtime_size == {
                case 4;
                    ImGui.DragFloat(name, data, format="%.6f");
                    // ImGui.InputFloat(name, data, 0.01, 1.0);
                case 8;
                    x : float = xx <<cast(*float64) data;
                    if ImGui.InputFloat(name, *x, 0.01, 1.0) { <<cast(*float64) data = x; };
            }

        case .BOOL;

            ImGui.Checkbox(name, cast(*bool)data);

        case .STRING;

            string_data := Reflection.get_string_data(data, xx info);
            string_count := Reflection.get_string_count(data, xx info);

            // @Incomplete We could allow editing of strings too.
            if string_data {
                ImGui.InputText(name, string_data, xx string_count, ImGui.InputTextFlags.ReadOnly);
            } else {
                ImGui.InputText(name, "(null)", 6, ImGui.InputTextFlags.ReadOnly);
            }

        case .STRUCT;

            info_struct := cast(*Type_Info_Struct) info;
            if ImGui.TreeNode("%", to_string(name)) {
                defer ImGui.TreePop();
                // ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
                // defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

                for member : info_struct.members {
                    inspect(temp_c_string(member.name), data + member.offset_in_bytes, member.type);
                }
            }

        case .ARRAY;

            info_array := cast(*Type_Info_Array) info;
            array_count, array_data := Reflection.get_array_count_and_data(data, info_array);
            array_name := to_string(name);
            element_size := info_array.element_type.runtime_size;
            if ImGui.TreeNode("% (count = %)", array_name, array_count) {
                defer ImGui.TreePop();
                ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
                defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

                for 0..array_count-1 {
                    item_name := temp_c_string(tprint("%[%]", array_name, it));
                    inspect(item_name, array_data + it * element_size, info_array.element_type);
                }
            }

        case .ENUM;

            info_enum := cast(*Type_Info_Enum) info;

            if info_enum.enum_type_flags & .FLAGS {
                // @Incomplete How to handle flags?
            } else {
                value := Reflection.get_enum_value(data, info_enum);
                value_name := "";
                for info_enum.names {
                    if value == info_enum.values[it_index]  value_name = it;
                }

                if ImGui.BeginCombo(name, temp_c_string(value_name)) {
                    for info_enum.names {
                        is_selected := value == info_enum.values[it_index];
                        if ImGui.Selectable(temp_c_string(it), is_selected) {
                            Reflection.set_enum_value(data, info_enum, info_enum.values[it_index]);
                        }
                        if is_selected ImGui.SetItemDefaultFocus();
                    }

                    ImGui.EndCombo();
                }
            }

        case .POLYMORPHIC_VARIABLE; #through;
        case .OVERLOAD_SET;         #through;
        case .PROCEDURE;            #through;
        case .POINTER;              #through;
        case .VOID;                 #through;
        case .CODE;                 #through;
        case .ANY;                  #through;
        case .TYPE;
            text := temp_c_string(tprint("% support is incomplete", info.type));
            ImGui.Text(text);
    }
}

Reflection :: #import "Reflection";
