extends Node
## Headless UI smoke test (run as a scene): plays a few moves through the Game scene.

func _ready() -> void:
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var gs = get_node('/root/GameSettings')
	gs.mode = 1
	gs.difficulty = 0
	gs.human_color = Piece.BLACK
	main.start_game()
	for i in 100:
		await get_tree().process_frame
	var g = main._current
	print("game after bot's first move: ", g.board.to_fen(), " san=", g.san_history)
	# human plays e7e5 via view signal (tap path)
	g._on_move_requested(Piece.sq_from_name("e7"), Piece.sq_from_name("e5"), false)
	for i in 100:
		await get_tree().process_frame
	print("after human+bot: ", g.san_history)
	g._on_undo()
	print("after undo: ", g.san_history, " thinking=", g.thinking)
	for i in 60:
		await get_tree().process_frame
	# switch to pvp, promotion path
	gs.mode = 0
	main.start_game()
	await get_tree().process_frame
	await get_tree().process_frame
	g = main._current
	g.board = BoardState.from_fen("8/P6k/8/8/8/8/8/K7 w - - 0 1")
	g._refresh(-1, -1)
	g._on_move_requested(Piece.sq_from_name("a7"), Piece.sq_from_name("a8"), false)
	await get_tree().process_frame
	print("promo visible: ", g.promo.visible)
	g.promo.chosen.emit(Piece.KNIGHT)
	await get_tree().process_frame
	print("after promo: ", g.board.to_fen(), g.san_history)
	main.show_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	print("SMOKE DONE")
	get_tree().quit(0)
