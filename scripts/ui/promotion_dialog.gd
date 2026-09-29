extends Control
## Modal overlay to choose a promotion piece. `await ask(color, square_size)`.

signal chosen(piece_type: int)

var _row: HBoxContainer
const LETTER := ["", "P", "N", "B", "R", "Q", "K"]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			chosen.emit(0))
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	panel.add_child(_row)

func ask(color: int, square_size: float) -> int:
	for c in _row.get_children():
		c.queue_free()
	var side := maxf(square_size, 72.0)
	for t in [Piece.QUEEN, Piece.ROOK, Piece.BISHOP, Piece.KNIGHT]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(side, side)
		b.icon = load("res://assets/pieces/%s%s.svg" % ["w" if color == Piece.WHITE else "b", LETTER[t]])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.pressed.connect(func(): chosen.emit(t))
		_row.add_child(b)
	visible = true
	var r: int = await chosen
	visible = false
	return r
