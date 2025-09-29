const std = @import("std");
const print = std.debug.print;
const InterfaceImpl = @import("./CheckForInterfaceAtCmpTime.zig");

pub fn main() !void {
    // printTheTypes(Person);
    const a = animal{ .name = .cat };
    var p = Person{ .name = "bdb" };
    try p.random(a);
}

const err11 = error{ Random1, Random2 };

const animal = struct {
    name: enum { cat, dog, lion, tiger, other } = .cat,
    pub fn speak(self: animal) !void {
        std.debug.print("\n the animal is a {any} has spoken the work meow \n", .{self.name});
        return;
    }
};

const Person = struct {
    name: []const u8,
    number: i32 = 0,
    const vTable = struct {
        speak: fn (self: anytype) err11!void,
    };
    pub fn random(_: Person, comptime zz: anytype) !void {
        comptime InterfaceImpl.InterfaceCheck(.{}).checkIfTypeImplementsExpectedInterfaces(vTable, zz);
        const a: void = try zz.speak();
        return a;
    }
};
