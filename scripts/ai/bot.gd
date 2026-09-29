class_name ChessBot
extends RefCounted
## Negamax / alpha-beta bot with three difficulty profiles. `think` is a
## coroutine: it yields to the engine every few ms so the (single-threaded)
## web build stays responsive.

enum Difficulty { EASY, MEDIUM, HARD }

const INF_SCORE := 1000000
const MATE := 100000
const NO_SCORE := -2000000
const SLICE_MS := 12
const HARD_MAX_DEPTH := 5
const TT_MAX := 200000

var nodes: int = 0
var last_depth: int = 0
var aborted: bool = false
var cancelled: bool = false
var tt: Dictionary = {}
var rng := RandomNumberGenerator.new()

var _deadline: int = 0
var _last_yield: int = 0
var _tree: SceneTree
var _use_tt: bool = false
var _killers := PackedInt32Array()

func _init() -> void:
	rng.randomize()
	_killers.resize(256)

# ------------------------------------------------------------------ public

func think(board: BoardState, difficulty: int, tree: SceneTree) -> Move:
	_tree = tree
	var b := board.copy()
	var moves := b.generate_legal()
	if moves.is_empty():
		return null
	if moves.size() == 1:
		return moves[0]
	nodes = 0
	last_depth = 0
	aborted = cancelled
	_killers.fill(0)
	_last_yield = Time.get_ticks_msec()
	_use_tt = false
	match difficulty:
		Difficulty.EASY:
			return await _think_easy(b, moves)
		Difficulty.MEDIUM:
			_deadline = Time.get_ticks_msec() + 1000
			if _is_opening(b):
				var om := await _think_opening(b, moves)
				if om != null:
					return om
				aborted = cancelled
			return await _think_medium(b, moves)
		_:
			_deadline = Time.get_ticks_msec() + 2000
			if _is_opening(b):
				var om2 := await _think_opening(b, moves)
				if om2 != null:
					return om2
				aborted = cancelled
				_deadline = Time.get_ticks_msec() + 2000
			return await _think_hard(b, moves)

## Opening variety only for real game openings: early move number and no captures yet.
func _is_opening(b: BoardState) -> bool:
	if b.fullmove_number > 2:
		return false
	var count := 0
	for p in b.squares:
		if p != 0:
			count += 1
	return count == 32

# ------------------------------------------------------------------ profiles

func _think_easy(b: BoardState, moves: Array[Move]) -> Move:
	if rng.randf() < 0.35:
		return moves[rng.randi() % moves.size()]
	var us := b.side_to_move
	var best: Move = moves[0]
	var best_score := -INF_SCORE * 2
	for m in moves:
		b.make_move(m)
		var s: int
		var replies := b.generate_legal()
		if replies.is_empty():
			s = MATE if b.in_check() else 0
		else:
			s = -Evaluator.evaluate(b)
		b.unmake_move()
		s += rng.randi_range(-150, 150)
		if s > best_score:
			best_score = s
			best = m
		await _maybe_yield()
	return best

func _think_opening(b: BoardState, moves: Array[Move]) -> Move:
	var scores := await _search_root(b, moves, 2, true)
	if aborted:
		return null
	var top := -INF_SCORE * 2
	for s in scores:
		top = maxi(top, s)
	var pool: Array[Move] = []
	for i in moves.size():
		if scores[i] != NO_SCORE and scores[i] >= top - 20:
			pool.append(moves[i])
	return pool[rng.randi() % pool.size()] if pool.size() > 0 else null

func _think_medium(b: BoardState, moves: Array[Move]) -> Move:
	var scores := await _search_root(b, moves, 2, true)
	var best: Move = moves[0]
	var best_score := -INF_SCORE * 2
	for i in moves.size():
		if scores[i] == NO_SCORE:
			continue
		var s := scores[i] + rng.randi_range(-30, 30)
		if s > best_score:
			best_score = s
			best = moves[i]
	last_depth = 2
	return best

