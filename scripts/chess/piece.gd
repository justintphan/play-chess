class_name Piece
extends RefCounted
## Piece encoding and square helpers. Square 0 = a8, 63 = h1.

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const WHITE := 8
const BLACK := 16

static func type_of(p: int) -> int:
	return p & 7

static func color_of(p: int) -> int:
	return p & 24

static func is_white(p: int) -> bool:
	return (p & 8) != 0

static func make(type: int, color: int) -> int:
	return type | color

static func opposite(color: int) -> int:
	return BLACK if color == WHITE else WHITE

static func to_char(p: int) -> String:
	if p == EMPTY:
		return ""
	var c := "?PNBRQK"[type_of(p)]
	return c if is_white(p) else c.to_lower()

static func from_char(c: String) -> int:
	var idx := "PNBRQK".find(c.to_upper())
	if idx < 0:
		return EMPTY
	var color := WHITE if c == c.to_upper() else BLACK
	return (idx + 1) | color

static func file_of(sq: int) -> int:
	return sq & 7

static func rank_of(sq: int) -> int:
	return 7 - (sq >> 3)  # 0 = rank 1

static func sq_name(sq: int) -> String:
	return "abcdefgh"[file_of(sq)] + str(rank_of(sq) + 1)

static func sq_from_name(n: String) -> int:
	var f := "abcdefgh".find(n[0])
	var r := int(n[1]) - 1
	if f < 0 or r < 0 or r > 7:
		return -1
	return (7 - r) * 8 + f
