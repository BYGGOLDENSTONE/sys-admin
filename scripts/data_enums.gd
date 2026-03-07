class_name DataEnums

enum ContentType { STANDARD, FINANCIAL, BIOMETRIC, BLUEPRINT, RESEARCH, CLASSIFIED, KEY }
enum DataState { CLEAN, ENCRYPTED, CORRUPTED, MALWARE, RESIDUE }
enum RefinedType { CALIBRATED_DATA, RECOVERY_MATRIX, SECURITY_CORE, TRADE_LICENSE, NEURAL_INDEX }

static func make_key(content: int, state: int, tier: int = 0) -> String:
	return "%d_%d_%d" % [content, state, tier]

static func parse_key(key: String) -> Dictionary:
	var parts = key.split("_")
	var tier: int = int(parts[2]) if parts.size() > 2 else 0
	return { "content": int(parts[0]), "state": int(parts[1]), "tier": tier }

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
		DataState.CLEAN: return "Clean"
		DataState.ENCRYPTED: return "Encrypted"
		DataState.CORRUPTED: return "Corrupted"
		DataState.MALWARE: return "Malware"
		DataState.RESIDUE: return "Residue"
	return "Unknown"

static func state_color(s: int) -> Color:
	match s:
		DataState.CLEAN: return Color("#44ff88")
		DataState.ENCRYPTED: return Color("#44aaff")
		DataState.CORRUPTED: return Color("#ff8844")
		DataState.MALWARE: return Color("#ff4466")
		DataState.RESIDUE: return Color("#888844")
	return Color("#aabbcc")

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
		ContentType.STANDARD: return Color("#aabbcc")
		ContentType.FINANCIAL: return Color("#ffdd44")
		ContentType.BIOMETRIC: return Color("#ff88cc")
		ContentType.BLUEPRINT: return Color("#88ffdd")
		ContentType.RESEARCH: return Color("#aa88ff")
		ContentType.CLASSIFIED: return Color("#ff6666")
		ContentType.KEY: return Color("#ffaa00")
	return Color("#aabbcc")

static func state_color_hex(s: int) -> String:
	match s:
		DataState.CLEAN: return "#44ff88"
		DataState.ENCRYPTED: return "#44aaff"
		DataState.CORRUPTED: return "#ff8844"
		DataState.MALWARE: return "#ff4466"
		DataState.RESIDUE: return "#888844"
	return "#aabbcc"

static func state_storage_cost(s: int) -> int:
	match s:
		DataState.CLEAN: return 1
		DataState.ENCRYPTED: return 2
		DataState.CORRUPTED: return 3
		DataState.MALWARE: return 0  # Cannot be stored
		DataState.RESIDUE: return 1
	return 1


static func content_color_hex(c: int) -> String:
	match c:
		ContentType.STANDARD: return "#aabbcc"
		ContentType.FINANCIAL: return "#ffdd44"
		ContentType.BIOMETRIC: return "#ff88cc"
		ContentType.BLUEPRINT: return "#88ffdd"
		ContentType.RESEARCH: return "#aa88ff"
		ContentType.CLASSIFIED: return "#ff6666"
		ContentType.KEY: return "#ffaa00"
	return "#aabbcc"


static func refined_name(r: int) -> String:
	match r:
		RefinedType.CALIBRATED_DATA: return "Calibrated Data"
		RefinedType.RECOVERY_MATRIX: return "Recovery Matrix"
		RefinedType.SECURITY_CORE: return "Security Core"
		RefinedType.TRADE_LICENSE: return "Trade License"
		RefinedType.NEURAL_INDEX: return "Neural Index"
	return "Unknown"


static func refined_color(r: int) -> Color:
	match r:
		RefinedType.CALIBRATED_DATA: return Color("#66ffcc")
		RefinedType.RECOVERY_MATRIX: return Color("#88ddff")
		RefinedType.SECURITY_CORE: return Color("#ff88ff")
		RefinedType.TRADE_LICENSE: return Color("#ffcc66")
		RefinedType.NEURAL_INDEX: return Color("#cc88ff")
	return Color("#ffffff")


static func refined_color_hex(r: int) -> String:
	match r:
		RefinedType.CALIBRATED_DATA: return "#66ffcc"
		RefinedType.RECOVERY_MATRIX: return "#88ddff"
		RefinedType.SECURITY_CORE: return "#ff88ff"
		RefinedType.TRADE_LICENSE: return "#ffcc66"
		RefinedType.NEURAL_INDEX: return "#cc88ff"
	return "#ffffff"
