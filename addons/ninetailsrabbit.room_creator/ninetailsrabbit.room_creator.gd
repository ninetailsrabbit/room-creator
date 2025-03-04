@tool
extends EditorPlugin

var inspector_plugin
var plugin_custom_type: String = "RoomCreator"

func _enter_tree() -> void:
	add_custom_type(plugin_custom_type, "Node3D", preload("src/room_creator.gd"), preload("assets/icon.svg"))
	
	inspector_plugin = preload("src/inspector/inspector_button_plugin.gd").new()
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	remove_custom_type(plugin_custom_type)
	remove_inspector_plugin(inspector_plugin)
