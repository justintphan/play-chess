class_name BoardState
extends RefCounted
## Chess rules engine: FEN, move generation, make/unmake, game status.

enum Status { ONGOING, CHECKMATE, STALEMATE, DRAW_50, DRAW_REPETITION, DRAW_MATERIAL }

const WK := 1
const WQ := 2
const BK := 4
const BQ := 8
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

const KNIGHT_D := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const KING_D := [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]
const BISHOP_D := [[1, 1], [-1, 1], [-1, -1], [1, -1]]
const ROOK_D := [[1, 0], [0, 1], [-1, 0], [0, -1]]

static var _z_piece: PackedInt64Array
static var _z_castle: PackedInt64Array
static var _z_ep: PackedInt64Array
static var _z_side: int = 0
static var _z_ready := false
static var _castle_mask: PackedInt32Array

var squares: PackedInt32Array = PackedInt32Array()
var side_to_move: int = Piece.WHITE
var castling: int = 0
var ep_square: int = -1
var halfmove_clock: int = 0
var fullmove_number: int = 1
var king_sq: PackedInt32Array = PackedInt32Array([-1, -1])
var zobrist_key: int = 0
var history_keys: Array[int] = []
var undo_stack: Array = []

static func _init_zobrist() -> void:
	if _z_ready:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED1234
	_z_piece = PackedInt64Array()
	_z_piece.resize(12 * 64)
	for i in _z_piece.size():
		_z_piece[i] = (rng.randi() << 32) | rng.randi()
	_z_castle = PackedInt64Array()
	_z_castle.resize(16)
	for i in 16:
		_z_castle[i] = (rng.randi() << 32) | rng.randi()
	_z_ep = PackedInt64Array()
	_z_ep.resize(8)
	for i in 8:
		_z_ep[i] = (rng.randi() << 32) | rng.randi()
	_z_side = (rng.randi() << 32) | rng.randi()
	_castle_mask = PackedInt32Array()
	_castle_mask.resize(64)
	_castle_mask.fill(15)
	_castle_mask[Piece.sq_from_name("e1")] = 15 & ~(WK | WQ)
	_castle_mask[Piece.sq_from_name("a1")] = 15 & ~WQ
	_castle_mask[Piece.sq_from_name("h1")] = 15 & ~WK
	_castle_mask[Piece.sq_from_name("e8")] = 15 & ~(BK | BQ)
	_castle_mask[Piece.sq_from_name("a8")] = 15 & ~BQ
	_castle_mask[Piece.sq_from_name("h8")] = 15 & ~BK
	_z_ready = true

static func _zp(p: int, sq: int) -> int:
	var idx := (p & 7) - 1 + (6 if (p & 16) != 0 else 0)
	return _z_piece[idx * 64 + sq]

func _init() -> void:
	_init_zobrist()
	squares.resize(64)

static func start_position() -> BoardState:
	return from_fen(START_FEN)

static func from_fen(fen: String) -> BoardState:
	var b := BoardState.new()
	var parts := fen.strip_edges().split(" ", false)
	var rows := parts[0].split("/")
	for r in 8:
		var f := 0
		for ch in rows[r]:
			if ch >= "1" and ch <= "8":
				f += int(ch)
			else:
				var p := Piece.from_char(ch)
				b.squares[r * 8 + f] = p
				if Piece.type_of(p) == Piece.KING:
					b.king_sq[0 if Piece.is_white(p) else 1] = r * 8 + f
				f += 1
	b.side_to_move = Piece.BLACK if parts.size() > 1 and parts[1] == "b" else Piece.WHITE
	var c := parts[2] if parts.size() > 2 else "-"
	if "K" in c: b.castling |= WK
	if "Q" in c: b.castling |= WQ
	if "k" in c: b.castling |= BK
	if "q" in c: b.castling |= BQ
	b.ep_square = -1
	if parts.size() > 3 and parts[3] != "-":
		b.ep_square = Piece.sq_from_name(parts[3])
	b.halfmove_clock = int(parts[4]) if parts.size() > 4 else 0
	b.fullmove_number = int(parts[5]) if parts.size() > 5 else 1
	b.zobrist_key = b._compute_key()
	b.history_keys = [b.zobrist_key]
	return b

