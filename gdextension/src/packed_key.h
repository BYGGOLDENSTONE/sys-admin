#ifndef PACKED_KEY_H
#define PACKED_KEY_H

#include <cstdint>

// Packed key layout: (content << 12) | (state << 8) | (tier << 4) | tags
// Packet flag: bit 16 set

static constexpr int PACK_PACKET_BIT = 1 << 16;

static inline int unpack_content(int64_t k) { return (int)((k >> 12) & 0xF); }
static inline int unpack_state(int64_t k)   { return (int)((k >> 8) & 0xF); }
static inline int unpack_tier(int64_t k)    { return (int)((k >> 4) & 0xF); }
static inline int unpack_tags(int64_t k)    { return (int)(k & 0xF); }
static inline int pack_key(int c, int s, int t, int tg) { return (c << 12) | (s << 8) | (t << 4) | tg; }
static inline bool is_packet(int64_t k) { return (k & PACK_PACKET_BIT) != 0; }

#endif // PACKED_KEY_H
