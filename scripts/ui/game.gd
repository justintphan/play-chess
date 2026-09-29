extends Control
## Game screen: owns the authoritative BoardState, the bot, and the side panel.

signal menu_requested

const PROMO_SCENE := preload("res://scenes/PromotionDialog.tscn")
const MAX_BOARD := 900.0
const MARGIN := 16.0
const GAP := 16.0

var board: BoardState
var bot: ChessBot
var san_history: Array[String] = []
var game_id: int = 0
var thinking := false
var game_over := false
var _shutting_down := false
var _restart_pending := false

var view: BoardView
var panel: PanelContainer
var panel_box: BoxContainer
var mode_label: Label
var turn_label: Label
var status_label: Label
var move_list: RichTextLabel
var btn_grid: GridContainer
var undo_btn: Button
var overlay: Panel
var overlay_label: Label
var promo: Control

func _ready() -> void:
	view = BoardView.new()
	view.targets_provider = _targets_for
	view.move_requested.connect(_on_move_requested)
	add_child(view)

	panel = PanelContainer.new()
	add_child(panel)
	panel_box = BoxContainer.new()
	panel_box.add_theme_constant_override("separation", 12)
	panel.add_child(panel_box)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_child(info)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 22)
	mode_label.modulate = Color(1, 1, 1, 0.65)
	info.add_child(mode_label)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 30)
	turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(turn_label)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("ff8a70"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(status_label)

	move_list = RichTextLabel.new()
	move_list.scroll_following = true
	move_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	move_list.custom_minimum_size = Vector2(120, 90)
	move_list.focus_mode = Control.FOCUS_NONE
	move_list.mouse_filter = Control.MOUSE_FILTER_STOP
	# RichTextLabel only scrolls by wheel or its thin scrollbar; add drag-to-scroll
	# (touch arrives as emulated mouse drags) and a scrollbar wide enough to grab.
	move_list.gui_input.connect(_on_move_list_input)
	move_list.get_v_scroll_bar().custom_minimum_size.x = 14
	panel_box.add_child(move_list)

	btn_grid = GridContainer.new()
	btn_grid.columns = 2
	btn_grid.add_theme_constant_override("h_separation", 8)
	btn_grid.add_theme_constant_override("v_separation", 8)
	btn_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_child(btn_grid)
	undo_btn = _mk_btn("Undo", _on_undo)
	_mk_btn("Restart", _new_game)
	_mk_btn("Flip", func(): view.flip())
	_mk_btn("Menu", _on_menu)

	overlay = Panel.new()
	overlay.visible = false
	add_child(overlay)
	var ov := VBoxContainer.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.offset_left = 20
	ov.offset_right = -20
	ov.offset_top = 20
	ov.offset_bottom = -20
	ov.add_theme_constant_override("separation", 14)
	overlay.add_child(ov)
	overlay_label = Label.new()
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_label.add_theme_font_size_override("font_size", 34)
	ov.add_child(overlay_label)
	var oh := HBoxContainer.new()
	oh.add_theme_constant_override("separation", 10)
	ov.add_child(oh)
	var again := UITheme.button("Play again")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_new_game)
	oh.add_child(again)
	var menu := UITheme.button("Menu")
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(_on_menu)
	oh.add_child(menu)

	promo = PROMO_SCENE.instantiate()
	add_child(promo)

	resized.connect(_on_resized)
	# The panel's size is clamped to its minimum size, which is only final once
	# its containers and wrapped labels have been sorted; re-layout whenever it
	# changes (e.g. first game after page load) instead of relying on timing.
	panel.minimum_size_changed.connect(_on_resized, CONNECT_DEFERRED)
	_new_game()
	_on_resized()
	# Switching panel_box orientation changes the panel's minimum size only after
	# the containers re-sort, so the first pass can leave the panel clamped to the
	# old (horizontal) minimum and overflowing the screen. Lay out again next frame.
	await get_tree().process_frame
	if is_inside_tree():
		_on_resized()

