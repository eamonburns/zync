const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;

const zync = @import("zync");
const zmsg = zync.protocol.msg;

const max_msg_len = std.math.maxInt(u16);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const addr: Io.net.IpAddress = .{
        .ip4 = .unspecified(4321),
    };
    const socket = try addr.bind(io, .{
        .mode = .dgram,
        .protocol = .udp,
    });
    std.debug.print("listening on port {d}...\n", .{socket.address.getPort()});

    var msg_data_buf: [max_msg_len]u8 = undefined;
    const quit_msg = "quit";
    comptime assert(msg_data_buf.len >= quit_msg.len); // NOTE: Must be able to store quit message

    var msg_arena: std.heap.ArenaAllocator = .init(gpa);
    defer msg_arena.deinit();
    while (true) {
        _ = msg_arena.reset(.retain_capacity);

        const msg = try socket.receive(io, &msg_data_buf);
        const marker: zync.protocol.Marker = @fromBackingInt(msg.data[0]);
        assert(!msg.flags.trunc);
        std.debug.print("<- (from: {f}) {t}\n", .{ msg.from, marker });
        switch (marker) {
            .init => {
                const init_msg: zmsg.Init = .deserialize(msg.data);
                std.debug.print("  {any}", .{init_msg});
            },
            .ping => {
                const ping_msg: zmsg.Ping = try .deserializeAlloc(msg_arena.allocator(), msg.data);
                std.debug.print("  {f}", .{ping_msg});
            },
            else => unreachable,
        }

        if (std.mem.eql(u8, msg.data, quit_msg)) {
            std.debug.print("exiting\n", .{});
            break;
        }

        std.debug.print("  -> ping\n", .{});
        try socket.send(io, &msg.from, "ping");
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
