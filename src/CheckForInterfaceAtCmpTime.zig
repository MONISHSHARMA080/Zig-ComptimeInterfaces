const std = @import("std");
const print = std.debug.print;

pub const config = struct {
    /// do we want the other params to be of anytype/generics/anyopaque etc. if no then if we encounter param other then self to be of anytype then we will crash
    /// recommend TRUE as we want it to ensure proper types
    allowOtherParamsOfBeingGenerics: bool = false,
};
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
                // here null means for eg a fn has param ?i32 , that's why it is null

                // =============================================
                //  here check when param can be null and crash on that
                //  and also what if the struct func takes a reference to itslef we also have to handle it
                // =============================================
                //
                // ==================Stradegy:1============================
                // I think the params can be null when a type on them is not present, so we need to check if the type on them is same as the one
                // in the vtable, or you know what we know the type of the struct passed in, we know the type of it, and we could find out the self param in it based
                // on which param is taking in self_type (assert 1) and that is the self one, if there are more than one  then I want the user to tell me via
                // config that the
                // or
                // there are 3 scenarios, like 1) vtable.Param < struct.Param by 1 or 2) == or  3) vtable.Param > struct.Param by 1; rest will not happen(see above assert)
                //  1) here I need to see if the user has not included the self in the VTable one may be as we don't know if it will have them or not-- check
                //  if the other params are same and 1 is the margin of error, or may be introduce a config type and we can implement more type saftey by checking
                //  the param to be it(check for the self in the struct's fn to be of same type)
                //  2) == > if same no of param then leaving the one that doesn't match we check the rest, if in the config struct we don't have type then we assume that it is it
                //  else in the param dict we assign it to be it and perform a same check
                //  3) vtable.Param > struct.Param: here in the vtable we have the self but not in the struct, so what we can do same in the 1); now note that the
                //   1) and 3) are the same so we have same code for them
                //
                //
                // or as we can demand the user to include the reference to self regardless(in vtable and struct) if not then we have a error
                //
                //NOTE-  we need to handle the case where the interface does not know type of the error the function retunrs(anyerror)
                //
                // --additon--
                // we can return the name(or in the end place it in the struct field) of the type that we assumed to be of self so that the user outside can assert it during the comptime
                // in the case where the vtable.Param < struct.Param we have a assertion of the type that is the self but in the 3) case the self on the vtable is
                // of the anytype so we don't know the type to asser too, we can just assume it, then if we have the type of the self given by the user we can assume the
                // anytype to be of that type, and put that in the struct field for the user to assert (or maybe this should error/crash)
                // ==================Stradegy:1 implementation============================
                //
                // since we demanded the user to include the same number of argument (include self in vtable and struct), now we get the ref to self
                // and the index of the self in the vtable is the same as the one in the Struct.Fn
                const indexOfSelfInStruct = returnSelfTypeIndexInFnParam(typeOfFunInStruct.@"fn".params, TypeToCheck) catch |err| switch (err) {
                    error.MoreThanOneReferenceToSelfType => @compileError("Fn " ++ fieldName ++ "() (type to check) references more than one self value\n"),
                    error.didNotFoundIndex => @compileError("We were not able to find the self index in your struct's function " ++ fieldName ++ " \n"),
                    else => unreachable,
                };
                // const indexOfSelfInVTable = indexOfSelfInStruct; // cause we can't find it as it might have one or more anytype
                const areParamsEqual = areParamsTypeSameExceptSelf(typeOfFunInStruct.@"fn".params, typeOfFunInVTable.@"fn".params, indexOfSelfInStruct, bool);
                if (areParamsEqual) @compileError("");
                // now we check all the arguments and if the params at all the argument except

                // ==================Stradegy:1 implementation============================
                // also look for the reading: https://github.com/nilslice/zig-interface/blob/main/src/interface.zig (implemetns the comptime interface)
                // ==================Stradegy:0============================
            }
            // }
        },
        else => {
            @compileError("\n expected the vtable to be of the type struct but we got something else, for type other than struct the functionalaity is not implemented \n");
        },
    }
    // get the methods from the vtable(name) and check if the same type(param and output) is present
    // inline for (0..1, 0..) |value, i| {}
}

const paramTypeCheckingParam = error{
    OneParamIsNullWhileOtherIsNot,
    TypeDoesNotMatch,
};
/// check is the params have a same type except the self one(given)
fn areParamsTypeSameExceptSelf(typeToCheckFnParams: []const std.builtin.Type.Fn.Param, vTableFnParams: []const std.builtin.Type.Fn.Param, selfParamIndex: u32, returnType: type) returnType {
    if (typeToCheckFnParams.len != vTableFnParams.len) @compileError("expected the len of the parms of function in vtable and type to check to match \n");
    std.debug.assert(selfParamIndex <= typeToCheckFnParams.len); // the index should be in the parma len
    std.debug.assert(returnType == bool or returnType == paramTypeCheckingParam!bool); // the index should be in the parma len
    const shouldWeCrashOnError = if (returnType == bool) true else false;
    inline for (typeToCheckFnParams, vTableFnParams, 0..) |typeFnParam, vTableParam, i| {
        if (i == selfParamIndex) continue;
        // now need to check if both the param is of not null type (same)
        // --------------make sure to check the config to see if we need to crash on null ----------
        if (typeFnParam.type == null and vTableParam.type == null) {
            // fine move forward by making a fn that returns a struct and implement this as a default, so we can get this
            if (config.allowOtherParamsOfBeingGenerics == true) continue else {
                @compileError(" the generics/anytype are not allowed , we want you to make the type known \n");
            }
        } else if (typeFnParam.type == null or vTableParam.type == null) {
            if (shouldWeCrashOnError) @compileError("while comparing param of type to check and vtable, param of the one Fn is null while other is not") else return error.OneParamIsNullWhileOtherIsNot;
        } else if (typeFnParam.type != null and vTableParam.type != null) {
            if (isTypeCompatible(typeFnParam.type, vTableParam.type)) continue else @compileError("while comparing param of type to check and vtable, param of the one Fn is not same as the other one");
        } else unreachable;
    }
    return true;
}

