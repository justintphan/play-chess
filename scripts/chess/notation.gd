class_name Notation
extends RefCounted
## SAN helpers.

static func to_san(board: BoardState, m: Move) -> String:
	var s := ""
	var t := m.piece & 7
	if m.flags & Move.CASTLE_KING:
		s = "O-O"
	elif m.flags & Move.CASTLE_QUEEN:
		s = "O-O-O"
	else:
		if t == Piece.PAWN:
			if m.is_capture():
				s += "abcdefgh"[Piece.file_of(m.from)]
		else:
			s += "?PNBRQK"[t]
			# disambiguation
			var others: Array[Move] = []
			for o in board.generate_legal():
				if o.to == m.to and o.piece == m.piece and o.from != m.from:
					others.append(o)
			if others.size() > 0:
				var same_file := false
				var same_rank := false
				for o in others:
					if Piece.file_of(o.from) == Piece.file_of(m.from):
						same_file = true
					if Piece.rank_of(o.from) == Piece.rank_of(m.from):
						same_rank = true
				var fch: String = "abcdefgh"[Piece.file_of(m.from)]
				var rch := str(Piece.rank_of(m.from) + 1)
				if not same_file:
					s += fch
				elif not same_rank:
					s += rch
				else:
					s += fch + rch
		if m.is_capture():
			s += "x"
		s += Piece.sq_name(m.to)
		if m.promotion != 0:
			s += "=" + "?PNBRQK"[m.promotion]
	var b := board.copy()
	b.make_move(m)
	if b.in_check():
		s += "#" if b.generate_legal().is_empty() else "+"
	return s
