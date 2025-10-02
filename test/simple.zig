const std = @import("std");
const Interface = @import("interface");
const testing = std.testing;
const print = std.debug.print;

const err = error{FieldNotThere};

const vtable = struct {
    mailTheUser: fn (self: anytype) err!void,
    printName: fn (self: anytype) void,
};
const User = struct {
    age: u32 = 0,
    name: []const u8 = "",
    emaiAddress: []const u8 = "",
    pub fn mailTheUser(self: User) err!void {
        if (self.emaiAddress.len <= 0) return err.FieldNotThere;
        print("emailed the user at {s}\n", .{self.emaiAddress});
    }
    pub fn printName(self: User) void {
        print("the user's name is {s}\n", .{self.name});
    }
};

const WrongUser = struct {
    age: u32,
    name: []const u8,
    emaiAddress: []const u8,
    pub fn mailTheUser(self: WrongUser) !void {
        if (self.emaiAddress.len <= 0) return err.FieldNotThere;
        print("emailed the user at {s}\n", .{self.emaiAddress});
    }
    pub fn printName(self: WrongUser) void {
        print("the user's name is {s}\n", .{self.name});
    }
};
test "A simple test " {
    comptime {
        const user = User{ .name = "some random", .emaiAddress = "abc@email.com", .age = 22 };
        const wronguser = WrongUser{ .name = "some random", .emaiAddress = "abc@email.com", .age = 22 };
        try Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(vtable, user);
        const res = Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(vtable, wronguser);
        try testing.expectError(Interface.ParamTypeCheckingError.TypeDoesNotMatch, res);
    }
    print("we are testing a simple test\n", .{});
}