/// retuns the index of the self type for the fucntion, if we encounters more than one type then retunrs the error, if we did not found the index then we also return
fn returnSelfTypeIndexInFnParam(functionParams: []const std.builtin.Type.Fn.Param, selfType: type) error{ MoreThanOneReferenceToSelfType, didNotFoundIndex }!u32 {
    var indexOfSelfType: ?u32 = null;
    inline for (functionParams, 0..) |param, i| {
        const paramType = param.type orelse continue;
        const typeInfo = @typeInfo(paramType);
        switch (typeInfo) {
            .pointer => {
                const pointerInfo = typeInfo.pointer;
                if (pointerInfo.child == selfType) {
                    if (indexOfSelfType != null) return error.MoreThanOneReferenceToSelfType else indexOfSelfType = i;
                }
            },
            else => {
                if (paramType == selfType) {
                    if (indexOfSelfType != null) return error.MoreThanOneReferenceToSelfType else indexOfSelfType = i;
                }
            },
        }
    }
    return indexOfSelfType orelse error.didNotFoundIndex;
}

/// Compares two types structurally to determine if they're compatible
fn isTypeCompatible(comptime T1: type, comptime T2: type) bool {
    const info1 = @typeInfo(T1);
    const info2 = @typeInfo(T2);

    // If types are identical, they're compatible
    if (T1 == T2) return true;

    // If type categories don't match, they're not compatible
    if (@intFromEnum(info1) != @intFromEnum(info2)) return false;

    return switch (info1) {
        .@"struct" => |s1| blk: {
            const s2 = @typeInfo(T2).@"struct";
            if (s1.fields.len != s2.fields.len) break :blk false;
            if (s1.is_tuple != s2.is_tuple) break :blk false;

            for (s1.fields, s2.fields) |f1, f2| {
                if (!std.mem.eql(u8, f1.name, f2.name)) break :blk false;
                if (!isTypeCompatible(f1.type, f2.type)) break :blk false;
            }
            break :blk true;
        },
        .@"enum" => |e1| blk: {
            const e2 = @typeInfo(T2).@"enum";
            if (e1.fields.len != e2.fields.len) break :blk false;

            for (e1.fields, e2.fields) |f1, f2| {
                if (!std.mem.eql(u8, f1.name, f2.name)) break :blk false;
                if (f1.value != f2.value) break :blk false;
            }
            break :blk true;
        },
        .array => |a1| blk: {
            const a2 = @typeInfo(T2).array;
            if (a1.len != a2.len) break :blk false;
            break :blk isTypeCompatible(a1.child, a2.child);
        },
        .pointer => |p1| blk: {
            const p2 = @typeInfo(T2).pointer;
            if (p1.size != p2.size) break :blk false;
            if (p1.is_const != p2.is_const) break :blk false;
            if (p1.is_volatile != p2.is_volatile) break :blk false;
            break :blk isTypeCompatible(p1.child, p2.child);
        },
        .optional => |o1| blk: {
            const o2 = @typeInfo(T2).optional;
            break :blk isTypeCompatible(o1.child, o2.child);
        },
        else => T1 == T2,
    };
}
test "Check if we get the self type index" {
    const testing = std.testing;

    const MyStruct = struct {
        value: i32,

        // Method that takes self by value
        pub fn byValue(self: @This()) void {
            _ = self;
        }

        // Method that takes self by pointer
        pub fn byPointer(self: *@This()) void {
            _ = self;
        }

        // Method that takes self by const pointer
        pub fn byConstPointer(self: *const @This()) void {
            _ = self;
        }

        // Method with multiple parameters including self
        pub fn withOtherParams(self: *@This(), other: i32, another: f32) void {
            _ = self;
            _ = other;
            _ = another;
        }

        // Method with two self references (should error)
        pub fn duplicateSelf(self: *@This(), other: @This()) void {
            _ = self;
            _ = other;
        }
    };

    // Test byValue method
    {
        comptime {
            const fnInfo = @typeInfo(@TypeOf(MyStruct.byValue)).@"fn";
            const index = try returnSelfTypeIndexInFnParam(fnInfo.params, MyStruct);
            try testing.expect(index == 0);
        }
        std.debug.print("got the ", .{});
    }

    // Test byPointer method
    {
        const fnInfo = @typeInfo(@TypeOf(MyStruct.byPointer)).@"fn";
        const index = try returnSelfTypeIndexInFnParam(fnInfo.params, MyStruct);
        try testing.expect(index == 0);
    }

    // Test byConstPointer method
    {
        const fnInfo = @typeInfo(@TypeOf(MyStruct.byConstPointer)).@"fn";
        const index = try returnSelfTypeIndexInFnParam(fnInfo.params, MyStruct);
        try testing.expect(index == 0);
    }

    // Test withOtherParams method (self is at index 0)
    {
        const fnInfo = @typeInfo(@TypeOf(MyStruct.withOtherParams)).@"fn";
        const index = try returnSelfTypeIndexInFnParam(fnInfo.params, MyStruct);
        try testing.expect(index == 0);
    }

    // Test duplicateSelf method (should return error)
    {
        const fnInfo = @typeInfo(@TypeOf(MyStruct.duplicateSelf)).@"fn";
        const result = returnSelfTypeIndexInFnParam(fnInfo.params, MyStruct);
        try testing.expectError(error.MoreThanOneReferenceToSelfType, result);
    }
}
