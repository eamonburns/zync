const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;

const zync = @import("zync");
const zmsg = zync.protocol.msg;

const max_msg_len = std.math.maxInt(u16);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const local_addr: Io.net.IpAddress = .{
        .ip4 = .unspecified(0), // NOTE: Request ephemeral port
    };
    const socket = try local_addr.bind(io, .{
        .mode = .dgram,
        .protocol = .udp,
    });
    std.debug.print("sending from port {d}...\n", .{socket.address.getPort()});

    const server_address = if (init.environ_map.get("ZYNC_HOST")) |zync_host| blk: {
        var addr = Io.net.IpAddress.parseLiteral(zync_host) catch |err| {
            std.log.err("{t}", .{err});
            return;
        };
        if (addr.getPort() == 0) addr.setPort(zync.protocol.default_port);
        break :blk addr;
    } else Io.net.IpAddress{
        .ip4 = .loopback(zync.protocol.default_port),
    };
    std.debug.print("sending to server {f}\n", .{server_address});

    var msg_data_buf: [max_msg_len]u8 = undefined;

    var msg_arena: std.heap.ArenaAllocator = .init(gpa);
    defer msg_arena.deinit();
    while (true) {
        _ = msg_arena.reset(.retain_capacity);

        var zmsg_buf: [1024]u8 = undefined;
        var zmsg_writer: Io.Writer = .fixed(&zmsg_buf);
        var message: [10]u8 = undefined;
        io.random(&message);
        const ping_msg: zmsg.Ping = .{
            .message = &message,
        };
        try ping_msg.serialize(&zmsg_writer);
        const msg_data = zmsg_writer.buffered();

        try io.sleep(.fromSeconds(1), .real);
        std.debug.print("-> {t} ({f})\n", .{ @TypeOf(ping_msg).marker, ping_msg });
        try socket.send(io, &server_address, msg_data);
        const msg = try socket.receiveTimeout(io, &msg_data_buf, .{ .duration = .{
            .clock = .real,
            .raw = .fromSeconds(1),
        } });
        std.debug.print("  <- (from: {f}) {q}", .{ msg.from, msg.data });

        if (msg.flags.trunc) {
            std.debug.print("...\n", .{});
        } else {
            std.debug.print("\n", .{});
        }
    }
}
