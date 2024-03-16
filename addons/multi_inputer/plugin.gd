@tool
extends EditorPlugin

const AUTOLOAD_NAME = "MInput"


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/multi_inputer/input.gd")


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
