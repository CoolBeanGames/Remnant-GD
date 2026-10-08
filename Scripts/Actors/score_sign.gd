class_name score_sign
extends Label3D

## Minimum display width. Larger scores grow to the right without truncation.
@export_range(1, 32, 1) var minimum_digits: int = 18

var _displayed_text: String = ""


func _ready() -> void:
	# Keep the authored centered sign's left edge when switching alignment.
	var display_font: Font = font if font != null else ThemeDB.fallback_font
	if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		offset.x -= display_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	update_score()


func _process(_delta: float) -> void:
	update_score()


func update_score() -> void:
	var value: Variant = Blackboard.read_data("score")
	var total: int = int(value) if value is int or value is float else 0
	var digits: String = str(absi(total)).pad_zeros(minimum_digits)
	var formatted: String = ("-" if total < 0 else "") + digits
	if formatted != _displayed_text:
		_displayed_text = formatted
		text = formatted
