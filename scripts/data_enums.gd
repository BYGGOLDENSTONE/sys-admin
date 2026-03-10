class_name DataEnums

enum ContentType { STANDARD, FINANCIAL, BIOMETRIC, BLUEPRINT, RESEARCH, CLASSIFIED, KEY }
enum DataState { PUBLIC, ENCRYPTED, CORRUPTED, MALWARE }

## Processing tags — bit flags that accumulate on data as it gets processed
enum ProcessingTag {
	NONE = 0,
	DECRYPTED = 1,   ## Applied by Decryptor
	RECOVERED = 2,   ## Applied by Recoverer
	ENCRYPTED = 4,   ## Applied by Encryptor
}

static func make_key(content: int, state: int, tier: int = 0, tags: int = 0) -> String:
	return "%d_%d_%d_%d" % [content, state, tier, tags]

static func parse_key(key: String) -> Dictionary:
	var parts = key.split("_")
	var tier: int = int(parts[2]) if parts.size() > 2 else 0
	var tags: int = int(parts[3]) if parts.size() > 3 else 0
	return { "content": int(parts[0]), "state": int(parts[1]), "tier": tier, "tags": tags }

static func tier_name(t: int) -> String:
	if t <= 0:
		return ""
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
	return "Unknown"

static func state_name(s: int) -> String:
	match s:
		DataState.PUBLIC: return "Public"
		DataState.ENCRYPTED: return "Encrypted"
		DataState.CORRUPTED: return "Corrupted"
		DataState.MALWARE: return "Malware"
	return "Unknown"

static func state_color(s: int) -> Color:
	match s:
		DataState.PUBLIC: return Color("#00ffaa")
		DataState.ENCRYPTED: return Color("#2288ff")
		DataState.CORRUPTED: return Color("#ffaa00")
		DataState.MALWARE: return Color("#ff1133")
	return Color("#778899")

static func content_char(c: int) -> String:
	match c:
		ContentType.STANDARD: return ["0", "1"][randi() % 2]
		ContentType.FINANCIAL: return "$"
		ContentType.BIOMETRIC: return "@"
		ContentType.BLUEPRINT: return "#"
		ContentType.RESEARCH: return "?"
		ContentType.CLASSIFIED: return "!"
		ContentType.KEY: return "K"
	return "0"


static func content_color(c: int) -> Color:
	match c:
		ContentType.STANDARD: return Color("#7788aa")
		ContentType.FINANCIAL: return Color("#ffcc00")
		ContentType.BIOMETRIC: return Color("#ff33aa")
		ContentType.BLUEPRINT: return Color("#00ffcc")
		ContentType.RESEARCH: return Color("#9955ff")
		ContentType.CLASSIFIED: return Color("#ff3388")
		ContentType.KEY: return Color("#ffaa00")
	return Color("#7788aa")

static func state_color_hex(s: int) -> String:
	match s:
		DataState.PUBLIC: return "#00ffaa"
		DataState.ENCRYPTED: return "#2288ff"
		DataState.CORRUPTED: return "#ffaa00"
		DataState.MALWARE: return "#ff1133"
	return "#778899"

static func state_storage_cost(s: int) -> int:
	match s:
		DataState.PUBLIC: return 1
		DataState.ENCRYPTED: return 2
		DataState.CORRUPTED: return 3
		DataState.MALWARE: return 0  # Cannot be stored
	return 1


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
	var t: String = tier_name(tier)
	if t != "":
		label += " " + t
	return label


static func content_color_hex(c: int) -> String:
	match c:
		ContentType.STANDARD: return "#7788aa"
		ContentType.FINANCIAL: return "#ffcc00"
		ContentType.BIOMETRIC: return "#ff33aa"
		ContentType.BLUEPRINT: return "#00ffcc"
		ContentType.RESEARCH: return "#9955ff"
		ContentType.CLASSIFIED: return "#ff3388"
		ContentType.KEY: return "#ffaa00"
	return "#7788aa"

