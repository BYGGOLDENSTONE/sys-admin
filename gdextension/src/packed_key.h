#ifndef PACKED_KEY_H
#define PACKED_KEY_H

#include <cstdint>

// Packed key layout: (sub_type+1 << 16) | (content << 12) | (state << 8) | (tier << 4) | tags
// sub_type stored as +1 offset: 0=none(-1), 1=sub0, 2=sub1, etc.
// Packet flag: bit 24 set (shifted up to avoid sub_type collision)

static constexpr int PACK_PACKET_BIT = 1 << 24;

static inline int unpack_content(int64_t k) { return (int)((k >> 12) & 0xF); }
static inline int unpack_state(int64_t k)   { return (int)((k >> 8) & 0xF); }
static inline int unpack_tier(int64_t k)    { return (int)((k >> 4) & 0xF); }
static inline int unpack_tags(int64_t k)    { return (int)(k & 0xF); }
static inline int unpack_sub_type(int64_t k) { return (int)(((k >> 16) & 0xF) - 1); }
static inline int pack_key(int c, int s, int t, int tg, int st = -1) { return (((st + 1) & 0xF) << 16) | (c << 12) | (s << 8) | (t << 4) | tg; }
static inline bool is_packet(int64_t k) { return (k & PACK_PACKET_BIT) != 0; }

#endif // PACKED_KEY_H
