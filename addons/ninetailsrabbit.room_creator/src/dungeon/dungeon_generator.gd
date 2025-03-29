@tool
class_name DungeonGenerator extends Node3D

class DungeonRoom:
	var is_entrance: bool = false
	var room: CSGRoom
	var column: int
	var row: int
	var dimensions: Vector2i ## The dimensions of the grid it belows
	
	func _init(_room: CSGRoom, _column: int, _row: int, _dimensions: Vector2i, _is_entrance: bool = false) -> void:
		room = _room
		column = _column
		row = _row
		dimensions = _dimensions
		is_entrance = _is_entrance
		
	func grid_position() -> Vector2i:
		return Vector2i(column, row)
		
	#region Grid related
	func is_border() -> bool:
		return is_top_border() or is_bottom_border() or is_right_border() or is_left_border()
		
	func is_top_border() -> bool:
		return row == 0

	func is_bottom_border() -> bool:
		return row == dimensions.y - 1

	func is_right_border() -> bool:
		return column == dimensions.x - 1

	func is_left_border() -> bool:
		return column == 0
		
	func is_top_left_corner() -> bool:
		return row == 0 and column == 0

	func is_bottom_left_corner() -> bool:
		return column == 0 and row == dimensions.y - 1

	func is_top_right_corner() -> bool:
		return row == 0 and column == dimensions.x - 1


	func is_bottom_right_corner() -> bool:
		return row == dimensions.y - 1 and column == dimensions.x - 1

#endregion


@export_tool_button("Generate dungeon") var generate_dungeon_action = generate_dungeon
@export_tool_button("Clear dungeon") var clear_dungeon_action = clear_dungeon
## Dimensions in the format Vector2i(column, row)
@export var dimensions: Vector2i = Vector2i(10, 5)
@export var room_size: Vector3 = Vector3(5, 4, 5)
@export var entrance_position: Vector2i = Vector2i(0, 0)
## The entrance room will be randomized on one of the borders of the grid
@export var randomize_entrance: bool = false


var dungeon_grid: Array = []


func clear_dungeon() -> void:
	for child in get_children():
		child.free()
		
		
func generate_dungeon() -> void:
	clear_dungeon()
	dungeon_grid.clear()
	
	assert(entrance_position.x >= 0 \
		and entrance_position.x < dimensions.x - 1 \
		and entrance_position.y >= 0 \
		and entrance_position.y <= dimensions.y - 1,
		"The entrance_position is out of bounds for the current dungeon dimensions"
		)
	
	var entrance: Vector2i = border_positions().pick_random() if randomize_entrance else entrance_position
	
	for column in dimensions.x:
		dungeon_grid.append([])
		
		for row in dimensions.y:
			var room: CSGRoom = CSGRoom.new()
			var dungeon_room: DungeonRoom = DungeonRoom.new(
				room,
				column,
				row,
				dimensions,
				Vector2i(column, row) == entrance
			)
				
			room.room_size = room_size
			room.use_manual_door_mode = true
			
			_setup_room_doors(dungeon_room)
			add_child(room)
			
			room.position = Vector3(row * room_size.x, 0, -column * room_size.z)
			room.position.z -= (room.wall_thickness) * column
			room.position.x += (room.wall_thickness) * row
			
			dungeon_grid[column].append(room)
			
	#
func pick_random_border() -> Vector2i:
	var dungeon_borders: Array[Vector2i] = border_rooms()\
		.map(func(dungeon_room: DungeonRoom): return dungeon_room.grid_position())

	return dungeon_borders.pick_random()
	

## A helper function to tterate over the dungeon grid and execute a callback callback that receives a DungeonRoom
func iterate_over_grid(grid: Array, callback: Callable) -> void:
	for column in dimensions.x:
		for row in dimensions.y:
			callback.call(column, row)


func border_rooms() -> Array[DungeonRoom]:
	var rooms: Array[DungeonRoom] = []
	rooms.assign(RoomCreatorPluginUtilities\
		.flatten(dungeon_grid)\
		.filter(func(dungeon_room: DungeonRoom): return dungeon_room.is_border())
	)
	
	return rooms


func border_positions(dungeon_dimensions: Vector2i = dimensions) -> Array[Vector2i]:
	var borders: Array[Vector2i] = []
	var detect_border = func(column: int, row: int):
		if row == 0 or column == 0 or row == dungeon_dimensions.y - 1 or column == dungeon_dimensions.x - 1:
			borders.append(Vector2i(column, row))
	
	iterate_over_grid(dungeon_grid, detect_border)
	
	return borders
	

func _setup_room_doors(dungeon_room: DungeonRoom) -> void:
	if dungeon_room.is_top_border():
		dungeon_room.room.door_in_left_wall = false
		dungeon_room.room.door_in_back_wall = false if dungeon_room.is_top_left_corner() else true
		dungeon_room.room.door_in_front_wall = false if dungeon_room.is_top_right_corner() else true
		dungeon_room.room.door_in_right_wall = true
	elif dungeon_room.is_bottom_border():
		dungeon_room.room.door_in_left_wall = true
		dungeon_room.room.door_in_back_wall = false if dungeon_room.is_bottom_left_corner() else true
		dungeon_room.room.door_in_front_wall = false if dungeon_room.is_bottom_right_corner() else true
		dungeon_room.room.door_in_right_wall = false
	elif dungeon_room.is_right_border():
		dungeon_room.room.door_in_left_wall = false if dungeon_room.is_top_right_corner() else true
		dungeon_room.room.door_in_back_wall = true
		dungeon_room.room.door_in_front_wall = false
		dungeon_room.room.door_in_right_wall = false if dungeon_room.is_bottom_right_corner() else true
	elif dungeon_room.is_left_border():
		dungeon_room.room.door_in_left_wall = true
		dungeon_room.room.door_in_back_wall = false
		dungeon_room.room.door_in_front_wall = true
		dungeon_room.room.door_in_right_wall = false if dungeon_room.is_bottom_right_corner() else true
	else:
		dungeon_room.room.door_in_left_wall = true
		dungeon_room.room.door_in_back_wall = true
		dungeon_room.room.door_in_front_wall = true
		dungeon_room.room.door_in_right_wall = true
