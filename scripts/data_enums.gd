class_name DataEnums

enum ContentType { STANDARD, FINANCIAL, BIOMETRIC, BLUEPRINT, RESEARCH, CLASSIFIED }
enum DataState { CLEAN, ENCRYPTED, CORRUPTED, MALWARE }

static func make_key(content: int, state: int) -> String:
	return "%d_%d" % [content, state]

static func parse_key(key: String) -> Dictionary:
	var parts = key.split("_")
	return { "content": int(parts[0]), "state": int(parts[1]) }

static func content_name(c: int) -> String:
	match c:
		ContentType.STANDARD: return "Standard"
		ContentType.FINANCIAL: return "Financial"
		ContentType.BIOMETRIC: return "Biometric"
		ContentType.BLUEPRINT: return "Blueprint"
		ContentType.RESEARCH: return "Research"
		ContentType.CLASSIFIED: return "Classified"
	return "Unknown"

static func state_name(s: int) -> String:
	match s:
		DataState.CLEAN: return "Clean"
		DataState.ENCRYPTED: return "Encrypted"
		DataState.CORRUPTED: return "Corrupted"
		DataState.MALWARE: return "Malware"
	return "Unknown"

static func state_color(s: int) -> Color:
	match s:
		DataState.CLEAN: return Color("#44ff88")
		DataState.ENCRYPTED: return Color("#44aaff")
		DataState.CORRUPTED: return Color("#ff8844")
		DataState.MALWARE: return Color("#ff4466")
	return Color("#aabbcc")

static func content_color(c: int) -> Color:
	match c:
		ContentType.STANDARD: return Color("#aabbcc")
		ContentType.FINANCIAL: return Color("#ffdd44")
		ContentType.BIOMETRIC: return Color("#ff88cc")
		ContentType.BLUEPRINT: return Color("#88ffdd")
		ContentType.RESEARCH: return Color("#aa88ff")
		ContentType.CLASSIFIED: return Color("#ff6666")
	return Color("#aabbcc")

static func state_color_hex(s: int) -> String:
	match s:
		DataState.CLEAN: return "#44ff88"
		DataState.ENCRYPTED: return "#44aaff"
		DataState.CORRUPTED: return "#ff8844"
		DataState.MALWARE: return "#ff4466"
	return "#aabbcc"

static func content_color_hex(c: int) -> String:
	match c:
		ContentType.STANDARD: return "#aabbcc"
		ContentType.FINANCIAL: return "#ffdd44"
		ContentType.BIOMETRIC: return "#ff88cc"
		ContentType.BLUEPRINT: return "#88ffdd"
		ContentType.RESEARCH: return "#aa88ff"
		ContentType.CLASSIFIED: return "#ff6666"
	return "#aabbcc"
