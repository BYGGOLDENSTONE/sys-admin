class_name DataEnums

enum ContentType { STANDARD, FINANCIAL, BIOMETRIC, BLUEPRINT, RESEARCH, CLASSIFIED, KEY, REPAIR_KIT }
enum DataState { PUBLIC, ENCRYPTED, CORRUPTED, MALWARE, ENC_COR }

## Processing tags — bit flags that accumulate on data as it gets processed
enum ProcessingTag {
	NONE = 0,
	DECRYPTED = 1,   ## Applied by Decryptor
	RECOVERED = 2,   ## Applied by Recoverer
	ENCRYPTED = 4,   ## Applied by Encryptor
}

## Encrypted tiers (bit-depth)
const BIT_4: int = 1
const BIT_16: int = 2
const BIT_32: int = 3  ## Full release only

## Corrupted tiers (glitch severity)
const MINOR_GLITCHED: int = 1
const MAJOR_GLITCHED: int = 2
const CRITICAL_GLITCHED: int = 3  ## Full release only

static func make_key(content: int, state: int, tier: int = 0, tags: int = 0) -> String:
	return "%d_%d_%d_%d" % [content, state, tier, tags]

static func parse_key(key: String) -> Dictionary:
	var parts = key.split("_")
	var tier: int = int(parts[2]) if parts.size() > 2 else 0
	var tags: int = int(parts[3]) if parts.size() > 3 else 0
	return { "content": int(parts[0]), "state": int(parts[1]), "tier": tier, "tags": tags }

static func tier_name(t: int, state: int = -1) -> String:
	if t <= 0:
		return ""
	if state == DataState.ENCRYPTED:
		match t:
			BIT_4: return "4-bit"
			BIT_16: return "16-bit"
			BIT_32: return "32-bit"
		return "%d-bit" % (4 * (1 << (t - 1)))
	if state == DataState.CORRUPTED:
		match t:
			MINOR_GLITCHED: return "Minor-Glitched"
			MAJOR_GLITCHED: return "Major-Glitched"
			CRITICAL_GLITCHED: return "Critical-Glitched"
		return "Glitch-T%d" % t
	return "T%d" % t

static func content_name(c: int) -> String:
	match c:
		ContentType.STANDARD: return "Standard"
		ContentType.FINANCIAL: return "Financial"
		ContentType.BIOMETRIC: return "Biometric"
		ContentType.BLUEPRINT: return "Blueprint"
		ContentType.RESEARCH: return "Research"
		ContentType.CLASSIFIED: return "Classified"
		ContentType.KEY: return "Key"
		ContentType.REPAIR_KIT: return "Repair Kit"
	return "Unknown"

static func state_name(s: int) -> String:
	match s:
		DataState.PUBLIC: return "Public"
		DataState.ENCRYPTED: return "Encrypted"
		DataState.CORRUPTED: return "Corrupted"
		DataState.MALWARE: return "Malware"
		DataState.ENC_COR: return "Enc·Cor"
	return "Unknown"

static func state_color(s: int) -> Color:
	match s:
		DataState.PUBLIC: return Color("#00ffaa")
		DataState.ENCRYPTED: return Color("#2288ff")
		DataState.CORRUPTED: return Color("#ffaa00")
		DataState.MALWARE: return Color("#ff1133")
		DataState.ENC_COR: return Color("#88aa44")
	return Color("#778899")

static func content_char(c: int) -> String:
	match c:
		ContentType.STANDARD: return "1"
		ContentType.FINANCIAL: return "$"
		ContentType.BIOMETRIC: return "@"
		ContentType.BLUEPRINT: return "#"
		ContentType.RESEARCH: return "?"
		ContentType.CLASSIFIED: return "!"
		ContentType.KEY: return "K"
		ContentType.REPAIR_KIT: return "R"
	return "0"


static func content_color(c: int) -> Color:
	match c:
		ContentType.STANDARD: return Color("#7788aa")
		ContentType.FINANCIAL: return Color("#ffcc00")
		ContentType.BIOMETRIC: return Color("#ff88cc")
		ContentType.BLUEPRINT: return Color("#00ffcc")
		ContentType.RESEARCH: return Color("#9955ff")
		ContentType.CLASSIFIED: return Color("#ff3388")
		ContentType.KEY: return Color("#ffaa00")
		ContentType.REPAIR_KIT: return Color("#ff7744")
	return Color("#7788aa")

static func state_color_hex(s: int) -> String:
	match s:
		DataState.PUBLIC: return "#00ffaa"
		DataState.ENCRYPTED: return "#2288ff"
		DataState.CORRUPTED: return "#ffaa00"
		DataState.MALWARE: return "#ff1133"
		DataState.ENC_COR: return "#88aa44"
	return "#778899"


static func tags_label(tags: int) -> String:
	if tags == 0:
		return ""
	var parts: PackedStringArray = []
	if tags & ProcessingTag.DECRYPTED:
		parts.append("Decrypted")
	if tags & ProcessingTag.RECOVERED:
		parts.append("Recovered")
	if tags & ProcessingTag.ENCRYPTED:
		parts.append("Encrypted")
	return "·".join(parts)


static func data_label(content: int, state: int, tier: int = 0, tags: int = 0) -> String:
	var label: String = content_name(content)
	if tags != 0:
		label += " " + tags_label(tags)
	elif state != DataState.PUBLIC:
		label += " " + state_name(state)
	else:
		label += " Public"
	if state == DataState.ENC_COR:
		var et: int = compound_enc_tier(tier)
		var ct: int = compound_cor_tier(tier)
		if et > 0 or ct > 0:
			label += " %s·%s" % [tier_name(et, DataState.ENCRYPTED), tier_name(ct, DataState.CORRUPTED)]
	else:
		var t: String = tier_name(tier, state)
		if t != "":
			label += " " + t
	return label


static func content_color_hex(c: int) -> String:
	match c:
		ContentType.STANDARD: return "#7788aa"
		ContentType.FINANCIAL: return "#ffcc00"
		ContentType.BIOMETRIC: return "#ff88cc"
		ContentType.BLUEPRINT: return "#00ffcc"
		ContentType.RESEARCH: return "#9955ff"
		ContentType.CLASSIFIED: return "#ff3388"
		ContentType.KEY: return "#ffaa00"
		ContentType.REPAIR_KIT: return "#ff7744"
	return "#7788aa"


## --- PACKED INT KEYS (O13 optimization) ---
## Key format: bits 15-12=content, 11-8=state, 7-4=tier, 3-0=tags

static func pack_key(content: int, state: int, tier: int = 0, tags: int = 0) -> int:
	return (content << 12) | (state << 8) | (tier << 4) | tags

static func unpack_content(key: int) -> int:
	return (key >> 12) & 0xF

static func unpack_state(key: int) -> int:
	return (key >> 8) & 0xF

static func unpack_tier(key: int) -> int:
	return (key >> 4) & 0xF

static func unpack_tags(key: int) -> int:
	return key & 0xF

## --- COMPOUND STATE TIER HELPERS ---
## For ENC_COR state, tier field packs two sub-tiers: enc_tier(bits 3-2) | cor_tier(bits 1-0)
## Each sub-tier supports T0-T3 range (2 bits each, fits in 4-bit tier field)

static func make_compound_tier(enc_tier: int, cor_tier: int) -> int:
	return (enc_tier << 2) | cor_tier

static func compound_enc_tier(tier: int) -> int:
	return (tier >> 2) & 0x3

static func compound_cor_tier(tier: int) -> int:
	return tier & 0x3

static func is_compound_state(state: int) -> bool:
	return state == DataState.ENC_COR

