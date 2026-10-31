class_name Hud
extends CanvasLayer
## HUD: nazwy mózgów, HP, amunicja, czas meczu i wynik serii.

const MARGIN: float = 12.0
const FONT_SIZE: int = 18

@export var match_manager: MatchManager

var _label_a: Label
var _label_b: Label
var _label_center: Label


func _ready() -> void:
	_label_a = _make_label(Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_label_b = _make_label(Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	_label_center = _make_label(Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)


func _make_label(preset: Control.LayoutPreset, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER_TOP \
			else (Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_TOP_RIGHT else Control.GROW_DIRECTION_END)
	return label


func _process(_delta: float) -> void:
	var m: MatchManager = match_manager
	if m == null or m.fighter_a == null:
		return
	_label_a.text = _fighter_text("A", m.brain_a_name, m.fighter_a)
	_label_b.text = _fighter_text("B", m.brain_b_name, m.fighter_b)
	_label_a.add_theme_color_override("font_color", MatchManager.COLOR_A)
	_label_b.add_theme_color_override("font_color", MatchManager.COLOR_B)
	_label_center.text = "mecz %d   czas %.1f / %.0f s\nA %d : %d B   remisy %d" % [
		m.match_index + 1, m.elapsed, m.config.max_match_seconds, m.wins_a, m.wins_b, m.draws]


func _fighter_text(side: String, brain_name: String, fighter: Fighter) -> String:
	return "%s: %s\nHP %.0f   amunicja %d" % [side, brain_name, fighter.hp, fighter.ammo]
