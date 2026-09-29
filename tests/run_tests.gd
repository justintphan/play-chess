extends SceneTree

func _init() -> void:
	var fails := 0
	var which := OS.get_cmdline_user_args()
	var suites := {
		"perft": "res://tests/test_perft.gd",
		"rules": "res://tests/test_rules.gd",
		"bot": "res://tests/test_bot.gd",
	}
	for name in suites:
		if which.size() > 0 and not (name in which):
			continue
		if not FileAccess.file_exists(suites[name]):
			continue
		var s = load(suites[name]).new()
		fails += await s.run(self) if name == "bot" else s.run()
	print("TOTAL FAILURES: ", fails)
	quit(1 if fails > 0 else 0)
