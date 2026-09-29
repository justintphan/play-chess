extends Node
## Autoload "GameSettings": choices made in the menu, read by the game.

enum Mode { PVP, PVB }

var mode: int = Mode.PVP
var difficulty: int = 1  # ChessBot.Difficulty: 0 easy, 1 medium, 2 hard
var human_color: int = 8  # Piece.WHITE
