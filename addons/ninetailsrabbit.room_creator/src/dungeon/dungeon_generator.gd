@tool
class_name DungeonGenerator extends Node3D

@export_tool_button("Generate dungeon") var generate_dungeon_action = generate_dungeon
## Dimensions in the format Vector2i(column, row)
@export var dimensions: Vector2i = Vector2i(10, 5)
@export var room_size: Vector3 = Vector3(5, 4, 5)


var dungeon_grid: Array = []


func generate_dungeon() -> void:
	for child in get_children():
		child.free()
		
	dungeon_grid.clear()
	
	for column in dimensions.x:
		dungeon_grid.append([])
		
		for row in dimensions.y:
			var room: CSGRoom = CSGRoom.new()
			dungeon_grid[column].append(room)
			
			room.room_size = room_size
			room.use_manual_door_mode = true
			
			_setup_room_doors(room, column, row)
			add_child(room)
			
			room.position = Vector3(row * room_size.x, 0, -column * room_size.z)
			room.position.z -= (room.wall_thickness) * column
			room.position.x += (room.wall_thickness) * row
			

## Iterate over the grid with a callback that receives a CSGRoom, column and row
func iterate_over_grid(grid: Array, callback: Callable) -> void:
	for column in dimensions.x:
		for row in dimensions.y:
			callback.call(grid[column][row], column, row)


func _setup_room_doors(room: CSGRoom, column: int, row: int) -> void:
	if is_top_border(column, row):
		room.door_in_left_wall = false
		room.door_in_back_wall = false if is_top_left_corner(column, row) else true
		room.door_in_front_wall = false if is_top_right_corner(column, row) else true
		room.door_in_right_wall = true
	elif is_bottom_border(column, row):
		room.door_in_left_wall = true
		room.door_in_back_wall = false if is_bottom_left_corner(column, row) else true
		room.door_in_front_wall = false if is_bottom_right_corner(column, row) else true
		room.door_in_right_wall = false
	elif is_right_border(column, row):
		room.door_in_left_wall = false if is_top_right_corner(column, row) else true
		room.door_in_back_wall = true
		room.door_in_front_wall = false
		room.door_in_right_wall = false if is_bottom_right_corner(column, row) else true
	elif is_left_border(column, row):
		room.door_in_left_wall = true
		room.door_in_back_wall = false
		room.door_in_front_wall = true
		room.door_in_right_wall = false if is_bottom_right_corner(column, row) else true
	else:
		room.door_in_left_wall = true
		room.door_in_back_wall = true
		room.door_in_front_wall = true
		room.door_in_right_wall = true

#region Grid related
func is_top_border(column: int, row: int) -> bool:
	return row == 0


func is_bottom_border(column: int, row: int) -> bool:
	return row == dimensions.y - 1


func is_right_border(column: int, row: int) -> bool:
	return column == dimensions.x - 1


func is_left_border(column: int, row: int) -> bool:
	return column == 0
	
	
func is_top_left_corner(column: int, row: int) -> bool:
	return row == 0 and column == 0


func is_bottom_left_corner(column: int, row: int) -> bool:
	return column == 0 and row == dimensions.y - 1


func is_top_right_corner(column: int, row: int) -> bool:
	return row == 0 and column == dimensions.x - 1


func is_bottom_right_corner(column: int, row: int) -> bool:
	return row == dimensions.y - 1 and column == dimensions.x - 1

#endregion
