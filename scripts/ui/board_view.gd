class_name BoardView
extends Control
## Draws the board and handles tap / drag input. Holds no rules logic:
## Game feeds it the position and a Callable that returns legal targets.

signal move_requested(from: int, to: int, dragged: bool)

const LIGHT := Color("eeeed2")
const DARK := Color("769656")
const SELECTED := Color(0.96, 0.96, 0.4, 0.75)
const LAST_MOVE := Color(0.73, 0.79, 0.27, 0.55)
const LETTERS := ["", "P", "N", "B", "R", "Q", "K"]

var squares: PackedInt32Array = PackedInt32Array()
var flipped: bool = false
var last_from: int = -1
var last_to: int = -1
var check_sq: int = -1
## Color the local user may move right now (0 = nobody, input ignored).
var movable_color: int = 0
var targets_provider: Callable = Callable()

var selected: int = -1
var targets: Array[int] = []
var _drag_sq: int = -1
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_pos := Vector2.ZERO
var _textures: Dictionary = {}

var anim_t: float = 1.0:
	set(v):
		anim_t = v
		queue_redraw()
var _anim_from := -1
var _anim_to := -1
var _anim_piece := 0
var _tween: Tween

func _ready() -> void:
	squares.resize(64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for color in ["w", "b"]:
		for t in range(1, 7):
			var p := (t | (Piece.WHITE if color == "w" else Piece.BLACK))
			_textures[p] = load("res://assets/pieces/%s%s.svg" % [color, LETTERS[t]])
	resized.connect(queue_redraw)

func cell() -> float:
	return minf(size.x, size.y) / 8.0

func set_position_state(sq_arr: PackedInt32Array, from: int, to: int, chk: int) -> void:
	squares = sq_arr.duplicate()
	last_from = from
	last_to = to
	check_sq = chk
	queue_redraw()

func clear_selection() -> void:
	selected = -1
	targets = []
	_drag_sq = -1
	_dragging = false
	queue_redraw()

func animate_move(from: int, to: int, piece: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_anim_from = from
	_anim_to = to
	_anim_piece = piece
	anim_t = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "anim_t", 1.0, 0.14)
	_tween.finished.connect(func():
		_anim_to = -1
		queue_redraw())

func flip() -> void:
	flipped = not flipped
	queue_redraw()

# --------------------------------------------------------------- coordinates

func _sq_to_pos(sq: int) -> Vector2:
	var c := cell()
	var f := sq & 7
	var r := sq >> 3
	if flipped:
		f = 7 - f
		r = 7 - r
	return Vector2(f * c, r * c)

func _pos_to_sq(p: Vector2) -> int:
	var c := cell()
	var f := int(floor(p.x / c))
	var r := int(floor(p.y / c))
	if f < 0 or f > 7 or r < 0 or r > 7:
		return -1
	if flipped:
		f = 7 - f
		r = 7 - r
	return r * 8 + f

# --------------------------------------------------------------- drawing

func _draw() -> void:
	var c := cell()
	var font := ThemeDB.fallback_font
	var fs := int(maxf(c * 0.2, 10.0))
	for sq in 64:
		var pos := _sq_to_pos(sq)
		var light := (((sq >> 3) + (sq & 7)) & 1) == 0
		var col := LIGHT if light else DARK
		draw_rect(Rect2(pos, Vector2(c, c)), col)
		if sq == last_from or sq == last_to:
			draw_rect(Rect2(pos, Vector2(c, c)), LAST_MOVE)
		if sq == selected:
			draw_rect(Rect2(pos, Vector2(c, c)), SELECTED)
		if sq == check_sq:
			var ctr := pos + Vector2(c, c) * 0.5
			for i in 6:
				var k := float(i) / 6.0
				draw_circle(ctr, c * 0.5 * (1.0 - k), Color(1.0, 0.15, 0.15, 0.16))
		# coordinate labels
		var txt_col := DARK if light else LIGHT
		var screen_col := (7 - (sq & 7)) if flipped else (sq & 7)
		var screen_row := (7 - (sq >> 3)) if flipped else (sq >> 3)
		if screen_row == 7:
			var fl: String = "abcdefgh"[sq & 7]
			draw_string(font, pos + Vector2(c - fs * 0.75, c - fs * 0.3), fl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)
		if screen_col == 0:
			var rk := str(8 - (sq >> 3))
			draw_string(font, pos + Vector2(c * 0.05, fs * 1.0), rk, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)
	# pieces
	for sq in 64:
		var p := squares[sq]
		if p == 0:
			continue
		if _dragging and sq == _drag_sq:
			continue
		if _anim_to >= 0 and sq == _anim_to and anim_t < 1.0:
			continue
		draw_texture_rect(_textures[p], Rect2(_sq_to_pos(sq), Vector2(c, c)), false)
	# legal-move markers
	for t in targets:
		var ctr2 := _sq_to_pos(t) + Vector2(c, c) * 0.5
		if squares[t] != 0 or (selected >= 0 and (squares[selected] & 7) == Piece.PAWN and (t & 7) != (selected & 7)):
			draw_arc(ctr2, c * 0.44, 0, TAU, 40, Color(0, 0, 0, 0.28), c * 0.09, true)
		else:
			draw_circle(ctr2, c * 0.15, Color(0, 0, 0, 0.26))
	# animated piece
	if _anim_to >= 0 and anim_t < 1.0:
		var e := ease(anim_t, -2.0)
		var pp := _sq_to_pos(_anim_from).lerp(_sq_to_pos(_anim_to), e)
		draw_texture_rect(_textures[_anim_piece], Rect2(pp, Vector2(c, c)), false)
	# dragged piece: larger and lifted above the finger
	if _dragging and _drag_sq >= 0:
		var big := c * 1.3
		var r := Rect2(_drag_pos - Vector2(big * 0.5, big * 0.5 + c * 0.35), Vector2(big, big))
		draw_texture_rect(_textures[squares[_drag_sq]], r, false)

# --------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion and _drag_sq >= 0:
		if not _dragging and event.position.distance_to(_drag_start) > 4.0:
			_dragging = true
		if _dragging:
			_drag_pos = event.position
			queue_redraw()

func _own_piece(sq: int) -> bool:
	return sq >= 0 and squares[sq] != 0 and Piece.color_of(squares[sq]) == movable_color

func _on_press(pos: Vector2) -> void:
	if movable_color == 0:
		return
	var sq := _pos_to_sq(pos)
	if sq < 0:
		return
	if selected >= 0 and sq in targets:
		var from := selected
		clear_selection()
		move_requested.emit(from, sq, false)
		return
	if _own_piece(sq):
		selected = sq
		targets = []
		if targets_provider.is_valid():
			for t in targets_provider.call(sq):
				targets.append(t)
		_drag_sq = sq
		_dragging = false
		_drag_start = pos
		_drag_pos = pos
	else:
		clear_selection()
	queue_redraw()

func _on_release(pos: Vector2) -> void:
	if _dragging:
		var sq := _pos_to_sq(pos)
		var from := _drag_sq
		_dragging = false
		_drag_sq = -1
		if sq >= 0 and sq in targets and from >= 0:
			clear_selection()
			move_requested.emit(from, sq, true)
			return
	_drag_sq = -1
	queue_redraw()
