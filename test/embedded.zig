const std = @import("std");
const Interface = @import("interface");
const testing = std.testing;
const cmpPrint = std.fmt.comptimePrint;
const print = std.debug.print;

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
};

test "interface embedding" {
    print("testing interface embedding\n", .{});

    // Base Logger interface
    const LoggerVTable = struct {
        log: fn (self: anytype, message: []const u8) void,
        getLogLevel: fn (self: anytype) u8,
    };

    // Metrics interface that embeds Logger
    const MetricsVTable1 = struct {
        increment: fn (self: anytype, key: []const u8) void,
        getValue: fn (self: anytype, key: []const u8) u64,
        // Embedded from Logger
        log: fn (self: anytype, message: []const u8) void,
        getLogLevel: fn (self: anytype) u8,
    };

    // Repository interface that embeds Metrics (and transitively Logger)
    const MonitoredRepositoryVTable = struct {
        create: fn (self: anytype, user: User) anyerror!u32,
        findById: fn (self: anytype, id: u32) anyerror!?User,
        update: fn (self: anytype, user: User) anyerror!void,
        delete: fn (self: anytype, id: u32) anyerror!void,
        // Embedded from Metrics
        increment: fn (self: anytype, key: []const u8) void,
        getValue: fn (self: anytype, key: []const u8) u64,
        // Embedded from Logger (through Metrics)
        log: fn (self: anytype, message: []const u8) void,
        getLogLevel: fn (self: anytype) u8,
    };

    // Implementation that satisfies all embedded interfaces
    const TrackedRepository = struct {
        allocator: std.mem.Allocator,
        users: std.AutoHashMap(u32, User),
        next_id: u32,
        log_level: u8,
        metrics: std.StringHashMap(u64),

        const Self = @This();

        pub fn init(comptime allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .users = std.AutoHashMap(u32, User).init(allocator),
                .next_id = 1,
                .log_level = 0,
                .metrics = std.StringHashMap(u64).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.metrics.deinit();
            self.users.deinit();
        }

        // Logger interface methods
        pub fn log(self: Self, message: []const u8) void {
            _ = self;
            _ = message;
        }

        pub fn getLogLevel(self: Self) u8 {
            return self.log_level;
        }

        // Metrics interface methods
        pub fn increment(self: *Self, key: []const u8) void {
            if (self.metrics.get(key)) |value| {
                self.metrics.put(key, value + 1) catch {};
            } else {
                self.metrics.put(key, 1) catch {};
            }
        }

        pub fn getValue(self: Self, key: []const u8) u64 {
            return self.metrics.get(key) orelse 0;
        }

        // Repository interface methods
        pub fn create(self: *Self, user: User) anyerror!u32 {
            self.log("Creating new user");
            self.increment("users.created");
            var new_user = user;
            new_user.id = self.next_id;
            try self.users.put(self.next_id, new_user);
            self.next_id += 1;
            return new_user.id;
        }

        pub fn findById(self: *Self, id: u32) !?User {
            self.increment("users.lookup");
            return self.users.get(id);
        }

        pub fn update(self: *Self, user: User) !void {
            self.log("Updating user");
            self.increment("users.updated");
            if (!self.users.contains(user.id)) {
                return error.UserNotFound;
            }
            try self.users.put(user.id, user);
        }

        pub fn delete(self: *Self, id: u32) !void {
            self.log("Deleting user");
            self.increment("users.deleted");
            if (!self.users.remove(id)) {
                return error.UserNotFound;
            }
        }
    };

    comptime {
        var repo = try TrackedRepository.init(std.testing.allocator);
        defer repo.deinit();

        // Test that implementation satisfies the base Logger interface
        try Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(LoggerVTable, repo);

        // Test that implementation satisfies the Metrics interface (with embedded Logger)
        try Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(MetricsVTable1, repo);

        // Test that implementation satisfies the full MonitoredRepository interface
        try Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(MonitoredRepositoryVTable, repo);
    }

    print("interface embedding test passed\n", .{});
}

// Base Closer interface
const CloserVTable1 = struct {
    close: fn (self: anytype) void,
};

// Writer interface that embeds Closer
const WriterVTable = struct {
    write: fn (self: anytype, data: []const u8) anyerror!void,
    // Embedded from Closer
    close: fn (self: anytype) void,
};

// FileWriter interface that embeds Writer (and transitively Closer)
const FileWriterVTable = struct {
    flush: fn (self: anytype) anyerror!void,
    // Embedded from Writer
    write: fn (self: anytype, data: []const u8) anyerror!void,
    // Embedded from Closer (through Writer)
    close: fn (self: anytype) void,
};

// Implementation that satisfies all nested interfaces
const FileWriterStruct = struct {
    pub fn close(self: @This()) void {
        _ = self;
    }

    pub fn write(self: @This(), data: []const u8) anyerror!void {
        _ = self;
        _ = data;
    }

    pub fn flush(self: @This()) anyerror!void {
        _ = self;
    }
};

test "nested interface embedding" {
    print("testing nested interface embedding\n", .{});

    // Test satisfaction of base Closer interface
    comptime Interface.InterfaceCheck(.{}).checkIfTypeImplementsExpectedInterfaces(CloserVTable1, FileWriterStruct{}) catch unreachable;

    // Test satisfaction of Writer interface (with embedded Closer)
    var res = comptime try Interface.InterfaceCheck(.{}).checkIfTypeImplementsExpectedInterfaces(WriterVTable, FileWriterStruct{});

    // Test satisfaction of full FileWriter interface
    res = try comptime Interface.InterfaceCheck(.{}).checkIfTypeImplementsExpectedInterfaces(FileWriterVTable, FileWriterStruct{});
    print("nested interface embedding test passed\n", .{});
}

const MetricsVTable2 = struct {
    increment: fn (self: anytype, key: []const u8) void,
    getValue: fn (self: anytype, key: []const u8) u64,
    // Embedded from Logger
    log: fn (self: anytype, message: []const u8) void,
    getLogLevel: fn (self: anytype) u8,
};

// Implementation missing the embedded Logger methods
const IncompleteImpl = struct {
    pub fn increment(self: @This(), key: []const u8) void {
        _ = self;
        _ = key;
    }

    // Missing: log and getLogLevel from embedded Logger
};
test "incomplete implementation fails embedding check" {
    print("testing incomplete implementation with embedding\n", .{});
    const vtable11 = struct { fn1: fn (a: void) void, random2: fn (self: anytype, key: []const u8) u64 };
    const impl11 = struct {
        pub fn random2(self: @This(), key: []const u8) void {
            _ = self;
            _ = key;
        }
    };

    // This should fail because embedded methods are missing
    comptime {
        var res = Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(MetricsVTable2, IncompleteImpl{});
        try testing.expectError(Interface.ParamTypeCheckingError.TypeDoesNotMatch, res);
        res = Interface.InterfaceCheck(.{ .crashOnError = false }).checkIfTypeImplementsExpectedInterfaces(vtable11, impl11{});
        try testing.expectError(Interface.ParamTypeCheckingError.TypeDoesNotMatch, res);
    }

    print("incomplete implementation correctly failed embedding check\n", .{});
}
