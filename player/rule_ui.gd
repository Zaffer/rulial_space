class_name RuleUI
extends Control

# UI for displaying the currently selected hypergraph rewrite rule

var hbox: HBoxContainer
var lhs_label: Label
var arrow_label: Label
var rhs_label: Label

func _ready():
	_setup_ui()

func _setup_ui():
	# Set up as fullscreen UI for proper positioning
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create background panel for visibility
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position.y = -60
	panel.size = Vector2(300, 50)
	panel.position.x = -150  # Center horizontally
	
	# Style the panel with a semi-transparent background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style_box)
	add_child(panel)
	
	# Create horizontal layout centered in panel
	hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hbox.position = Vector2(-100, -15)  # Center in panel
	panel.add_child(hbox)
	
	# LHS label with larger font
	lhs_label = Label.new()
	lhs_label.text = "●-●-●"
	lhs_label.add_theme_color_override("font_color", Color.CYAN)
	lhs_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(lhs_label)
	
	# Arrow with larger font
	arrow_label = Label.new()
	arrow_label.text = " → "
	arrow_label.add_theme_color_override("font_color", Color.WHITE)
	arrow_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(arrow_label)
	
	# RHS label with larger font
	rhs_label = Label.new()
	rhs_label.text = "●-●"
	rhs_label.add_theme_color_override("font_color", Color.YELLOW)
	rhs_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(rhs_label)

func update_rule(rule_name: String):
	if not lhs_label or not rhs_label:
		return
	
	# Simple text representation of rules
	match rule_name:
		"triangle_to_edge":
			lhs_label.text = "●-●-●"
			rhs_label.text = "●-●"
		"edge_to_triangle":
			lhs_label.text = "●-●"
			rhs_label.text = "●-●-●"
		"isolate_node":
			lhs_label.text = "●-●"
			rhs_label.text = "● ●"
		"create_star":
			lhs_label.text = "●"
			rhs_label.text = "●-●-●"
		"duplicate_node":
			lhs_label.text = "●"
			rhs_label.text = "●-●"
		_:
			lhs_label.text = "?"
			rhs_label.text = "?"