func _compute_key() -> int:
	var k := 0
	for sq in 64:
		var p := squares[sq]
		if p != 0:
			k ^= _zp(p, sq)
	k ^= _z_castle[castling]
	if ep_square >= 0:
		k ^= _z_ep[ep_square & 7]
	if side_to_move == Piece.BLACK:
		k ^= _z_side
	return k

func to_fen() -> String:
	var s := ""
	for r in 8:
		var empty := 0
		for f in 8:
			var p := squares[r * 8 + f]
			if p == 0:
				empty += 1
			else:
				if empty > 0:
					s += str(empty)
					empty = 0
				s += Piece.to_char(p)
		if empty > 0:
			s += str(empty)
		if r < 7:
			s += "/"
	var c := ""
	if castling & WK: c += "K"
	if castling & WQ: c += "Q"
	if castling & BK: c += "k"
	if castling & BQ: c += "q"
	if c == "": c = "-"
	var ep := "-" if ep_square < 0 else Piece.sq_name(ep_square)
	return "%s %s %s %s %d %d" % [s, "w" if side_to_move == Piece.WHITE else "b", c, ep, halfmove_clock, fullmove_number]

func copy() -> BoardState:
	var b := BoardState.new()
	b.squares = squares.duplicate()
	b.side_to_move = side_to_move
	b.castling = castling
	b.ep_square = ep_square
	b.halfmove_clock = halfmove_clock
	b.fullmove_number = fullmove_number
	b.king_sq = king_sq.duplicate()
	b.zobrist_key = zobrist_key
	b.history_keys = history_keys.duplicate()
	# undo stack is intentionally not copied (search never unmakes past the copy point)
	return b

# ---------------------------------------------------------------- attacks

func is_square_attacked(sq: int, by: int) -> bool:
	var f := sq & 7
	var r := sq >> 3
	# pawns
	var pawn := Piece.PAWN | by
	var pr := r + 1 if by == Piece.WHITE else r - 1  # row where attacking pawn sits
	if pr >= 0 and pr < 8:
		if f > 0 and squares[pr * 8 + f - 1] == pawn:
			return true
		if f < 7 and squares[pr * 8 + f + 1] == pawn:
			return true
	# knights
	var knight := Piece.KNIGHT | by
	for d in KNIGHT_D:
		var nf: int = f + d[0]
		var nr: int = r + d[1]
		if nf >= 0 and nf < 8 and nr >= 0 and nr < 8 and squares[nr * 8 + nf] == knight:
			return true
	# king
	var king := Piece.KING | by
	for d in KING_D:
		var nf: int = f + d[0]
		var nr: int = r + d[1]
		if nf >= 0 and nf < 8 and nr >= 0 and nr < 8 and squares[nr * 8 + nf] == king:
			return true
	# sliders
	var bishop := Piece.BISHOP | by
	var rook := Piece.ROOK | by
	var queen := Piece.QUEEN | by
	for d in BISHOP_D:
		var nf: int = f + d[0]
		var nr: int = r + d[1]
		while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
			var p := squares[nr * 8 + nf]
			if p != 0:
				if p == bishop or p == queen:
					return true
				break
			nf += d[0]
			nr += d[1]
	for d in ROOK_D:
		var nf: int = f + d[0]
		var nr: int = r + d[1]
		while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
			var p := squares[nr * 8 + nf]
			if p != 0:
				if p == rook or p == queen:
					return true
				break
			nf += d[0]
			nr += d[1]
	return false

