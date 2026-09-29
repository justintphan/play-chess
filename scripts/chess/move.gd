class_name Move
extends RefCounted

const CAPTURE := 1
const EN_PASSANT := 2
const CASTLE_KING := 4
const CASTLE_QUEEN := 8
const DOUBLE_PUSH := 16
const PROMOTION := 32

var from: int = 0
var to: int = 0
var piece: int = 0
var captured: int = 0
var promotion: int = 0
var flags: int = 0

static func create(f: int, t: int, p: int, cap: int = 0, promo: int = 0, fl: int = 0) -> Move:
	var m := Move.new()
	m.from = f
	m.to = t
	m.piece = p
	m.captured = cap
	m.promotion = promo
	m.flags = fl
	return m

func uci() -> String:
	var s := Piece.sq_name(from) + Piece.sq_name(to)
	if promotion != 0:
		s += "?pnbrqk"[promotion]
	return s

func equals(o: Move) -> bool:
	return o != null and from == o.from and to == o.to and promotion == o.promotion

func is_capture() -> bool:
	return (flags & CAPTURE) != 0
