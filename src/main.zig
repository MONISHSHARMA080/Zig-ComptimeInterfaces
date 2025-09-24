const std = @import("std");
const print = std.debug.print;
const InterfaceCheck = @import("./CheckForInterfaceAtCmpTime.zig");

pub fn main() !void {
    // printTheTypes(Person);
    const a = animal{ .name = .cat };
    var p = Person{ .name = "bdb" };
    p.random(a);
}

const animal = struct {
    name: enum { cat, dog, lion, tiger, other } = .cat,
    pub fn speak(self: animal) void {
        std.debug.print("\n the animal is a {any} has spoken the work meow \n", .{self.name});
        return;
    }
};

const Person = struct {
    name: []const u8,
    number: i32 = 0,
    const vTable = struct {
        speak: fn (self: anytype) void,
    };
    pub fn random(_: Person, comptime zz: anytype) void {
        comptime InterfaceCheck.checkIfTypeImplementExpectedInterfaces(vTable, zz);
        const a: void = zz.speak();
        return a;
    }
};
