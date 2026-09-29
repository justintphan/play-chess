extends RefCounted

var fails := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("ok   ", name)
	else:
		fails += 1
		print("FAIL ", name, " ", detail)

func play(b: BoardState, uci_list: Array) -> void:
	for u in uci_list:
		var from := Piece.sq_from_name(u.substr(0, 2))
		var to := Piece.sq_from_name(u.substr(2, 2))
		var promo := 0
		if u.length() > 4:
			promo = "?pnbrqk".find(u[4])
		var m := b.find_legal(from, to, promo)
		if m == null:
			fails += 1
			print("FAIL illegal move in test: ", u, " fen ", b.to_fen())
			return
		b.make_move(m)

func san_seq(fen: String, ucis: Array) -> Array:
	var b := BoardState.from_fen(fen)
	var out := []
	for u in ucis:
		var m := b.find_legal(Piece.sq_from_name(u.substr(0, 2)), Piece.sq_from_name(u.substr(2, 2)), "?pnbrqk".find(u[4]) if u.length() > 4 else 0)
		out.append(Notation.to_san(b, m))
		b.make_move(m)
	return out

func run() -> int:
	var b := BoardState.start_position()
	check("fen roundtrip start", b.to_fen() == BoardState.START_FEN, b.to_fen())
	var f2 := "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
	check("fen roundtrip kiwipete", BoardState.from_fen(f2).to_fen() == f2)
	# scholar's mate
	b = BoardState.start_position()
	play(b, ["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"])
	check("scholar mate", b.get_status() == BoardState.Status.CHECKMATE)
	check("scholar SAN", san_seq(BoardState.START_FEN, ["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"]) == ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"])
	check("stalemate", BoardState.from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1").get_status() == BoardState.Status.STALEMATE)
	check("K v K", BoardState.from_fen("8/8/4k3/8/8/3K4/8/8 w - - 0 1").get_status() == BoardState.Status.DRAW_MATERIAL)
	check("KB v K", BoardState.from_fen("8/8/4k3/8/8/3KB3/8/8 w - - 0 1").get_status() == BoardState.Status.DRAW_MATERIAL)
	check("KBvKB same", BoardState.from_fen("8/8/4kb2/8/8/3KB3/8/8 w - - 0 1").get_status() == BoardState.Status.DRAW_MATERIAL)
	check("KBvKB diff", BoardState.from_fen("8/8/4kb2/8/8/3K1B2/8/8 w - - 0 1").get_status() == BoardState.Status.ONGOING)
	check("KR v K not draw", BoardState.from_fen("8/8/4k3/8/8/3KR3/8/8 w - - 0 1").get_status() == BoardState.Status.ONGOING)
	check("50-move", BoardState.from_fen("8/8/4k3/8/8/3KR3/8/8 w - - 100 80").get_status() == BoardState.Status.DRAW_50)
	b = BoardState.start_position()
	var cyc := ["g1f3", "g8f6", "f3g1", "f6g8"]
	play(b, cyc)
	check("no rep after 2", b.get_status() == BoardState.Status.ONGOING)
	play(b, cyc)
	check("draw repetition", b.get_status() == BoardState.Status.DRAW_REPETITION)
	# unmake restores key/fen
	b = BoardState.from_fen(f2)
	var k := b.zobrist_key
	for m in b.generate_legal():
		b.make_move(m)
		b.unmake_move()
	check("make/unmake restores", b.zobrist_key == k and b.to_fen() == f2)
	# incremental key equals recomputed
	b = BoardState.start_position()
	play(b, ["e2e4", "d7d5", "e4e5", "f7f5", "e5f6", "g8f6", "f1e2", "e7e6", "g1f3", "f8e7", "e1g1"])
	check("zobrist incremental", b.zobrist_key == BoardState.from_fen(b.to_fen()).zobrist_key)
	# SAN
	var sc := san_seq("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", ["e1g1", "e8c8"])
	check("SAN O-O / O-O-O", sc[0] == "O-O" and sc[1].begins_with("O-O-O"), str(sc))
	check("SAN promotion", san_seq("8/P6k/8/8/8/8/8/K7 w - - 0 1", ["a7a8q"]) == ["a8=Q"])
	check("SAN promo check", san_seq("7k/P7/8/8/8/8/8/K7 w - - 0 1", ["a7a8q"]) == ["a8=Q+"])
	check("SAN Nbd2", san_seq("4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1", ["b1d2"]) == ["Nbd2"])
	check("SAN R1e2 real", san_seq("7k/8/8/8/4R3/8/8/4R1K1 w - - 0 1", ["e1e2"]) == ["R1e2"], str(san_seq("7k/8/8/8/4R3/8/8/4R1K1 w - - 0 1", ["e1e2"])))
	check("SAN pawn capture", san_seq(BoardState.START_FEN, ["e2e4", "d7d5", "e4d5"])[2] == "exd5")
	# en passant
	b = BoardState.start_position()
	play(b, ["e2e4", "a7a6", "e4e5", "d7d5", "e5d6"])
	check("en passant", b.squares[Piece.sq_from_name("d5")] == 0 and b.squares[Piece.sq_from_name("d6")] == (Piece.PAWN | Piece.WHITE))
	print("rules failures: ", fails)
	return fails