func _think_hard(b: BoardState, moves: Array[Move]) -> Move:
	_use_tt = true
	if tt.size() > TT_MAX:
		tt.clear()
	var start := Time.get_ticks_msec()
	var cap := _deadline - start
	# initial ordering
	var sc := _score_moves(moves, 0, 0)
	var order: Array[Move] = []
	var idx := range(moves.size())
	idx.sort_custom(func(a, c): return sc[a] > sc[c])
	for i in idx:
		order.append(moves[i])
	var best: Move = order[0]
	for depth in range(1, HARD_MAX_DEPTH + 1):
		var scores := await _search_root(b, order, depth, false)
		var bi := -1
		var bs := NO_SCORE
		for i in order.size():
			if scores[i] > bs:
				bs = scores[i]
				bi = i
		if aborted:
			# a partial iteration is only trusted if the previous best was re-searched
			if bi >= 0 and scores[0] != NO_SCORE:
				best = order[bi]
			break
		best = order[bi]
		last_depth = depth
		# Fail-low moves can report exactly alpha and tie with the real best, and
		# sort_custom is unstable, so pin the best move first explicitly; an
		# aborted next iteration then always falls back to it.
		var ord2 := range(order.size())
		ord2.erase(bi)
		ord2.sort_custom(func(a, c): return scores[a] > scores[c])
		var next: Array[Move] = [best]
		for i in ord2:
			next.append(order[i])
		order = next
		if absi(bs) > MATE - 200:
			break
		if Time.get_ticks_msec() - start > cap * 0.6:
			break
	return best

# ------------------------------------------------------------------ search

func cancel() -> void:
	cancelled = true
	aborted = true

func _maybe_yield() -> void:
	if cancelled:
		aborted = true
	var now := Time.get_ticks_msec()
	if now - _last_yield > SLICE_MS:
		await _tree.process_frame
		_last_yield = Time.get_ticks_msec()

## Scores each root move. full_window: exact scores for every move (needed for noise).
func _search_root(b: BoardState, moves: Array[Move], depth: int, full_window: bool) -> PackedInt32Array:
	var scores := PackedInt32Array()
	scores.resize(moves.size())
	scores.fill(NO_SCORE)
	var alpha := -INF_SCORE
	var beta := INF_SCORE
	for i in moves.size():
		var m := moves[i]
		b.make_move(m)
		var s: int
		if depth <= 1:
			s = -_quiesce(b, -beta, -alpha, 1)
		else:
			s = -(await _node_async(b, depth - 1, -beta, -alpha, 1))
		b.unmake_move()
		if aborted:
			break
		scores[i] = s
		if not full_window and s > alpha:
			alpha = s
		await _maybe_yield()
	return scores

func _is_draw(b: BoardState) -> bool:
	if b.halfmove_clock >= 100:
		return true
	var h := b.history_keys
	var n := h.size()
	var key := b.zobrist_key
	var i := n - 3
	var lim := maxi(0, n - 1 - b.halfmove_clock)
	while i >= lim:
		if h[i] == key:
			return true
		i -= 2
	return false

func _node_async(b: BoardState, depth: int, alpha: int, beta: int, ply: int) -> int:
	if _is_draw(b):
		return 0
	var us := b.side_to_move
	var moves := b.generate_pseudo_legal()
	var scores := _score_moves(moves, 0, ply)
	var legal := 0
	var best := -INF_SCORE
	for i in moves.size():
		var m := _pick(moves, scores, i)
		b.make_move(m)
		if b.in_check(us):
			b.unmake_move()
			continue
		legal += 1
		var s := -_negamax(b, depth - 1, -beta, -alpha, ply + 1)
		b.unmake_move()
		if aborted:
			return 0
		if s > best:
			best = s
		if s > alpha:
			alpha = s
			if alpha >= beta:
				_store_killer(m, ply)
				break
		await _maybe_yield()
	if legal == 0:
		return -(MATE - ply) if b.in_check(us) else 0
	return best

