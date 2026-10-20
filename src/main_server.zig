const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;

const zync = @import("zync");
const zmsg = zync.protocol.msg;

const max_msg_len = std.math.maxInt(u16);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const receive_address = if (init.environ_map.get("ZYNC_HOST")) |zync_host| blk: {
        var addr = Io.net.IpAddress.parseLiteral(zync_host) catch |err| {
            std.log.err("{t}", .{err});
            return;
        };
        if (addr.getPort() == 0) addr.setPort(zync.protocol.default_port);
        break :blk addr;
    } else Io.net.IpAddress{
        .ip4 = .unspecified(zync.protocol.default_port),
    };
    const socket = try receive_address.bind(io, .{
        .mode = .dgram,
        .protocol = .udp,
    });
    std.debug.print("listening on {f}...\n", .{socket.address});

    var msg_data_buf: [max_msg_len]u8 = undefined;
    const quit_msg = "quit";
    comptime assert(msg_data_buf.len >= quit_msg.len); // NOTE: Must be able to store quit message

    var msg_arena: std.heap.ArenaAllocator = .init(gpa);
    defer msg_arena.deinit();
    const arena = msg_arena.allocator();

    while (true) {
        _ = msg_arena.reset(.retain_capacity);

        const msg = try socket.receive(io, &msg_data_buf);
        const marker: zync.protocol.Marker = @fromBackingInt(msg.data[0]);
        assert(!msg.flags.trunc);
        switch (marker) {
            .init => {
                const init_msg: zmsg.Init = try .deserialize(msg.data);
                std.debug.print("<- (from: {f}) {f}\n", .{ msg.from, init_msg });
            },
            .init_response => {
                const init_response_msg: zmsg.InitResponse = try .deserialize(msg.data);
                std.debug.print("<- (from: {f}) {f}\n", .{ msg.from, init_response_msg });
            },
            .ping => {
                const ping_msg: zmsg.Ping = try .deserializeAlloc(arena, msg.data);
                std.debug.print("  {f}\n", .{ping_msg});
                std.debug.print("<- (from: {f}) {f}\n", .{ msg.from, ping_msg });

                var aw: Io.Writer.Allocating = .init(arena);
                const response: zmsg.Ping = .{
                    .message = ping_msg.message,
                };
                try response.serialize(&aw.writer);

                try socket.send(io, &msg.from, aw.written());
            },
        }

        if (std.mem.eql(u8, msg.data, quit_msg)) {
            std.debug.print("exiting\n", .{});
            break;
        }
    }
}
