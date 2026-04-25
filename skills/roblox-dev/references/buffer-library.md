# `buffer` Library Reference

Fixed-size mutable byte block. Source: [`buffer.yaml` in creator-docs](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/libraries/buffer.yaml).

- Max size: **1 GiB** (`1_073_741_824` bytes).
- Numeric reads/writes are **little-endian**.
- All offsets are **byte offsets from 0** (except `readbits`/`writebits` which use **bit offsets**).
- Reading/writing past the buffer raises an error.
- Sending a buffer through Roblox APIs (RemoteEvents, etc.) **copies** it — the receiver gets a new buffer object.
- Cannot share a buffer between Actor scripts (Parallel Luau).

---

## Lifecycle

```
buffer.create(size: number) -> buffer
buffer.fromstring(value: string) -> buffer
buffer.tostring(b: buffer) -> string
buffer.len(b: buffer) -> number
```

`create` zero-initializes. `fromstring` makes a buffer the same byte length as the string. `tostring` returns the full byte content.

---

## Numeric reads / writes

For each integer width — i8, u8, i16, u16, i32, u32 — and floats f32, f64:

```
buffer.readi8(b: buffer, offset: number) -> number
buffer.writei8(b: buffer, offset: number, value: number) -> ()

buffer.readu8(b: buffer, offset: number) -> number
buffer.writeu8(b: buffer, offset: number, value: number) -> ()

buffer.readi16 / writei16   (2 bytes)
buffer.readu16 / writeu16   (2 bytes)
buffer.readi32 / writei32   (4 bytes)
buffer.readu32 / writeu32   (4 bytes)
buffer.readf32 / writef32   (4 bytes, IEEE 754 single)
buffer.readf64 / writef64   (8 bytes, IEEE 754 double)
```

Signed reads sign-extend. Writes truncate to width. All little-endian.

---

## Bit-level

```
buffer.readbits(b: buffer, bitOffset: number, bitCount: number) -> number
buffer.writebits(b: buffer, bitOffset: number, bitCount: number, value: number) -> ()
```

`bitCount` is `0..32` inclusive. `0` returns `0` (supported so generalized code with dynamic bit widths doesn't error). Convenience equivalences:

- `readbits(b, 0, 8)` ≡ `readu8(b, 0)`
- `readbits(b, 0, 16)` ≡ `readu16(b, 0)`
- `readbits(b, 0, 32)` ≡ `readu32(b, 0)`
- `readbits(b, 0, 24)` reads 24 bits — no fixed-width call gives you that.

`bitOffset` is a number; since the max buffer is 1 GiB, the bit-offset cannot be assumed to fit in 32-bit ranges in all calculations.

---

## Strings

```
buffer.readstring(b: buffer, offset: number, count: number) -> string
buffer.writestring(b: buffer, offset: number, value: string, count: number?) -> ()
```

`writestring` with optional `count` writes at most `count` bytes from `value`. `count` cannot exceed `#value`.

---

## Bulk

```
buffer.copy(target: buffer, targetOffset: number, source: buffer, sourceOffset: number?, count: number?) -> ()
buffer.fill(b: buffer, offset: number, value: number, count: number?) -> ()
```

- `copy` accepts `source == target`. Overlapping regions are handled as if the source were copied through a temporary.
- `fill` writes `value` (treated as 8-bit unsigned) `count` times. `count` defaults to "to end of buffer".

---

## Use cases

- **Compact RemoteEvent payloads.** A packed buffer is smaller than the equivalent Luau table after Roblox's wire format. Worth it for high-frequency events (e.g. position updates, inputs).
- **DataStore value compression.** Pack into a buffer, `tostring`, store. Decode on read.
- **Reading binary formats** — anything `string.pack`/`unpack` can do, with a stable mutable structure instead of repeated string concatenations.
- **Preallocated scratch space** when constructing large strings byte-by-byte (avoids `..` quadratic behavior).

---

## Don't use it for

- Tiny payloads. `buffer.create` + reads/writes is overhead vs a 3-field Luau table for occasional events.
- Arbitrary structured data — there's no schema. Pair the buffer with a fixed serialization format you control.
- Storage you'll mutate concurrently across Actors. Buffers aren't shareable.
