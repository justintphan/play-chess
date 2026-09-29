extends Control
## Root: owns the theme and swaps between Menu and Game.

const MENU_SCENE := preload("res://scenes/Menu.tscn")
const GAME_SCENE := preload("res://scenes/Game.tscn")

var _current: Control

func _ready() -> void:
	theme = UITheme.make()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	show_menu()

func _swap(scene: PackedScene) -> Control:
	if _current != null:
		if _current.has_method("shutdown"):
			_current.shutdown()
		else:
			_current.queue_free()
	_current = scene.instantiate()
	add_child(_current)
	_current.set_anchors_preset(Control.PRESET_FULL_RECT)
	return _current

func show_menu() -> void:
	var m := _swap(MENU_SCENE)
	m.start_requested.connect(start_game)

func start_game() -> void:
	var g := _swap(GAME_SCENE)
	g.menu_requested.connect(show_menu)
