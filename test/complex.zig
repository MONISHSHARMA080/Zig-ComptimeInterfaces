const std = @import("std");
const Interface = @import("interface");
const testing = std.testing;
const print = std.debug.print;

const err = error{ Error1, Error2 };
const taggedUnion = union(enum) {
    A: u32,
    B: bool,
    C: err,
};
const newType = struct { x: u32, y: ?[]const u8 };
const complexType = struct {
    pub fn Function(self: complexType, first: struct { a: []const u8, b: ?i32 }, second: taggedUnion, third: newType) anyerror!void {
        _ = self;
        _ = first;
        _ = second;
        _ = third;
    }
};
const VTableWithError = struct {
    Function: fn (self: anytype, first: struct { a: []const u8, b: ?i32 }, second: taggedUnion, third: newType) err!void,
};

const VTable = struct {
    Function: fn (self: anytype, first: struct { a: []const u8, b: ?i32 }, second: taggedUnion, third: newType) anyerror!void,
};

/// wrong error union
const CorrectType = struct {
    pub fn Function(self: CorrectType, first: struct { a: []const u8, b: ?i32 }, second: taggedUnion, third: newType) err!void {
        _ = self;
        _ = first;
        _ = second;
        _ = third;
    }
};

/// wrong error union
const WrongComplexType = struct {
    pub fn Function(self: WrongComplexType, first: struct { a: []const u8, b: ?i32 }, second: taggedUnion, third: newType) !void {
        _ = self;
        _ = first;
        _ = second;
        _ = third;
    }
};

test "testing complex types" {
    print("in complex tests \n", .{});
    comptime {
        try Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(VTable, complexType);
        // const wrongComplexType = WrongComplexType{};
        const res: Interface.ParamTypeCheckingError!void = Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(VTable, WrongComplexType);
        try testing.expectError(Interface.ParamTypeCheckingError.TypeDoesNotMatch, res);
        try Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(VTableWithError, CorrectType);
    }
    print(" complexType test worked fine when the error set is diff form the vtable  \n", .{});
}
