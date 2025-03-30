@tool
class_name DungeonGenerator extends Node3D

class DungeonRoom:
	var is_entrance: bool = false:
		set(value):
			is_entrance = value
			critical_path = 0 if is_entrance else -1
	var is_exit: bool = false
	var room: CSGRoom
	var column: int
	var row: int
	var dimensions: Vector2i ## The dimensions of the grid it belows
	var critical_path: int = -1
	
	func _init(_room: CSGRoom, _column: int, _row: int, _dimensions: Vector2i) -> void:
		room = _room
		column = _column
		row = _row
		dimensions = _dimensions
	
	
	func grid_position() -> Vector2i:
		return Vector2i(column, row)
		
	func critical_path_neighbour_of(other_room: DungeonRoom):
		return critical_path != -1 \
			and other_room.critical_path != -1 \
			and other_room.critical_path in [maxi(0, critical_path - 1), critical_path + 1]
	
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
		
	func is_corner() -> bool:
		return is_top_left_corner() or is_top_right_corner() or is_bottom_left_corner() or is_bottom_right_corner()
		
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
@export var critical_path_length: int = 5
@export var entrance_position: Vector2i = Vector2i(0, 0)
## The entrance room will be randomized on one of the borders of the grid
@export var randomize_entrance: bool = false


var directions_v2: Array[Vector2i]= [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
var dungeon_grid: Array = []
var entrance: Vector2i


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
	
	entrance = border_positions().pick_random() if randomize_entrance else entrance_position
	
	for column in dimensions.x:
		dungeon_grid.append([])
		
		for row in dimensions.y:
			var room: CSGRoom = CSGRoom.new()
			var dungeon_room: DungeonRoom = DungeonRoom.new(
				room,
				column,
				row,
				dimensions
			)
			
			dungeon_room.is_entrance = Vector2i(column, row) == entrance
				
			room.room_size = room_size
			room.use_manual_door_mode = true
			
			dungeon_grid[column].append(dungeon_room)
			
	generate_critical_path(entrance, critical_path_length)
	create_dungeon_rooms()
	

func create_dungeon_rooms() -> void:
	for room: DungeonRoom in RoomCreatorPluginUtilities.flatten(dungeon_grid)\
		.filter(func(room: DungeonRoom): return room.critical_path != -1 or room.is_entrance):
			
		room.is_exit = room.critical_path == critical_path_length - 1
		add_room_to_tree(room)


func add_room_to_tree(dungeon_room: DungeonRoom) -> void:
	_setup_room_doors(dungeon_room)
	add_child(dungeon_room.room)
	
	dungeon_room.room.create_manual_doors()
	dungeon_room.room.position = Vector3(dungeon_room.row * room_size.x, 0, -dungeon_room.column * room_size.z)
	dungeon_room.room.position.z -= (dungeon_room.room.wall_thickness) * dungeon_room.column
	dungeon_room.room.position.x += (dungeon_room.room.wall_thickness) * dungeon_room.row


## A helper function to tterate over the dungeon grid and execute a callback callback that receives a DungeonRoom
func iterate_over_grid(grid: Array, callback: Callable) -> void:
	for column in dimensions.x:
		for row in dimensions.y:
			callback.call(column, row)


func generate_critical_path(from: Vector2i, length: int) -> bool:
	if length == 0:
		return true
	
	var current: Vector2i = from
	
	var direction: Vector2i = directions_v2.pick_random()
	## Avoid negative room position as the dungeon grid only uses positive values where the origin is Vector2i.ZERO
	var target_position: Vector2i = Vector2i(current.x + direction.x, current.y + direction.y)
	
	if target_position.x < 0 or target_position.y < 0:
		direction = direction.abs()
		target_position = Vector2i(current.x + direction.x, current.y + direction.y)
	

	for i in directions_v2.size():
		if target_position.x >= 0 and target_position.x < dimensions.x \
			and target_position.y >= 0 and target_position.y < dimensions.y \
			and target_position.x < dungeon_grid.size() and target_position.y < dungeon_grid[target_position.x].size() \
			and dungeon_grid[target_position.x][target_position.y].critical_path == -1:
				
				current = target_position
				dungeon_grid[target_position.x][target_position.y].critical_path = critical_path_length - length
				
				if generate_critical_path(current, length - 1):
					return true
				else:
					dungeon_grid[target_position.x][target_position.y].critical_path = -1
					current -= direction
		
		direction = Vector2i(direction.y, -direction.x)
	
	return false


func border_rooms() -> Array[DungeonRoom]:
	var rooms: Array[DungeonRoom] = []
	rooms.assign(RoomCreatorPluginUtilities\
		.flatten(dungeon_grid)\
		.filter(func(dungeon_room: DungeonRoom): return dungeon_room.is_border())
	)
	
	return rooms
	
	
func pick_random_border_room() -> Vector2i:
	var dungeon_borders: Array[Vector2i] = border_rooms()\
		.map(func(dungeon_room: DungeonRoom): return dungeon_room.grid_position())

	return dungeon_borders.pick_random()
	

func border_positions(dungeon_dimensions: Vector2i = dimensions) -> Array[Vector2i]:
	var borders: Array[Vector2i] = []
	var detect_border = func(column: int, row: int):
		if row == 0 or column == 0 or row == dungeon_dimensions.y - 1 or column == dungeon_dimensions.x - 1:
			borders.append(Vector2i(column, row))
	
	iterate_over_grid(dungeon_grid, detect_border)
	
	return borders
	

func _setup_room_doors(dungeon_room: DungeonRoom) -> void:
	var column: int = dungeon_room.column
	var row: int = dungeon_room.row
	
	var right_room: DungeonRoom = dungeon_grid[column + 1][row] if column + 1 < dimensions.x else null
	var left_room: DungeonRoom =  dungeon_grid[column - 1][row] if column - 1 >= 0 else null
	var top_room: DungeonRoom = dungeon_grid[column][row - 1] if row - 1 >= 0 else null
	var bottom_room: DungeonRoom = dungeon_grid[column][row + 1] if row + 1 < dimensions.y else null
	
	dungeon_room.room.door_in_front_wall = right_room and dungeon_room.critical_path_neighbour_of(right_room)
	dungeon_room.room.door_in_back_wall = left_room and dungeon_room.critical_path_neighbour_of(left_room)
	dungeon_room.room.door_in_left_wall = top_room and dungeon_room.critical_path_neighbour_of(top_room)
	dungeon_room.room.door_in_right_wall = bottom_room and dungeon_room.critical_path_neighbour_of(bottom_room)
	
	print("room neighbours ", right_room, left_room, top_room, bottom_room)
	print("room doors ", dungeon_room.grid_position(), dungeon_room.room.door_in_front_wall, dungeon_room.room.door_in_back_wall , dungeon_room.room.door_in_left_wall , dungeon_room.room.door_in_right_wall )
	
	
