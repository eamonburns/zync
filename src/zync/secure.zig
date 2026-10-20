const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Key = [32]u8;
const Aead = std.crypto.aead.chacha_poly.ChaCha20Poly1305;
const X25519 = std.crypto.dh.X25519;
const HkdfSha256 = std.crypto.kdf.hkdf.HkdfSha256;

const Nonce = [Aead.nonce_length]u8;
const Tag = [Aead.tag_length]u8;

const Envelope = struct {
    ephemeral_public_key: Key,
    nonce: Nonce,
    cipher_text: []u8,
    tag: Tag,

    pub fn deinit(envelope: Envelope, gpa: Allocator) void {
        gpa.free(envelope.cipher_text);
    }

    pub fn fromPlainText(io: Io, gpa: Allocator, recipient_public_key: Key, plain_text: []const u8) !Envelope {
        // TODO: Actually encrypt
        _ = io;
        _ = recipient_public_key;

        const cipher_text = try gpa.alloc(u8, plain_text.len);
        for (cipher_text, plain_text) |*cipher_char, plain_char| {
            cipher_char.* = plain_char +| 100;
        }
        return .{
            .ephemeral_public_key = undefined,
            .nonce = undefined,
            .cipher_text = cipher_text,
            .tag = undefined,
        };
    }

    pub fn toPlainText(envelope: Envelope, gpa: Allocator, recipient_secret_key: Key) ![]u8 {
        // TODO: Actually decrypt
        _ = recipient_secret_key;

        const plain_text = try gpa.alloc(u8, envelope.cipher_text.len);
        for (plain_text, envelope.cipher_text) |*plain_char, cipher_char| {
            plain_char.* = cipher_char -| 100;
        }
        return plain_text;
    }
};
