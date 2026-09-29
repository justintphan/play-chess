extends RefCounted

const CASES := [
	["start", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", [20, 400, 8902, 197281]],
	["kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", [48, 2039, 97862]],
	["pos3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", [14, 191, 2812, 43238]],
	["pos4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", [6, 264, 9467]],
	["pos5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", [44, 1486, 62379]],
]

func run() -> int:
	var fails := 0
	for c in CASES:
		var b := BoardState.from_fen(c[1])
		for i in c[2].size():
			var t := Time.get_ticks_msec()
			var got := b.perft(i + 1)
			var ok: bool = got == c[2][i]
			if not ok:
				fails += 1
			print("perft %s d%d: got %d expected %d %s (%d ms)" % [c[0], i + 1, got, c[2][i], "OK" if ok else "FAIL", Time.get_ticks_msec() - t])
	return fails