func _negamax(b: BoardState, depth: int, alpha: int, beta: int, ply: int) -> int:
	if depth <= 0:
		return _quiesce(b, alpha, beta, ply)
	nodes += 1
	if (nodes & 1023) == 0 and Time.get_ticks_msec() > _deadline:
		aborted = true
	if aborted:
		return 0
	if _is_draw(b):
		return 0
	var orig_alpha := alpha
	var key := b.zobrist_key
	var tt_id := 0
	if _use_tt:
		var e = tt.get(key)
		if e != null:
			tt_id = e[3]
			if e[0] >= depth:
				var ts: int = e[1]
				if ts > MATE - 1000:
					ts -= ply
				elif ts < -MATE + 1000:
					ts += ply
				# cut off only; narrowing alpha/beta here would make the bound
				# flag stored below wrong (an upper bound saved as exact)
				if e[2] == 0:
					return ts
				elif e[2] == 1 and ts >= beta:
					return ts
				elif e[2] == 2 and ts <= alpha:
					return ts
	if ply >= 60:
		return Evaluator.evaluate(b)
	var us := b.side_to_move
	var moves := b.generate_pseudo_legal()
	var scores := _score_moves(moves, tt_id, ply)
	var legal := 0
	var best := -INF_SCORE
	var best_id := 0
	for i in moves.size():
		var m := _pick(moves, scores, i)
		b.make_move(m)
		if b.in_check(us):
			b.unmake_move()
			continue
		legal += 1
		var s := -_negamax(b, depth - 1, -beta, -alpha, ply + 1)
		b.unmake_move()
		if aborted:
			return 0
		if s > best:
			best = s
			best_id = m.from * 64 + m.to
		if s > alpha:
			alpha = s
			if alpha >= beta:
				if m.captured == 0:
					_store_killer(m, ply)
				break
	if legal == 0:
		return -(MATE - ply) if b.in_check(us) else 0
	if _use_tt:
		var flag := 0
		if best <= orig_alpha:
			flag = 2
		elif best >= beta:
			flag = 1
		var st := best
		if st > MATE - 1000:
			st += ply
		elif st < -MATE + 1000:
			st -= ply
		tt[key] = [depth, st, flag, best_id]
	return best

func _quiesce(b: BoardState, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 1023) == 0 and Time.get_ticks_msec() > _deadline:
		aborted = true
	if aborted:
		return 0
	var stand := Evaluator.evaluate(b)
	if ply >= 60 or stand >= beta:
		return stand
	if stand > alpha:
		alpha = stand
	var us := b.side_to_move
	var moves := b.generate_pseudo_legal(true)
	var scores := _score_moves(moves, 0, 99)
	for i in moves.size():
		var m := _pick(moves, scores, i)
		b.make_move(m)
		if b.in_check(us):
			b.unmake_move()
			continue
		var s := -_quiesce(b, -beta, -alpha, ply + 1)
		b.unmake_move()
		if aborted:
			return 0
		if s >= beta:
			return s
		if s > alpha:
			alpha = s
	return alpha

# ------------------------------------------------------------------ ordering

func _store_killer(m: Move, ply: int) -> void:
	if m.captured != 0 or ply >= 120:
		return
	var id := m.from * 64 + m.to + 1
	if _killers[ply * 2] != id:
		_killers[ply * 2 + 1] = _killers[ply * 2]
		_killers[ply * 2] = id

func _score_moves(moves: Array[Move], tt_id: int, ply: int) -> PackedInt32Array:
	var sc := PackedInt32Array()
	sc.resize(moves.size())
	var k1 := 0
	var k2 := 0
	if ply < 120:
		k1 = _killers[ply * 2]
		k2 = _killers[ply * 2 + 1]
	for i in moves.size():
		var m := moves[i]
		var id := m.from * 64 + m.to
		var s := 0
		if tt_id != 0 and id == tt_id:
			s = 100000
		elif m.captured != 0:
			s = 10000 + Evaluator.VALUE[m.captured & 7] * 10 - (m.piece & 7)
		elif m.promotion == Piece.QUEEN:
			s = 9500
		elif id + 1 == k1 or id + 1 == k2:
			s = 5000
		if m.promotion != 0 and m.promotion != Piece.QUEEN:
			s -= 8000
		sc[i] = s
	return sc

## Selection step: moves the best remaining move to position i and returns it.
func _pick(moves: Array[Move], scores: PackedInt32Array, i: int) -> Move:
	var bi := i
	var bs := scores[i]
	for j in range(i + 1, moves.size()):
		if scores[j] > bs:
			bs = scores[j]
			bi = j
	if bi != i:
		var tm := moves[i]
		moves[i] = moves[bi]
		moves[bi] = tm
		scores[bi] = scores[i]
		scores[i] = bs
	return moves[i]
