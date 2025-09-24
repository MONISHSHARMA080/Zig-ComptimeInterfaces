const std = @import("std");
const print = std.debug.print;

/// fn crashes the program if the interface is not present
/// note: VTable should only contain methods and not var else this will error
pub fn checkIfTypeImplementExpectedInterfaces(comptime VTable: type, comptime typeToCheck: anytype) void {
    const TypeToCheck = @TypeOf(typeToCheck);
    const nameOfTheStruct = @typeName(TypeToCheck);
    switch (@typeInfo(VTable)) {
        .@"struct" => |structInVTableInfo| {
            inline for (structInVTableInfo.fields) |VTableField| {
                const fieldName = VTableField.name;
                const typeOfFunInVTable = @typeInfo(VTableField.type);
                if (!@hasDecl(TypeToCheck, fieldName)) @panic("the " ++ nameOfTheStruct ++ " does not contain the field " ++ fieldName ++ "\n");
                const typeOfFunInStruct = @typeInfo(@TypeOf(@field(TypeToCheck, fieldName)));
                if (typeOfFunInStruct != .@"fn") @compileError("expected the type's field in the struct " ++ nameOfTheStruct ++ " to be of type Fn \n");
                if (typeOfFunInVTable != .@"fn") @compileError("expected the VTable's field in the struct " ++ nameOfTheStruct ++ " to be of type Fn, but we got" + @typeName(typeOfFunInVTable) + " \n");
                // now checking if the the argument and return type is same as we expected them to be
                const ReturnTypeOfInterface = typeOfFunInVTable.@"fn".return_type orelse @panic("the fn " ++ fieldName ++ " on VTable " ++ nameOfTheStruct ++ " does not have any return value");
                const ReturnTypeOfStructToCheck = typeOfFunInStruct.@"fn".return_type orelse @panic("the fn " ++ fieldName ++ " on struct " ++ nameOfTheStruct ++ " does not have any return value");
                if (ReturnTypeOfInterface != ReturnTypeOfStructToCheck) @compileError("return type mismatch between the fn '" ++ fieldName ++ "'  in the VTable and in the struct we are checking \n");
                // now checking the function arguments
                if (typeOfFunInStruct.@"fn".params.len != typeOfFunInVTable.@"fn".params.len) @compileError(std.fmt.comptimePrint("expected the fn in vtable({d}) to be eqaul to no of params as fn in given type({s}) ({d})", .{ typeOfFunInVTable.@"fn".params.len, nameOfTheStruct, typeOfFunInStruct.@"fn".params.len }));
                inline for (typeOfFunInStruct.@"fn".params, typeOfFunInVTable.@"fn".params, 0..) |paramForStructFun, paramForVTableFun, i| {
                    // here null means for eg a fn has param ?i32 , that's why it is null

                    // =============================================
                    //  here check when param can be null and crash on that
                    //  and also what if the struct func takes a reference to itslef we also have to handle it
                    // =============================================
                    //
                    //
                    // ==================Stradegy:1============================
                    // I think the params can be null when a type on them is not present, so we need to check if the type on them is same as the one
                    // in the vtable, or you know what we know the type of the struct passed in, we know the type of it, and we could find out the self param in it based
                    // on which param is taking in self_type (assert 1) and that is the self one, if there are more than one  then I want the user to tell me via
                    // config that the
                    // or
                    // there are 3 scenarios, like 1) vtable.Param < struct.Param by 1 or 2) == or  3) vtable.Param > struct.Param by 1; rest is a error
                    //  1) here I need to see if the user has not included the self in the VTable one may be as we don't know if it will have them or not-- check
                    //  if the other params are same and 1 is the margin of error, or may be introduce a config type and we can implement more type saftey by checking
                    //  the param to be it(check for the self in the struct's fn to be of same type)
                    //  2) == > if same no of param then leaving the one that doesn't match we check the rest, if in the config struct we don't have type then we assume that it is it
                    //  else in the param dict we assign it to be it and perform a same check
                    //  3) vtable.Param > struct.Param: here in the vtable we have the self but not in the struct, so what we can do same in the 1); now note that the
                    //   1) and 3) are the same so we have same code for them
                    //
                    // --additon--
                    // we can return the name(or in the end place it in the struct field) of the type that we assumed to be of self so that the user outside can assert it during the comptime
                    // in the case where the vtable.Param < struct.Param we have a assertion of the type that is the self but in the 3) case the self on the vtable is
                    // of the anytype so we don't know the type to asser too, we can just assume it, then if we have the type of the self given by the user we can assume the
                    // anytype to be of that type, and put that in the struct field for the user to assert (or maybe this should error/crash)
                    // ==================Stradegy:1============================
                    // -----implementation-----
                    // ==================Stradegy:1============================
                    if (paramForStructFun.type == null and paramForVTableFun.type == null) {
                        continue; // Both are anytype - OK
                    } else if (paramForVTableFun.type == null or paramForStructFun.type == null) {
                        const nameOfType = if (paramForVTableFun.type == null) "VTable" else nameOfTheStruct;
                        @compileError(" Param type mismatch as the one in the " ++ nameOfType ++ " is null while other is not\n");
                    } else if (paramForStructFun.type.? != paramForVTableFun.type.?) {
                        @compileError(std.fmt.comptimePrint("Parameter type mismatch at index {d} \n ", .{i}));
                    }

                    // ==================Stradegy:1============================

                    // ==================Stradegy:0============================
                    // const structParamTypeOpt = paramForStructFun.type;
                    // const vtableParamTypeOpt = paramForVTableFun.type;
                    //
                    // // If both are null (both anytype), that's fine
                    // if (structParamTypeOpt == null and vtableParamTypeOpt == null) {
                    //     continue; // Both are anytype, compatible
                    // }
                    //
                    // // If one is null and the other isn't, that's an error
                    // if (structParamTypeOpt == null and vtableParamTypeOpt != null) {
                    //     @compileError(std.fmt.comptimePrint("Parameter {d} in struct function is anytype but vtable expects concrete type {s}", .{ 1, @typeName(vtableParamTypeOpt.?) }));
                    // }
                    // if (structParamTypeOpt != null and vtableParamTypeOpt == null) {
                    //     @compileError(std.fmt.comptimePrint("Parameter {d} in vtable function is anytype but struct has concrete type {s}", .{ 1, @typeName(structParamTypeOpt.?) }));
                    // }
                    //
                    // // Both have concrete types, compare them
                    // const structParamType = structParamTypeOpt.?;
                    // const vtableParamType = vtableParamTypeOpt.?;
                    //
                    // if (structParamType != vtableParamType) {
                    //     @compileError(std.fmt.comptimePrint("Parameter {d} type mismatch: vtable expects {s} but struct has {s}", .{ 2, @typeName(vtableParamType), @typeName(structParamType) }));
                    // }
                    //
                    //
                    // also look for the reading: https://github.com/nilslice/zig-interface/blob/main/src/interface.zig (implemetns the comptime interface)
                    // ==================Stradegy:0============================
                }
            }
        },
        else => {
            @compileError("\n expected the vtable to be of the type struct but we got something else\n");
        },
    }
    // get the methods from the vtable(name) and check if the same type(param and output) is present
    // inline for (0..1, 0..) |value, i| {}

}