func in_check(color: int = -1) -> bool:
	if color < 0:
		color = side_to_move
	var ks := king_sq[0 if color == Piece.WHITE else 1]
	if ks < 0:
		return false
	return is_square_attacked(ks, Piece.opposite(color))

# ---------------------------------------------------------------- generation

func generate_pseudo_legal(captures_only: bool = false) -> Array[Move]:
	var moves: Array[Move] = []
	var us := side_to_move
	var them := Piece.opposite(us)
	for sq in 64:
		var p := squares[sq]
		if p == 0 or (p & 24) != us:
			continue
		var t := p & 7
		var f := sq & 7
		var r := sq >> 3
		match t:
			Piece.PAWN:
				_gen_pawn(moves, sq, p, f, r, us, captures_only)
			Piece.KNIGHT:
				for d in KNIGHT_D:
					_gen_step(moves, sq, p, f + d[0], r + d[1], us, captures_only)
			Piece.KING:
				for d in KING_D:
					_gen_step(moves, sq, p, f + d[0], r + d[1], us, captures_only)
				if not captures_only:
					_gen_castling(moves, sq, p, us, them)
			Piece.BISHOP:
				_gen_slide(moves, sq, p, f, r, us, BISHOP_D, captures_only)
			Piece.ROOK:
				_gen_slide(moves, sq, p, f, r, us, ROOK_D, captures_only)
			Piece.QUEEN:
				_gen_slide(moves, sq, p, f, r, us, BISHOP_D, captures_only)
				_gen_slide(moves, sq, p, f, r, us, ROOK_D, captures_only)
	return moves

func _gen_step(moves: Array[Move], sq: int, p: int, nf: int, nr: int, us: int, caps_only: bool) -> void:
	if nf < 0 or nf > 7 or nr < 0 or nr > 7:
		return
	var to := nr * 8 + nf
	var q := squares[to]
	if q == 0:
		if not caps_only:
			moves.append(Move.create(sq, to, p))
	elif (q & 24) != us:
		moves.append(Move.create(sq, to, p, q, 0, Move.CAPTURE))

func _gen_slide(moves: Array[Move], sq: int, p: int, f: int, r: int, us: int, dirs: Array, caps_only: bool) -> void:
	for d in dirs:
		var nf: int = f + d[0]
		var nr: int = r + d[1]
		while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
			var to := nr * 8 + nf
			var q := squares[to]
			if q == 0:
				if not caps_only:
					moves.append(Move.create(sq, to, p))
			else:
				if (q & 24) != us:
					moves.append(Move.create(sq, to, p, q, 0, Move.CAPTURE))
				break
			nf += d[0]
			nr += d[1]

func _add_pawn_move(moves: Array[Move], sq: int, to: int, p: int, cap: int, flags: int, promo_row: bool) -> void:
	if promo_row:
		for pt in [Piece.QUEEN, Piece.ROOK, Piece.BISHOP, Piece.KNIGHT]:
			moves.append(Move.create(sq, to, p, cap, pt, flags | Move.PROMOTION))
	else:
		moves.append(Move.create(sq, to, p, cap, 0, flags))

func _gen_pawn(moves: Array[Move], sq: int, p: int, f: int, r: int, us: int, caps_only: bool) -> void:
	var dr := -1 if us == Piece.WHITE else 1
	var start_row := 6 if us == Piece.WHITE else 1
	var promo_row := 0 if us == Piece.WHITE else 7
	var nr := r + dr
	if nr < 0 or nr > 7:
		return
	var is_promo := nr == promo_row
	if squares[nr * 8 + f] == 0:
		if not caps_only or is_promo:
			_add_pawn_move(moves, sq, nr * 8 + f, p, 0, 0, is_promo)
			if r == start_row and not caps_only and squares[(nr + dr) * 8 + f] == 0:
				moves.append(Move.create(sq, (nr + dr) * 8 + f, p, 0, 0, Move.DOUBLE_PUSH))
	for df in [-1, 1]:
		var nf: int = f + df
		if nf < 0 or nf > 7:
			continue
		var to := nr * 8 + nf
		var q := squares[to]
		if q != 0 and (q & 24) != us:
			_add_pawn_move(moves, sq, to, p, q, Move.CAPTURE, is_promo)
		elif q == 0 and to == ep_square:
			var cap_pawn := Piece.PAWN | Piece.opposite(us)
			moves.append(Move.create(sq, to, p, cap_pawn, 0, Move.CAPTURE | Move.EN_PASSANT))

