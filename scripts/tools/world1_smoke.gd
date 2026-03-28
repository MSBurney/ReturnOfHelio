extends SceneTree

## Headless smoke gate for World 1 JSON data.
## Usage:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path . --script res://scripts/tools/world1_smoke.gd

const LEVEL_PATHS: PackedStringArray = [
	"res://data/levels/world1/w1_l01.json",
	"res://data/levels/world1/w1_l02.json",
	"res://data/levels/world1/w1_l03.json",
	"res://data/levels/world1/w1_l04.json",
	"res://data/levels/world1/w1_l05.json",
	"res://data/levels/world1/w1_l06.json",
	"res://data/levels/world1/w1_l07.json",
	"res://data/levels/world1/w1_l08.json",
	"res://data/levels/world1/w1_l09.json",
	"res://data/levels/world1/w1_l10.json",
	"res://data/levels/world1/w1_l11.json",
	"res://data/levels/world1/w1_l12.json",
	"res://data/levels/world1/w1_l13.json",
	"res://data/levels/world1/w1_boss.json",
]

var _failures: PackedStringArray = []

func _initialize() -> void:
	_run_smoke()
	if _failures.is_empty():
		print("WORLD1_SMOKE:PASS")
		quit(0)
		return
	for line in _failures:
		push_error(line)
	print("WORLD1_SMOKE:FAIL (%d issues)" % _failures.size())
	quit(1)

func _run_smoke() -> void:
	for path in LEVEL_PATHS:
		_validate_level(path)

func _validate_level(path: String) -> void:
	var data: LevelData = LevelData.load_from_file(path)
	if data == null:
		_fail(path, "Could not load JSON level data.")
		return
	if data.segments.is_empty():
		_fail(path, "No segments were found.")
		return
	if not data.segments.has(data.start_segment):
		_fail(path, "Missing start segment '%s'." % data.start_segment)
	if data.level_id == "":
		_fail(path, "Missing level_id.")

	var has_goal: bool = false
	var has_boss: bool = false

	for seg_id in data.segments.keys():
		var segment: LevelData.SegmentData = data.segments[seg_id]
		if segment.width <= 0 or segment.height <= 0:
			_fail(path, "Segment '%s' has invalid size %dx%d." % [seg_id, segment.width, segment.height])
		_validate_connections(path, segment, data)
		for entity in segment.entities:
			match entity.type:
				"goal":
					has_goal = true
				"boss", "boss_king_ribbit":
					has_boss = true
				_:
					pass

	if data.level <= 13 and data.level > 0 and not has_goal:
		_fail(path, "Non-boss level is missing a goal entity.")
	if data.level == 0 and not has_boss:
		_fail(path, "Boss level is missing a boss entity.")
func _validate_connections(path: String, segment: LevelData.SegmentData, data: LevelData) -> void:
	for conn in segment.connections:
		if not data.segments.has(conn.target_segment):
			_fail(path, "Segment '%s' has connection to missing segment '%s'." % [segment.id, conn.target_segment])
		if conn.door_pos.x < 0 or conn.door_pos.y < 0:
			_fail(path, "Segment '%s' has invalid door_pos %s." % [segment.id, str(conn.door_pos)])
		if conn.target_pos.x < 0 or conn.target_pos.y < 0:
			_fail(path, "Segment '%s' has invalid target_pos %s." % [segment.id, str(conn.target_pos)])

func _fail(path: String, message: String) -> void:
	_failures.append("%s :: %s" % [path, message])
