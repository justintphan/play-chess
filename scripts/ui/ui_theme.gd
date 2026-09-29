class_name UITheme
extends RefCounted
## Shared theme, sized for touch (iPad) use.

const BG := Color("302e2b")
const PANEL := Color("262421")
const ACCENT := Color("769656")
const TEXT := Color("f0efe9")
const BUTTON_H := 64.0
const FONT_SIZE := 26

static func _box(color: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.border_color = border
	sb.set_border_width_all(bw)
	return sb

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.set_stylebox("normal", "Button", _box(Color("4a4744")))
	t.set_stylebox("hover", "Button", _box(Color("5a5754")))
	t.set_stylebox("pressed", "Button", _box(ACCENT))
	t.set_stylebox("hover_pressed", "Button", _box(ACCENT))
	t.set_stylebox("disabled", "Button", _box(Color("3a3835")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("807d78"))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 24)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 14))
	t.set_stylebox("panel", "Panel", _box(PANEL, 14, ACCENT, 2))
	return t

static func button(text: String, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.custom_minimum_size = Vector2(0, BUTTON_H)
	b.focus_mode = Control.FOCUS_NONE
	return b