func _gen_castling(moves: Array[Move], sq: int, p: int, us: int, them: int) -> void:
	if us == Piece.WHITE:
		if sq != 60: return
		if (castling & WK) and squares[61] == 0 and squares[62] == 0 and squares[63] == (Piece.ROOK | us) \
				and not is_square_attacked(60, them) and not is_square_attacked(61, them) and not is_square_attacked(62, them):
			moves.append(Move.create(60, 62, p, 0, 0, Move.CASTLE_KING))
		if (castling & WQ) and squares[59] == 0 and squares[58] == 0 and squares[57] == 0 and squares[56] == (Piece.ROOK | us) \
				and not is_square_attacked(60, them) and not is_square_attacked(59, them) and not is_square_attacked(58, them):
			moves.append(Move.create(60, 58, p, 0, 0, Move.CASTLE_QUEEN))
	else:
		if sq != 4: return
		if (castling & BK) and squares[5] == 0 and squares[6] == 0 and squares[7] == (Piece.ROOK | us) \
				and not is_square_attacked(4, them) and not is_square_attacked(5, them) and not is_square_attacked(6, them):
			moves.append(Move.create(4, 6, p, 0, 0, Move.CASTLE_KING))
		if (castling & BQ) and squares[3] == 0 and squares[2] == 0 and squares[1] == 0 and squares[0] == (Piece.ROOK | us) \
				and not is_square_attacked(4, them) and not is_square_attacked(3, them) and not is_square_attacked(2, them):
			moves.append(Move.create(4, 2, p, 0, 0, Move.CASTLE_QUEEN))

func generate_legal() -> Array[Move]:
	var legal: Array[Move] = []
	var us := side_to_move
	for m in generate_pseudo_legal():
		make_move(m)
		if not in_check(us):
			legal.append(m)
		unmake_move()
	return legal

func legal_moves_from(sq: int) -> Array[Move]:
	var res: Array[Move] = []
	for m in generate_legal():
		if m.from == sq:
			res.append(m)
	return res

## Finds the legal move matching from/to (and promotion type if given, 0 = any).
func find_legal(from: int, to: int, promotion: int = 0) -> Move:
	for m in generate_legal():
		if m.from == from and m.to == to and (promotion == 0 or m.promotion == promotion):
			return m
	return null

# ---------------------------------------------------------------- make / unmake

