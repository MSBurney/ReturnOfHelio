extends SceneTree

## Extended gate check used before content scaling.
## Produces a compact report in user://world1_gate_report.json.

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

var _report: Dictionary = {
	"levels": [],
	"summary": {"passed": true, "failures": []},
}

func _initialize() -> void:
	for path in LEVEL_PATHS:
		_check_level(path)
	_write_report()
	var summary: Dictionary = _report["summary"]
	if bool(summary.get("passed", false)):
		print("WORLD1_GATE:PASS")
		quit(0)
		return
	print("WORLD1_GATE:FAIL (%d failures)" % int(summary.get("failure_count", 0)))
	quit(1)

func _check_level(path: String) -> void:
	var data: LevelData = LevelData.load_from_file(path)
	if data == null:
		_fail(path, "level_failed_to_load")
		return
	var level_result := {
		"path": path,
		"level_id": data.level_id,
		"segments": data.segments.size(),
		"entities": 0,
		"pickups": 0,
		"enemies": 0,
		"goals": 0,
		"checkpoints": 0,
		"pass": true,
		"issues": [],
	}
	if data.level_id == "":
		level_result["pass"] = false
		var issues_a: Array = level_result["issues"]
		issues_a.append("missing_level_id")
		level_result["issues"] = issues_a
	if not data.segments.has(data.start_segment):
		level_result["pass"] = false
		var issues_b: Array = level_result["issues"]
		issues_b.append("missing_start_segment")
		level_result["issues"] = issues_b

	for seg_id in data.segments.keys():
		var segment: LevelData.SegmentData = data.segments[seg_id]
		level_result["entities"] = int(level_result["entities"]) + segment.entities.size()
		for entry in segment.entities:
			if entry.type == "pickup":
				level_result["pickups"] = int(level_result["pickups"]) + 1
			if entry.type.begins_with("enemy") or entry.type.begins_with("boss"):
				level_result["enemies"] = int(level_result["enemies"]) + 1
			if entry.type == "goal":
				level_result["goals"] = int(level_result["goals"]) + 1
			if entry.type == "checkpoint":
				level_result["checkpoints"] = int(level_result["checkpoints"]) + 1
	if data.level > 0 and int(level_result["goals"]) == 0:
		level_result["pass"] = false
		var issues_c: Array = level_result["issues"]
		issues_c.append("missing_goal")
		level_result["issues"] = issues_c
	if data.level == 0 and int(level_result["enemies"]) == 0:
		level_result["pass"] = false
		var issues_d: Array = level_result["issues"]
		issues_d.append("missing_boss_or_enemy")
		level_result["issues"] = issues_d
	if int(level_result["entities"]) > 64:
		level_result["pass"] = false
		var issues_e: Array = level_result["issues"]
		issues_e.append("entity_density_over_budget")
		level_result["issues"] = issues_e

	_report["levels"].append(level_result)
	if not bool(level_result["pass"]):
		for issue in level_result["issues"]:
			_fail(path, str(issue))

func _fail(path: String, issue: String) -> void:
	var summary: Dictionary = _report["summary"]
	summary["passed"] = false
	var failures: Array = summary.get("failures", [])
	failures.append({"path": path, "issue": issue})
	summary["failures"] = failures
	summary["failure_count"] = failures.size()
	_report["summary"] = summary

func _write_report() -> void:
	var file := FileAccess.open("user://world1_gate_report.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
