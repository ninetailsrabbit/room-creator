@tool
extends EditorPlugin

var inspector_plugin

func _enter_tree() -> void:
	add_custom_type("RoomCreator", "Node3D", preload("src/room_creator.gd"), preload("assets/icon.svg"))
	add_custom_type("DungeonGenerator", "Node3D", preload("src/dungeon/dungeon_generator.gd"), preload("assets/icon.svg"))
	
	inspector_plugin = preload("src/inspector/inspector_button_plugin.gd").new()
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	remove_custom_type("DungeonGenerator")
	remove_custom_type("RoomCreator")
	remove_inspector_plugin(inspector_plugin)
