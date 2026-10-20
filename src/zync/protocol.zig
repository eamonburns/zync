const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const default_port: u16 = 4321;

pub const msg = @import("protocol/msg.zig");

pub const Marker = enum(u8) {
    init,
    init_response,
    ping,
};

comptime {
    for (@typeInfo(msg).@"struct".decl_names, @typeInfo(Marker).@"enum".field_names) |msg_name, marker_name| {
        var it = std.mem.splitScalar(u8, marker_name, '_');
        var i: usize = 0;
        while (it.next()) |marker_segment| : (i += marker_segment.len) {
            const msg_segment = msg_name[i .. i + marker_segment.len];
            if (marker_segment.len == 0) {
                @compileError("marker name " ++ marker_name ++ " has a double underscore");
            }
            if (!std.ascii.isUpper(msg_segment[0])) {
                @compileError("message name " ++ msg_name ++ " does not match marker name " ++ marker_name);
            }
            if (marker_segment[0] != std.ascii.toLower(msg_segment[0])) {
                @compileError("message name " ++ msg_name ++ " does not match marker name " ++ marker_name);
            }
            if (!std.mem.eql(u8, marker_segment[1..], msg_segment[1..])) {
                @compileError("message name " ++ msg_name ++ " does not match marker name " ++ marker_name);
            }
            if (!@hasDecl(@field(msg, msg_name), "marker")) {
                @compileError("message " ++ msg_name ++ " has no `marker` declaration");
            }
            if (@field(msg, msg_name).marker != @field(Marker, marker_name)) {
                @compileError("marker for message " ++ msg_name ++ " is not equal to Marker." ++ marker_name);
            }
        }
        if (i != msg_name.len) @compileError("TODO: Good error message");
    }
}

pub fn MakeSerializeFn(T: type) fn (T, *Io.Writer) Io.Writer.Error!void {
    return struct {
        pub fn impl(message: T, writer: *Io.Writer) Io.Writer.Error!void {
            try writer.writeByte(@backingInt(T.marker));

            const message_info = @typeInfo(T).@"struct";
            inline for (message_info.field_names, message_info.field_types) |field_name, field_type| {
                switch (field_type) {
                    u8 => {
                        try writer.writeByte(@field(message, field_name));
                    },
                    []u8, []const u8 => {
                        const len: u32 = @intCast(@field(message, field_name).len);
                        try writer.writeInt(u32, len, .big);
                        try writer.writeAll(@field(message, field_name));
                    },
                    else => @compileError("unable to serialize field " ++ field_name ++ " of type " ++ @typeName(field_type)),
                }
            }
        }
    }.impl;
}

pub fn MakeDeserializeFn(T: type) fn ([]u8) T {
    return struct {
        pub fn impl(bytes: []u8) T {
            const marker: Marker = @fromBackingInt(bytes[0]);
            assert(marker == T.marker);

            var message: T = undefined;

            const message_info = @typeInfo(T).@"struct";
            var i: usize = 1; // Start after `marker`
            inline for (message_info.field_names, message_info.field_types) |field_name, field_type| {
                switch (field_type) {
                    u8 => {
                        defer i += @sizeOf(field_type);
                        @field(message, field_name) = bytes[i];
                    },
                    []u8, []const u8 => @compileError("unable to deserialize field " ++ field_name ++ " of type " ++ @typeName(field_type) ++ " (use MakeDeserializeAllocFn)"),
                    else => @compileError("unable to deserialize field " ++ field_name ++ " of type " ++ @typeName(field_type)),
                }
            }

            return message;
        }
    }.impl;
}

pub fn MakeDeserializeAllocFn(T: type) fn (Allocator, []u8) Allocator.Error!T {
    return struct {
        pub fn impl(gpa: Allocator, bytes: []u8) Allocator.Error!T {
            const marker: Marker = @fromBackingInt(bytes[0]);
            assert(marker == T.marker);

            var message: T = undefined;

            const message_info = @typeInfo(T).@"struct";
            var i: usize = 1; // Start after `marker`
            inline for (message_info.field_names, message_info.field_types) |field_name, field_type| {
                switch (field_type) {
                    u8 => {
                        defer i += @sizeOf(field_type);
                        @field(message, field_name) = bytes[i];
                    },
                    []u8, []const u8 => {
                        const len: u32 = std.mem.readInt(u32, &.{
                            bytes[i + 0],
                            bytes[i + 1],
                            bytes[i + 2],
                            bytes[i + 3],
                        }, .big); // TODO: Handle buffer too small
                        i += 4;
                        const slice = bytes[i .. i + len]; // TODO: Handle buffer too small
                        @field(message, field_name) = try gpa.dupe(u8, slice);
                    },
                    else => @compileError("unable to deserialize field " ++ field_name ++ " of type " ++ @typeName(field_type)),
                }
            }

            return message;
        }
    }.impl;
}
