extends Control

signal start_requested

var _bot_options: VBoxContainer
var _diff_buttons: Array[Button] = []
var _color_buttons: Array[Button] = []

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var logo := TextureRect.new()
	logo.texture = preload("res://icon.svg")
	logo.custom_minimum_size = Vector2(104, 104)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(logo)

	var title := Label.new()
	title.text = "Chess"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	box.add_child(title)

	var pvp := UITheme.button("1 vs 1 (Local)")
	pvp.pressed.connect(_on_pvp)
	box.add_child(pvp)
	var pvb := UITheme.button("1 vs Bot")
	pvb.pressed.connect(func(): _bot_options.visible = true)
	box.add_child(pvb)

	_bot_options = VBoxContainer.new()
	_bot_options.add_theme_constant_override("separation", 12)
	_bot_options.visible = false
	box.add_child(_bot_options)

	_bot_options.add_child(_heading("Difficulty"))
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 8)
	_bot_options.add_child(dh)
	var g1 := ButtonGroup.new()
	for i in 3:
		var b := UITheme.button(["Easy", "Medium", "Hard"][i], true)
		b.button_group = g1
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = (i == GameSettings.difficulty)
		dh.add_child(b)
		_diff_buttons.append(b)

	_bot_options.add_child(_heading("Play as"))
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	_bot_options.add_child(ch)
	var g2 := ButtonGroup.new()
	for i in 3:
		var b2 := UITheme.button(["White", "Black", "Random"][i], true)
		b2.button_group = g2
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.button_pressed = (i == 0)
		ch.add_child(b2)
		_color_buttons.append(b2)

	var start := UITheme.button("Start")
	start.pressed.connect(_on_start_bot)
	_bot_options.add_child(start)

func _heading(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _on_pvp() -> void:
	GameSettings.mode = GameSettings.Mode.PVP
	start_requested.emit()

func _on_start_bot() -> void:
	GameSettings.mode = GameSettings.Mode.PVB
	for i in 3:
		if _diff_buttons[i].button_pressed:
			GameSettings.difficulty = i
	var c := 0
	for i in 3:
		if _color_buttons[i].button_pressed:
			c = i
	match c:
		0: GameSettings.human_color = Piece.WHITE
		1: GameSettings.human_color = Piece.BLACK
		_: GameSettings.human_color = Piece.WHITE if randi() % 2 == 0 else Piece.BLACK
	start_requested.emit()
