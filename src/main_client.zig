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

    const server_addr: Io.net.IpAddress = .{
        .ip4 = .loopback(zync.protocol.default_port),
    };

    var msg_data_buf: [max_msg_len]u8 = undefined;

    var msg_arena: std.heap.ArenaAllocator = .init(gpa);
    defer msg_arena.deinit();
    while (true) {
        _ = msg_arena.reset(.retain_capacity);

        var zmsg_buf: [1024]u8 = undefined;
        var zmsg_writer: Io.Writer = .fixed(&zmsg_buf);
        const ping_msg: zmsg.Ping = .{
            .message = "hello",
        };
        try ping_msg.serialize(&zmsg_writer);
        const msg_data = zmsg_writer.buffered();

        try io.sleep(.fromSeconds(1), .real);
        std.debug.print("-> {t} ({f})\n", .{ @TypeOf(ping_msg).marker, ping_msg });
        try socket.send(io, &server_addr, msg_data);
        const msg = try socket.receiveTimeout(io, &msg_data_buf, .{ .duration = .{
            .clock = .real,
            .raw = .fromSeconds(1),
        } });
        std.debug.print("  <- (from: {f}) {s}", .{ msg.from, msg.data });

        if (msg.flags.trunc) {
            std.debug.print("...\n", .{});
        } else {
            std.debug.print("\n", .{});
        }
    }
}

// const std = @import("std");
// const Io = std.Io;
//
// const X25519 = std.crypto.dh.X25519;
// const HkdfSha256 = std.crypto.kdf.hkdf.HkdfSha256;
//
// const Nonce = [Aead.nonce_length]u8;
// const Tag = [Aead.tag_length]u8;
//
// const Envelope = struct {
//     ephemeral_public_key: Key,
//     nonce: Nonce,
//     ciphertext: []u8,
//     tag: Tag,
// };
//
// fn deriveKey(shared_secret: Key, salt: []const u8) Key {
//     const prk = HkdfSha256.extract(salt, &shared_secret);
//     var key: Key = undefined;
//     HkdfSha256.expand(&key, "example-message-encryption-v1", prk);
//     return key;
// }
//
// fn encrypt(
//     io: Io,
//     allocator: std.mem.Allocator,
//     recipient_public_key: Key,
//     plaintext: []const u8,
// ) !Envelope {
//     // Generate a fresh ephemeral key pair for this message.
//     const ephemeral: X25519.KeyPair = .generate(io);
//
//     const shared_secret = try X25519.scalarmult(
//         ephemeral.secret_key,
//         recipient_public_key,
//     );
//     defer {
//         var secret = shared_secret;
//         std.crypto.secureZero(u8, &secret);
//     }
//
//     const key = deriveKey(shared_secret, &ephemeral.public_key);
//     defer {
//         var secret = key;
//         std.crypto.secureZero(u8, &secret);
//     }
//
//     var nonce: Nonce = undefined;
//     io.random(&nonce);
//
//     const ciphertext = try allocator.alloc(u8, plaintext.len);
//     errdefer allocator.free(ciphertext);
//
//     var tag: Tag = undefined;
//
//     // Bind the ephemeral public key to the authenticated ciphertext.
//     Aead.encrypt(
//         ciphertext,
//         &tag,
//         plaintext,
//         &ephemeral.public_key,
//         nonce,
//         key,
//     );
//
//     return .{
//         .ephemeral_public_key = ephemeral.public_key,
//         .nonce = nonce,
//         .ciphertext = ciphertext,
//         .tag = tag,
//     };
// }
//
// fn decrypt(
//     allocator: std.mem.Allocator,
//     recipient_secret_key: Key,
//     envelope: Envelope,
// ) ![]u8 {
//     const shared_secret = try X25519.scalarmult(
//         recipient_secret_key,
//         envelope.ephemeral_public_key,
//     );
//     defer {
//         var secret = shared_secret;
//         std.crypto.secureZero(u8, &secret);
//     }
//
//     const key = deriveKey(
//         shared_secret,
//         &envelope.ephemeral_public_key,
//     );
//     defer {
//         var secret = key;
//         std.crypto.secureZero(u8, &secret);
//     }
//
//     const plaintext = try allocator.alloc(u8, envelope.ciphertext.len);
//     errdefer allocator.free(plaintext);
//
//     try Aead.decrypt(
//         plaintext,
//         envelope.ciphertext,
//         envelope.tag,
//         &envelope.ephemeral_public_key,
//         envelope.nonce,
//         key,
//     );
//
//     return plaintext;
// }
//
// pub fn main(init: std.process.Init) !void {
//     const io = init.io;
//     const gpa = init.gpa;
//
//     // Recipient creates a long-term X25519 key pair.
//     const recipient: X25519.KeyPair = .generate(io);
//
//     const message = "Confidential message";
//
//     // Sender encrypts using only the recipient's public key.
//     const envelope = try encrypt(
//         io,
//         gpa,
//         recipient.public_key,
//         message,
//     );
//     defer gpa.free(envelope.ciphertext);
//
//     // In a real application, transmit the envelope fields to the recipient.
//
//     // Recipient decrypts using their private key.
//     const plaintext = try decrypt(
//         gpa,
//         recipient.secret_key,
//         envelope,
//     );
//     defer gpa.free(plaintext);
//
//     std.debug.print("Decrypted: {s}\n", .{plaintext});
// }
