//! zync protocol message descriptions.

const std = @import("std");

const proto = @import("../protocol.zig");

pub const Init = struct {
    version: u8,

    pub const marker: proto.Marker = .init;
    pub const serialize = proto.MakeSerializeFn(@This());
    pub const deserialize = proto.MakeDeserializeFn(@This());
    pub const format = proto.MakeFormatFn(@This());
};

pub const InitResponse = struct {
    version: u8,

    pub const marker: proto.Marker = .init_response;
    pub const serialize = proto.MakeSerializeFn(@This());
    pub const deserialize = proto.MakeDeserializeFn(@This());
    pub const format = proto.MakeFormatFn(@This());
};

pub const Ping = struct {
    message: []const u8,

    pub const marker: proto.Marker = .ping;
    pub const serialize = proto.MakeSerializeFn(@This());
    pub const deserializeAlloc = proto.MakeDeserializeAllocFn(@This());
    pub const format = proto.MakeFormatFn(@This());
};
