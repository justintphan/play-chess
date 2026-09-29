extends RefCounted

var fails := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("ok   ", name, " ", detail)
	else:
		fails += 1
		print("FAIL ", name, " ", detail)

const POSITIONS := [
	"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
	"rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
	"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
	"8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
	"r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
	"rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
	"8/8/4k3/8/8/3KR3/8/8 b - - 0 1",
	"r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 4 4",
	"4k3/P7/8/8/8/8/7p/4K3 w - - 0 1",
	"rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3",
]

func is_legal(b: BoardState, m: Move) -> bool:
	return m != null and b.find_legal(m.from, m.to, m.promotion) != null

func run(tree: SceneTree) -> int:
	var bot := ChessBot.new()
	var names := ["Easy", "Medium", "Hard"]
	for lvl in 3:
		var ok := true
		var maxms := 0
		for fen in POSITIONS:
			var b := BoardState.from_fen(fen)
			var t := Time.get_ticks_msec()
			var m: Move = await bot.think(b, lvl, tree)
			maxms = maxi(maxms, Time.get_ticks_msec() - t)
			if not is_legal(b, m):
				ok = false
				print("  illegal: ", fen, " ", m.uci() if m else "null")
		check("legal moves " + names[lvl], ok, "(max %d ms)" % maxms)
	# mate in 1
	var mate1 := "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1"
	for lvl in [1, 2]:
		var b := BoardState.from_fen(mate1)
		var m: Move = await bot.think(b, lvl, tree)
		check("mate-in-1 " + names[lvl], m != null and m.uci() == "a1a8", m.uci() if m else "null")
	# mate in 2 (Hard): every black reply must allow an immediate mate
	var mate2 := "7k/8/8/8/8/8/8/RR2K3 w - - 0 1"
	var b2 := BoardState.from_fen(mate2)
	var m2: Move = await bot.think(b2, 2, tree)
	b2.make_move(m2)
	var forced := true
	for r in b2.generate_legal():
		b2.make_move(r)
		var found := false
		for w in b2.generate_legal():
			b2.make_move(w)
			if b2.get_status() == BoardState.Status.CHECKMATE:
				found = true
			b2.unmake_move()
			if found:
				break
		b2.unmake_move()
		if not found:
			forced = false
	check("mate-in-2 Hard", forced, m2.uci())
	# queen attacked by pawn: Hard must move the queen
	var b3 := BoardState.from_fen("4k3/8/8/3p4/4Q3/8/8/4K3 w - - 0 1")
	var m3: Move = await bot.think(b3, 2, tree)
	check("Hard saves queen", (m3.piece & 7) == Piece.QUEEN, m3.uci())
	# regression: in a real game (TT carried between moves) Hard used to hang its
	# queen with 12.Bd5?? here instead of taking Black's queen with 12.Qxd8
	var line := "e4 e5 Nf3 Nc6 Nc3 Nf6 d4 exd4 Nxd4 Bb4 Qd3 Bxc3+ Qxc3 Nxd4 Qxd4 O-O e5 Ne8 Bc4 d6 Bf4 dxe5".split(" ")
	var gb := BoardState.start_position()
	var gbot := ChessBot.new()
	var replay_ok := true
	for san in line:
		if gb.side_to_move == Piece.WHITE:
			await gbot.think(gb, 2, tree)  # warm the TT exactly like a game does
		var pm: Move = null
		for lm in gb.generate_legal():
			if Notation.to_san(gb, lm) == san:
				pm = lm
		if pm == null:
			replay_ok = false
			break
		gb.make_move(pm)
	var m12: Move = await gbot.think(gb, 2, tree) if replay_ok else null
	var m12_san := Notation.to_san(gb, m12) if m12 else "null"
	check("Hard game replay takes queen", m12_san == "Qxd8", m12_san)
	# timing
	var worst := 0
	for fen in [POSITIONS[0], POSITIONS[2], POSITIONS[7], POSITIONS[5]]:
		var b := BoardState.from_fen(fen)
		var t := Time.get_ticks_msec()
		var m: Move = await bot.think(b, 2, tree)
		var dt := Time.get_ticks_msec() - t
		worst = maxi(worst, dt)
		print("  hard timing: %d ms, depth %d, nodes %d (%.0f nps)" % [dt, bot.last_depth, bot.nodes, bot.nodes * 1000.0 / maxf(dt, 1)])
	check("Hard within time cap", worst < 2500, "(worst %d ms)" % worst)
	# Hard (white) vs Easy (black), up to 60 plies
	var g := BoardState.start_position()
	var plies := 0
	var okgame := true
	while plies < 60 and g.get_status() == BoardState.Status.ONGOING:
		var lvl := 2 if g.side_to_move == Piece.WHITE else 0
		var m: Move = await bot.think(g, lvl, tree)
		if not is_legal(g, m):
			okgame = false
			break
		g.make_move(m)
		plies += 1
	check("bot-vs-bot game", okgame, "(%d plies, final %s)" % [plies, g.to_fen()])
	print("bot failures: ", fails)
	return fails
