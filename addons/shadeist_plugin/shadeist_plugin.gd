@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type(
		"LegacyPostFX",
		"CanvasLayer",
		preload("res://addons/shadeist_plugin/legacypostfx_node.gd"),
		preload("postfx_icon.svg")
	)
	add_custom_type(
		"ColorPostFX",
		"CanvasLayer",
		preload("res://addons/shadeist_plugin/colorpostfx_node.gd"),
		preload("postfx_icon.svg")
	)

func _exit_tree() -> void:
	remove_custom_type("LegacyPostFX")
	remove_custom_type("ColorPostFX")
