# Zig-ComptimeInterfacesPublic

Compile-time interface checking for Zig.

## Installation

```zig
const Interface = @import("interface");
```

## Usage

Define a vtable (interface) and check if your type implements it:

```zig
const std = @import("std");
const Interface = @import("interface");

const vtable = struct {
    mailTheUser: fn (self: anytype) error{FieldNotThere}!void,
    printName: fn (self: anytype) void,
};

const User = struct {
    age: u32 = 0,
    name: []const u8 = "",
    emailAddress: []const u8 = "",
    
    pub fn mailTheUser(self: User) error{FieldNotThere}!void {
        if (self.emailAddress.len <= 0) return error.FieldNotThere;
        std.debug.print("emailed the user at {s}\n", .{self.emailAddress});
    }
    
    pub fn printName(self: User) void {
        std.debug.print("the user's name is {s}\n", .{self.name});
    }
};

comptime {
    Interface.InterfaceCheck(.{ .crashOnError = true })
        .checkIfTypeImplementsExpectedInterfaces(vtable, User);
}
```

### Complex Types

Works with nested structs, tagged unions, and optionals:

```zig
const taggedUnion = union(enum) {
    A: u32,
    B: bool,
    C: error{ Error1, Error2 },
};

const newType = struct { x: u32, y: ?[]const u8 };

const VTable = struct {
    Function: fn (
        self: anytype,
        first: struct { a: []const u8, b: ?i32 },
        second: taggedUnion,
        third: newType
    ) anyerror!void,
};

const ComplexType = struct {
    pub fn Function(
        self: ComplexType,
        first: struct { a: []const u8, b: ?i32 },
        second: taggedUnion,
        third: newType
    ) anyerror!void {
        _ = self; _ = first; _ = second; _ = third;
    }
};

comptime {
    Interface.InterfaceCheck(.{ .crashOnError = true })
        .checkIfTypeImplementsExpectedInterfaces(VTable, ComplexType);
}
```

## Options

- `crashOnError: bool` - Set to `true` to get compile-time errors with details, `false` for tests