func _mk_btn(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	btn_grid.add_child(b)
	return b

# ---------------------------------------------------------------- layout

func _on_resized() -> void:
	if view == null:
		return
	var w := size.x - MARGIN * 2.0
	var h := size.y - MARGIN * 2.0
	if size.x / maxf(size.y, 1.0) < 1.0:
		# portrait: board on top, panel strip below
		panel_box.vertical = false
		var bs := minf(minf(w, MAX_BOARD), h - GAP - 230.0)
		bs = maxf(bs, 200.0)
		var ph := minf(h - bs - GAP, 300.0)
		ph = maxf(ph, 150.0)
		var total_h := bs + GAP + ph
		var x0 := (size.x - bs) / 2.0
		var y0 := maxf((size.y - total_h) / 2.0, MARGIN)
		view.position = Vector2(x0, y0)
		view.size = Vector2(bs, bs)
		panel.position = Vector2(x0, y0 + bs + GAP)
		panel.size = Vector2(bs, ph)
		btn_grid.custom_minimum_size = Vector2(minf(bs * 0.36, 300.0), 0)
		move_list.custom_minimum_size = Vector2(120, 80)
	else:
		panel_box.vertical = true
		var pw := clampf(w * 0.3, 300.0, 360.0)
		var bs2 := minf(minf(h, w - pw - GAP), MAX_BOARD)
		bs2 = maxf(bs2, 200.0)
		var total_w := bs2 + GAP + pw
		var x1 := (size.x - total_w) / 2.0
		var y1 := (size.y - bs2) / 2.0
		view.position = Vector2(x1, y1)
		view.size = Vector2(bs2, bs2)
		panel.position = Vector2(x1 + bs2 + GAP, y1)
		panel.size = Vector2(pw, bs2)
		btn_grid.custom_minimum_size = Vector2(0, 0)
		move_list.custom_minimum_size = Vector2(120, 120)
	# game-over card is centred on the board so it never covers the side panel
	var ow := minf(440.0, view.size.x - 32.0)
	overlay.size = Vector2(ow, 240)
	overlay.position = view.position + (view.size - overlay.size) / 2.0

# ---------------------------------------------------------------- game flow

func _is_pvb() -> bool:
	return GameSettings.mode == GameSettings.Mode.PVB

func _human_color() -> int:
	return GameSettings.human_color

func _new_game() -> void:
	game_id += 1
	if bot != null:
		bot.cancel()
	bot = ChessBot.new()
	board = BoardState.start_position()
	san_history.clear()
	thinking = false
	game_over = false
	overlay.visible = false
	view.clear_selection()
	view.flipped = _is_pvb() and _human_color() == Piece.BLACK
	_refresh(-1, -1)
	if _is_pvb() and board.side_to_move != _human_color():
		_bot_turn()

func _targets_for(sq: int) -> Array:
	var res := []
	for m in board.legal_moves_from(sq):
		if not (m.to in res):
			res.append(m.to)
	return res

func _can_human_move() -> bool:
	if game_over or thinking:
		return false
	if _is_pvb() and board.side_to_move != _human_color():
		return false
	return true

func _on_move_requested(from: int, to: int, dragged: bool) -> void:
	if not _can_human_move():
		return
	var gid := game_id
	var cands: Array[Move] = []
	for m in board.legal_moves_from(from):
		if m.to == to:
			cands.append(m)
	if cands.is_empty():
		return
	var chosen: Move = cands[0]
	if cands.size() > 1:
		view.movable_color = 0
		var t: int = await promo.ask(board.side_to_move, view.cell())
		if gid != game_id or _shutting_down:
			return
		if t == 0:
			_update_input()
			return
		for m in cands:
			if m.promotion == t:
				chosen = m
	_apply_move(chosen, not dragged)

func _apply_move(m: Move, animate: bool) -> void:
	san_history.append(Notation.to_san(board, m))
	board.make_move(m)
	view.clear_selection()
	_refresh(m.from, m.to)
	if animate:
		view.animate_move(m.from, m.to, m.piece)
	if not game_over and _is_pvb() and board.side_to_move != _human_color():
		_bot_turn()

func _bot_turn() -> void:
	var gid := game_id
	var my_bot := bot
	thinking = true
	_update_input()
	_update_labels()
	var t0 := Time.get_ticks_msec()
	var m: Move = await my_bot.think(board.copy(), GameSettings.difficulty, get_tree())
	var el := Time.get_ticks_msec() - t0
	if el < 400 and gid == game_id and not _shutting_down:
		await get_tree().create_timer((400 - el) / 1000.0).timeout
	if gid != game_id or _shutting_down:
		if _shutting_down and gid == game_id:
			queue_free()
		return
	thinking = false
	if m == null:
		_refresh(-1, -1)
		return
	_apply_move(m, true)

func _on_undo() -> void:
	if thinking or board.undo_stack.is_empty():
		return
	game_id += 1  # cancel anything in flight
	var n := 0
	while not board.undo_stack.is_empty() and (n == 0 or (_is_pvb() and board.side_to_move != _human_color())):
		board.unmake_move()
		if not san_history.is_empty():
			san_history.pop_back()
		n += 1
		if not _is_pvb():
			break
	game_over = false
	overlay.visible = false
	view.clear_selection()
	var lf := -1
	var lt := -1
	if not board.undo_stack.is_empty():
		var lm: Move = board.undo_stack.back()[0]
		lf = lm.from
		lt = lm.to
	_refresh(lf, lt)
	if _is_pvb() and board.side_to_move != _human_color():
		_bot_turn()

func _on_menu() -> void:
	menu_requested.emit()

## Called by Main before swapping screens. Frees itself once any bot search has wound down.
func shutdown() -> void:
	_shutting_down = true
	game_id += 1
	if bot != null:
		bot.cancel()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if thinking:
		game_id -= 1  # let _bot_turn see "shutting down" and free us
		return
	queue_free()

# ---------------------------------------------------------------- UI refresh

func _update_input() -> void:
	view.movable_color = board.side_to_move if _can_human_move() else 0
	undo_btn.disabled = thinking or board.undo_stack.is_empty()

func _check_square() -> int:
	if board.in_check():
		return board.king_sq[0 if board.side_to_move == Piece.WHITE else 1]
	return -1

func _refresh(lf: int, lt: int) -> void:
	view.set_position_state(board.squares, lf, lt, _check_square())
	var st := board.get_status()
	game_over = st != BoardState.Status.ONGOING
	_update_input()
	_update_labels()
	_update_move_list()
	if game_over:
		overlay_label.text = _result_text(st)
		overlay.visible = true
	else:
		overlay.visible = false

func _side_name(c: int) -> String:
	return "White" if c == Piece.WHITE else "Black"

func _result_text(st: int) -> String:
	match st:
		BoardState.Status.CHECKMATE:
			return "Checkmate\n%s wins" % _side_name(Piece.opposite(board.side_to_move))
		BoardState.Status.STALEMATE:
			return "Draw by stalemate"
		BoardState.Status.DRAW_50:
			return "Draw by 50-move rule"
		BoardState.Status.DRAW_REPETITION:
			return "Draw by repetition"
		BoardState.Status.DRAW_MATERIAL:
			return "Draw: insufficient material"
	return ""

func _update_labels() -> void:
	if _is_pvb():
		mode_label.text = "1 vs Bot - %s" % ["Easy", "Medium", "Hard"][GameSettings.difficulty]
	else:
		mode_label.text = "1 vs 1 (Local)"
	var st := board.get_status()
	if game_over:
		turn_label.text = "Game over"
		status_label.text = _result_text(st).replace("\n", " - ")
		return
	if thinking:
		turn_label.text = "Bot is thinking..."
	elif _is_pvb():
		turn_label.text = "Your move (%s)" % _side_name(board.side_to_move)
	else:
		turn_label.text = "%s to move" % _side_name(board.side_to_move)
	status_label.text = "Check!" if board.in_check() else ""

func _on_move_list_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var sb := move_list.get_v_scroll_bar()
		sb.value = clampf(sb.value - e.relative.y, sb.min_value, sb.max_value)
		# keep auto-following new moves only while the list is at the bottom
		move_list.scroll_following = sb.value >= sb.max_value - sb.page - 1.0
		move_list.accept_event()
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var sb2 := move_list.get_v_scroll_bar()
		move_list.scroll_following = e.button_index == MOUSE_BUTTON_WHEEL_DOWN and sb2.value >= sb2.max_value - sb2.page - 40.0

func _update_move_list() -> void:
	var s := ""
	for i in san_history.size():
		if i % 2 == 0:
			s += "%d. " % (i / 2 + 1)
		s += san_history[i]
		s += "  " if i % 2 == 0 else "\n"
	if san_history.is_empty():
		move_list.scroll_following = true
	# re-setting text resets the scroll; keep the user's place if they scrolled up
	var sb := move_list.get_v_scroll_bar()
	var keep := not move_list.scroll_following
	var v := sb.value
	move_list.text = s
	if keep:
		sb.set_deferred("value", v)
