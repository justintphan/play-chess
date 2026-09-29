class_name Evaluator
extends RefCounted
## Material + piece-square tables (Simplified Evaluation Function). Tables are
## written from White's view with index 0 = a8, matching our square indexing.

const VALUE := [0, 100, 320, 330, 500, 900, 0]

const PAWN_T := [
	0, 0, 0, 0, 0, 0, 0, 0,
	50, 50, 50, 50, 50, 50, 50, 50,
	10, 10, 20, 30, 30, 20, 10, 10,
	5, 5, 10, 25, 25, 10, 5, 5,
	0, 0, 0, 20, 20, 0, 0, 0,
	5, -5, -10, 0, 0, -10, -5, 5,
	5, 10, 10, -20, -20, 10, 10, 5,
	0, 0, 0, 0, 0, 0, 0, 0]
const KNIGHT_T := [
	-50, -40, -30, -30, -30, -30, -40, -50,
	-40, -20, 0, 0, 0, 0, -20, -40,
	-30, 0, 10, 15, 15, 10, 0, -30,
	-30, 5, 15, 20, 20, 15, 5, -30,
	-30, 0, 15, 20, 20, 15, 0, -30,
	-30, 5, 10, 15, 15, 10, 5, -30,
	-40, -20, 0, 5, 5, 0, -20, -40,
	-50, -40, -30, -30, -30, -30, -40, -50]
const BISHOP_T := [
	-20, -10, -10, -10, -10, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 10, 10, 5, 0, -10,
	-10, 5, 5, 10, 10, 5, 5, -10,
	-10, 0, 10, 10, 10, 10, 0, -10,
	-10, 10, 10, 10, 10, 10, 10, -10,
	-10, 5, 0, 0, 0, 0, 5, -10,
	-20, -10, -10, -10, -10, -10, -10, -20]
const ROOK_T := [
	0, 0, 0, 0, 0, 0, 0, 0,
	5, 10, 10, 10, 10, 10, 10, 5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	0, 0, 0, 5, 5, 0, 0, 0]
const QUEEN_T := [
	-20, -10, -10, -5, -5, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 5, 5, 5, 0, -10,
	-5, 0, 5, 5, 5, 5, 0, -5,
	0, 0, 5, 5, 5, 5, 0, -5,
	-10, 5, 5, 5, 5, 5, 0, -10,
	-10, 0, 5, 0, 0, 0, 0, -10,
	-20, -10, -10, -5, -5, -10, -10, -20]
const KING_MG_T := [
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-20, -30, -30, -40, -40, -30, -30, -20,
	-10, -20, -20, -20, -20, -20, -20, -10,
	20, 20, 0, 0, 0, 0, 20, 20,
	20, 30, 10, 0, 0, 10, 30, 20]
const KING_EG_T := [
	-50, -40, -30, -20, -20, -30, -40, -50,
	-30, -20, -10, 0, 0, -10, -20, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -30, 0, 0, 0, 0, -30, -30,
	-50, -30, -30, -30, -30, -30, -30, -50]

static var _tables: Array = []

static func _ensure() -> void:
	if _tables.is_empty():
		_tables = [[], PAWN_T, KNIGHT_T, BISHOP_T, ROOK_T, QUEEN_T, KING_MG_T]

## Score in centipawns from the side-to-move's perspective.
static func evaluate(b: BoardState) -> int:
	_ensure()
	var sq_arr := b.squares
	var score := 0  # white minus black
	var wq := 0
	var bq := 0
	var wminor := 0
	var bminor := 0
	var wb := 0
	var bb := 0
	var wrook := 0
	var brook := 0
	for sq in 64:
		var p := sq_arr[sq]
		if p == 0:
			continue
		var t := p & 7
		if (p & 8) != 0:
			score += VALUE[t]
			if t != Piece.KING:
				score += _tables[t][sq]
			match t:
				Piece.QUEEN: wq += 1
				Piece.KNIGHT: wminor += 1
				Piece.BISHOP:
					wminor += 1
					wb += 1
				Piece.ROOK: wrook += 1
		else:
			score -= VALUE[t]
			if t != Piece.KING:
				score -= _tables[t][sq ^ 56]
			match t:
				Piece.QUEEN: bq += 1
				Piece.KNIGHT: bminor += 1
				Piece.BISHOP:
					bminor += 1
					bb += 1
				Piece.ROOK: brook += 1
	if wb >= 2: score += 30
	if bb >= 2: score -= 30
	var endgame := (wq + bq == 0) or ((wq == 0 or (wminor <= 1 and wrook == 0)) and (bq == 0 or (bminor <= 1 and brook == 0)))
	var kt: Array = KING_EG_T if endgame else KING_MG_T
	var wk := b.king_sq[0]
	var bk := b.king_sq[1]
	if wk >= 0: score += kt[wk]
	if bk >= 0: score -= kt[bk ^ 56]
	return score if b.side_to_move == Piece.WHITE else -score
