class_name Rule
extends Control

# UI for displaying the currently selected hypergraph rewrite rule

@onready var panel: Panel = $Panel
@onready var hbox: HBoxContainer = $Panel/HBoxContainer
@onready var lhs_label: Label = $Panel/HBoxContainer/LHSLabel
@onready var arrow_label: Label = $Panel/HBoxContainer/ArrowLabel
@onready var rhs_label: Label = $Panel/HBoxContainer/RHSLabel

func _ready():
	_setup_ui()

func _setup_ui():
	# Style the panel with a semi-transparent background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style_box)

func update_rule(rule_name: String):
	if not lhs_label or not rhs_label:
		return
	
	# Simple text representation of rules
	match rule_name:
		"triangle_to_edge":
			lhs_label.text = "🔺"  # Triangle symbol for 3-node hyperedge
			rhs_label.text = "🟣-🟣"  # Simple edge
		"edge_to_triangle":
			lhs_label.text = "🔵-🔵"  # Simple edge
			rhs_label.text = "🔺"  # Triangle symbol for 3-node hyperedge
		"isolate_node":
			lhs_label.text = "🔵-🔵"  # Connected nodes
			rhs_label.text = "🟣 🟣"  # Isolated nodes
		"create_star":
			lhs_label.text = "🔵"  # Single node
			rhs_label.text = "⭐"  # Star symbol
		"duplicate_node":
			lhs_label.text = "🔵"  # Single node
			rhs_label.text = "🟣-🟣"  # Two connected nodes
		_:
			lhs_label.text = "?"
			rhs_label.text = "?"