func make_move(m: Move) -> void:
	undo_stack.append([m, castling, ep_square, halfmove_clock, zobrist_key])
	var us := side_to_move
	var key := zobrist_key
	if ep_square >= 0:
		key ^= _z_ep[ep_square & 7]
	key ^= _z_castle[castling]
	var p := m.piece
	# remove captured piece
	if m.flags & Move.EN_PASSANT:
		var cap_sq := m.to + (8 if us == Piece.WHITE else -8)
		key ^= _zp(squares[cap_sq], cap_sq)
		squares[cap_sq] = 0
	elif m.captured != 0:
		key ^= _zp(m.captured, m.to)
	# move piece
	key ^= _zp(p, m.from)
	squares[m.from] = 0
	var placed := p
	if m.promotion != 0:
		placed = m.promotion | us
	squares[m.to] = placed
	key ^= _zp(placed, m.to)
	if (p & 7) == Piece.KING:
		king_sq[0 if us == Piece.WHITE else 1] = m.to
	# castling rook
	if m.flags & Move.CASTLE_KING:
		var rf := m.to + 1
		var rt := m.to - 1
		var rk := squares[rf]
		squares[rf] = 0
		squares[rt] = rk
		key ^= _zp(rk, rf) ^ _zp(rk, rt)
	elif m.flags & Move.CASTLE_QUEEN:
		var rf2 := m.to - 2
		var rt2 := m.to + 1
		var rk2 := squares[rf2]
		squares[rf2] = 0
		squares[rt2] = rk2
		key ^= _zp(rk2, rf2) ^ _zp(rk2, rt2)
	castling &= _castle_mask[m.from] & _castle_mask[m.to]
	key ^= _z_castle[castling]
	# ep square
	if m.flags & Move.DOUBLE_PUSH:
		ep_square = (m.from + m.to) >> 1
		key ^= _z_ep[ep_square & 7]
	else:
		ep_square = -1
	# clocks
	if (p & 7) == Piece.PAWN or m.captured != 0:
		halfmove_clock = 0
	else:
		halfmove_clock += 1
	if us == Piece.BLACK:
		fullmove_number += 1
	side_to_move = Piece.opposite(us)
	key ^= _z_side
	zobrist_key = key
	history_keys.append(key)

func unmake_move() -> void:
	var u: Array = undo_stack.pop_back()
	var m: Move = u[0]
	history_keys.pop_back()
	castling = u[1]
	ep_square = u[2]
	halfmove_clock = u[3]
	zobrist_key = u[4]
	side_to_move = Piece.opposite(side_to_move)
	var us := side_to_move
	if us == Piece.BLACK:
		fullmove_number -= 1
	squares[m.from] = m.piece
	squares[m.to] = 0
	if m.flags & Move.EN_PASSANT:
		squares[m.to + (8 if us == Piece.WHITE else -8)] = m.captured
	elif m.captured != 0:
		squares[m.to] = m.captured
	if (m.piece & 7) == Piece.KING:
		king_sq[0 if us == Piece.WHITE else 1] = m.from
	if m.flags & Move.CASTLE_KING:
		squares[m.to + 1] = squares[m.to - 1]
		squares[m.to - 1] = 0
	elif m.flags & Move.CASTLE_QUEEN:
		squares[m.to - 2] = squares[m.to + 1]
		squares[m.to + 1] = 0

# ---------------------------------------------------------------- status

func is_insufficient_material() -> bool:
	var minors := 0
	var bishop_colors := []
	for sq in 64:
		var p := squares[sq]
		if p == 0:
			continue
		match p & 7:
			Piece.PAWN, Piece.ROOK, Piece.QUEEN:
				return false
			Piece.KNIGHT:
				minors += 1
			Piece.BISHOP:
				minors += 1
				bishop_colors.append(((sq >> 3) + (sq & 7)) & 1)
	if minors <= 1:
		return true
	# only bishops, all on the same square color
	if bishop_colors.size() == minors:
		for c in bishop_colors:
			if c != bishop_colors[0]:
				return false
		# K+B v K+B same color (also covers several same-colored bishops)
		return true
	return false

func repetition_count() -> int:
	var n := 0
	for k in history_keys:
		if k == zobrist_key:
			n += 1
	return n

func get_status() -> int:
	if generate_legal().is_empty():
		return Status.CHECKMATE if in_check() else Status.STALEMATE
	if halfmove_clock >= 100:
		return Status.DRAW_50
	if repetition_count() >= 3:
		return Status.DRAW_REPETITION
	if is_insufficient_material():
		return Status.DRAW_MATERIAL
	return Status.ONGOING

func perft(depth: int) -> int:
	if depth == 0:
		return 1
	var n := 0
	var us := side_to_move
	for m in generate_pseudo_legal():
		make_move(m)
		if not in_check(us):
			n += 1 if depth == 1 else perft(depth - 1)
		unmake_move()
	return n
