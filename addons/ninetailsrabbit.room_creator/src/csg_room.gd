@tool
class_name CSGRoom extends CSGCombiner3D

@export var room_size: Vector3 = Vector3.ZERO
## Defines whether it represents a room connector instead of a room itself
@export var is_bridge_room_connector : bool = false
## Generate the standard materials on new csg elements
@export var generate_materials : bool = true
@export_group("Doors")
@export var door_size: Vector3 = Vector3(1.5, 2.0, 0.25)
@export_range(1, 4, 1) var number_of_doors = 1
@export var randomize_door_position_in_wall: bool = false
@export_group("Thickness")
@export var wall_thickness: float = 0.15
@export var ceil_thickness: float = 0.1
@export var floor_thickness: float = 0.1
@export_group("Ceil columns")
@export var ceil_column_height: float = 0.6
@export var ceil_column_thickness: float = 0.5
@export_group("Corner columns")
@export var corner_column_thickness: float = 0.5
@export_group("Includes")
@export var include_ceil : bool = true
@export var include_ceil_columns : bool = false
@export var include_floor : bool = true
@export var include_right_wall : bool = true
@export var include_left_wall : bool = true
@export var include_front_wall : bool = true
@export var include_back_wall : bool = true
@export var include_corner_columns : bool = false

var floor_side: CSGShape3D
var ceil_side: CSGShape3D
var front_wall: CSGShape3D
var back_wall: CSGShape3D
var left_wall: CSGShape3D
var right_wall: CSGShape3D

var materials_by_room_part: Dictionary ##  CSGShape and the surface related index


func _enter_tree() -> void:
	if get_child_count() == 0 and not room_size.is_zero_approx():
		build()


func build() -> void:
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(self)
	
	if is_bridge_room_connector:
		name = "BridgeConnector%s" % name
		
	if include_floor:
		create_floor(room_size)
		
	if include_ceil:
		create_ceil(room_size)
		
		if include_ceil_columns:
			create_ceil_columns(room_size)
		
	if include_front_wall:
		create_front_wall(room_size)
	
	if include_back_wall:
		create_back_wall(room_size)
		
	if include_right_wall:
		create_right_wall(room_size)
		
	if include_left_wall:
		create_left_wall(room_size)
		
	if include_corner_columns:
		create_corner_columns()
	
	if is_bridge_room_connector:
		if include_front_wall and include_back_wall:
			create_door_slot_in_wall(front_wall, 1)
			create_door_slot_in_wall(back_wall, 2)
		elif include_right_wall and include_left_wall:
			create_door_slot_in_wall(right_wall, 1)
			create_door_slot_in_wall(left_wall, 2)
	else:
		for socket_number in number_of_doors:
			create_door_slot_in_random_wall(socket_number)
		
	create_materials_on_room()
		

func create_materials_on_room() -> void:
	if generate_materials:
		var shapes =  RoomCreatorPluginUtilities.get_all_children(self).filter(func(child): return child is CSGShape3D)
		var index: int = 0
		
		for shape: CSGShape3D in shapes:
			shape.material = StandardMaterial3D.new()
				
			materials_by_room_part[shape] = index
			index += 1


func generate_mesh_instance():
	var meshes = get_meshes()
	
	if meshes.size() > 1:
		var room_mesh: RoomMesh = RoomMesh.new()
		room_mesh.name = name
		room_mesh.mesh = meshes[1]
		room_mesh.position = position
		room_mesh.rotation = rotation
		room_mesh.sockets = door_sockets()
		
		return room_mesh
	
	return null

#region Getters
func walls() -> Array[CSGShape3D]:
	var result: Array[CSGShape3D] = []

	for wall: CSGShape3D in RoomCreatorPluginUtilities.remove_falsy_values([front_wall, back_wall, right_wall, left_wall]):
		result.append(wall)
	
	return result


func available_sockets() -> Array[Marker3D]:
	var markers = door_sockets().filter(func(socket: Node): return socket is Marker3D and not socket.get_meta("connected"))
	var sockets: Array[Marker3D] = []
	
	for socket: Marker3D in markers:
		sockets.append(socket)
	
	return sockets


func door_sockets() ->  Array[Marker3D]:
	var markers = RoomCreatorPluginUtilities.find_nodes_of_type(self, Marker3D.new())
	var sockets: Array[Marker3D] = []
	
	for socket: Marker3D in markers:
		sockets.append(socket)
	
	return sockets


func get_door_sloot_from_wall(wall: CSGShape3D):
	if wall:
		return wall.get_node_or_null("%sDoorSlot" % wall.name)
		
	return null
#endregion

#region Part creators
func create_door_slot_in_random_wall(socket_number: int = 1, size: Vector3 = room_size, _door_size: Vector3 = door_size) -> void:
	var available_walls = walls().filter(func(wall: CSGShape3D): return wall.name.containsn("wall") and wall.get_child_count() == 0)

	if available_walls.size() > 0:
		create_door_slot_in_wall(available_walls.pick_random(), socket_number, size, _door_size)


func create_door_slot_in_wall(wall: CSGShape3D, socket_number: int = 1, size: Vector3 = room_size, _door_size: Vector3 = door_size) -> void:
	if wall.get_child_count() == 0:
		var regex: RegEx = RegEx.new()
		regex.compile("(front|back)")
		
		var regex_result = regex.search(wall.name.to_lower()) # Front and back walls does not apply door rotation to fit in
		
		var door_position: Vector3 = Vector3(0, Vector3.DOWN.y * ( (room_size.y / 2) - (_door_size.y / 2) ), 0)
		var door_rotation: Vector3 = Vector3(0, 0 if regex_result else PI / 2, 0)
		
		if randomize_door_position_in_wall:
			if door_rotation.y != 0 and (wall.size.z - _door_size.x) > _door_size.x:
				door_position.z = (-1 if RoomCreatorPluginUtilities.chance(0.5) else 1) * randf_range(_door_size.x, (wall.size.z - _door_size.x) / 2)
			
			if door_rotation.y == 0 and (wall.size.x - _door_size.x) > _door_size.x:
				door_position.x = (-1 if RoomCreatorPluginUtilities.chance(0.5) else 1) * randf_range(_door_size.x, (wall.size.x - _door_size.x) / 2)
				
		var door_slot: CSGBox3D = CSGBox3D.new()
		door_slot.name = "%sDoorSlot" % wall.name
		door_slot.operation = CSGBox3D.OPERATION_SUBTRACTION
		door_slot.size = _door_size
		door_slot.position = door_position
		door_slot.rotation = door_rotation
		
		wall.add_child(door_slot)
		
		RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(door_slot)
		
		var room_socket: Marker3D = Marker3D.new()
		room_socket.name = "RoomSocket %d" % socket_number
		room_socket.position = Vector3(door_slot.position.x, min( (door_slot.position.y + _door_size.y / 2) + 0.1, size.y), door_slot.position.z)
		room_socket.set_meta("connected", false)
		
		match wall.name.to_lower().strip_edges():
			"frontwall":
				room_socket.position += Vector3.FORWARD * (wall_thickness / 2)
			"backwall":
				room_socket.position += Vector3.BACK * (wall_thickness / 2)
			"rightwall":
				room_socket.position += Vector3.RIGHT * (wall_thickness / 2)
			"leftwall":
				room_socket.position += Vector3.LEFT * (wall_thickness / 2)
			
		room_socket.set_meta("wall", wall.name)
				
		wall.add_child(room_socket)
		RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(room_socket)
	

func create_ceil_columns(size: Vector3 = room_size) -> void:
	var ceil_column_base: CSGShape3D = ceil_side.duplicate()
	ceil_column_base.name = "CeilColumnsInterior"
	ceil_column_base.size = Vector3(ceil_column_base.size.x - ceil_thickness,  ceil_column_height, ceil_column_base.size.z - ceil_thickness)
	
	var ceil_column_substraction: CSGShape3D = ceil_column_base.duplicate()
	ceil_column_substraction.name = "CeilColumnsExterior"
	ceil_column_substraction.operation = CSGShape3D.OPERATION_SUBTRACTION
	ceil_column_substraction.size = Vector3(size.x - ceil_column_thickness * 2, ceil_column_base.size.y + ceil_column_thickness * 2, size.z - ceil_column_thickness * 2)
	
	add_child(ceil_column_base)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(ceil_column_base)
	ceil_column_base.add_child(ceil_column_substraction)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(ceil_column_substraction)
	
	ceil_column_substraction.position = Vector3.ZERO
	ceil_column_base.position.y -= min(ceil_column_height, ceil_column_thickness) - ceil_thickness * 2
	

func create_corner_columns(size: Vector3 = room_size) -> void:
	var adjustment_thickness = corner_column_thickness / 2.0 + wall_thickness / 2.0
	var column_size: Vector3 =  Vector3(corner_column_thickness, size.y, corner_column_thickness)
	
	var top_right_column: CSGBox3D = CSGBox3D.new()
	var top_left_column: CSGBox3D = CSGBox3D.new()
	var bottom_right_column: CSGBox3D = CSGBox3D.new()
	var bottom_left_column: CSGBox3D = CSGBox3D.new()

	top_right_column.name = "TopRightCornerColumn"
	top_right_column.size = column_size
	
	add_child(top_right_column)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(top_right_column)
	top_right_column.position = Vector3( (size.x / 2.0) - adjustment_thickness, size.y / 2.0, -((size.z / 2.0) - adjustment_thickness))

	top_left_column.name = "TopLeftCornerColumn"
	top_left_column.size = column_size
	top_left_column.position = Vector3(-((size.x / 2.0) - adjustment_thickness), size.y / 2.0, -((size.z / 2.0) - adjustment_thickness))
	add_child(top_left_column)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(top_left_column)

	bottom_right_column.name = "BottomRightCornerColumn"
	bottom_right_column.size = column_size
	add_child(bottom_right_column)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(bottom_right_column)
	bottom_right_column.position = Vector3( (size.x / 2.0) - adjustment_thickness, size.y / 2.0, ((size.z / 2.0) - adjustment_thickness))

	bottom_left_column.name = "BottomLeftCornerColumn"
	bottom_left_column.size = column_size
	add_child(bottom_left_column)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(bottom_left_column)
	bottom_left_column.position = Vector3(-((size.x / 2.0) - adjustment_thickness), size.y / 2.0, ((size.z / 2.0) - adjustment_thickness))
	
	
func create_floor(size: Vector3 = room_size) -> void:
	if floor_thickness == 0:
		floor_side = CSGMesh3D.new()
		floor_side.mesh = PlaneMesh.new()
		floor_side.mesh.size = Vector2(size.x, size.z)
		floor_side.flip_faces = false
	else:
		floor_side = CSGBox3D.new()
		floor_side.size = Vector3(size.x + floor_thickness * 2, floor_thickness, size.z + floor_thickness * 2)
		
	floor_side.name = "Floor"
	floor_side.position = Vector3.ZERO
	
	add_child(floor_side)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(floor_side)


func create_ceil(size: Vector3 = room_size) -> void:
	if ceil_thickness == 0:
		ceil_side = CSGMesh3D.new()
		ceil_side.mesh = PlaneMesh.new()
		ceil_side.mesh.size = Vector2(size.x, size.z)
		ceil_side.position = Vector3(0, max(size.y, size.y - size.y / 2.5), 0)
		ceil_side.flip_faces = true
	else:
		ceil_side = CSGBox3D.new()
		ceil_side.size = Vector3(size.x + ceil_thickness * 2, ceil_thickness, size.z + ceil_thickness * 2)
		ceil_side.position = Vector3(0, max(size.y, (size.y + ceil_thickness) - size.y / 2.5), 0)
		
	ceil_side.name = "Ceil"
	
	add_child(ceil_side)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(ceil_side)


func create_front_wall(size: Vector3 = room_size) -> void:
	if wall_thickness == 0:
		front_wall = CSGMesh3D.new()
		front_wall.mesh = PlaneMesh.new()
		front_wall.mesh.size = Vector2(size.x, size.y)
		front_wall.position = Vector3(0, size.y / 2, min(-size.z / 2, -size.z / 2.5))
		front_wall.flip_faces = false
		front_wall.mesh.orientation = PlaneMesh.FACE_Z
	else:
		front_wall = CSGBox3D.new()
		front_wall.size = Vector3(size.x, size.y, wall_thickness)
		front_wall.position = Vector3(0, size.y / 2, min(-size.z / 2, -(size.z + wall_thickness) / 2.5) )
		
	front_wall.name = "FrontWall"
	
	add_child(front_wall)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(front_wall)


func create_back_wall(size: Vector3 = room_size) -> void:
	if wall_thickness == 0:
		back_wall = CSGMesh3D.new()
		back_wall.mesh = PlaneMesh.new()
		back_wall.mesh.size = Vector2(size.x, size.y)
		back_wall.position = Vector3(0, size.y / 2, max(size.z / 2, size.z / 2.5))
		back_wall.flip_faces = true
		back_wall.mesh.orientation = PlaneMesh.FACE_Z
	else:
		back_wall = CSGBox3D.new()
		back_wall.size = Vector3(size.x, size.y, wall_thickness)
		back_wall.position = Vector3(0, size.y / 2, max(size.z / 2, (size.z + wall_thickness) / 2.5) )
		
	back_wall.name = "BackWall"
	
	add_child(back_wall)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(back_wall)


func create_right_wall(size: Vector3 = room_size) -> void:
	if wall_thickness == 0:
		right_wall = CSGMesh3D.new()
		right_wall.mesh = PlaneMesh.new()
		right_wall.mesh.size = Vector2(size.z, size.y)
		right_wall.position = Vector3(max(size.x / 2, size.x / 2.5), size.y / 2, 0)
		right_wall.flip_faces = true
		right_wall.mesh.orientation = PlaneMesh.FACE_X
	else:
		right_wall = CSGBox3D.new()
		right_wall.size = Vector3(wall_thickness, size.y, size.z)
		right_wall.position = Vector3(max(size.x / 2, (size.x + wall_thickness) / 2.5) , size.y / 2, 0)
		
	right_wall.name = "RightWall"
		
	add_child(right_wall)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(right_wall)


func create_left_wall(size: Vector3 = room_size) -> void:
	if wall_thickness == 0:
		left_wall = CSGMesh3D.new()
		left_wall.mesh = PlaneMesh.new()
		left_wall.mesh.size = Vector2(size.z, size.y)
		left_wall.position = Vector3(min(-size.x / 2, -size.x / 2.5), size.y / 2, 0)
		left_wall.flip_faces = false
		left_wall.mesh.orientation = PlaneMesh.FACE_X
	else:
		left_wall = CSGBox3D.new()
		left_wall.size = Vector3(wall_thickness, size.y, size.z)
		left_wall.position = Vector3(min(-size.x / 2, (-size.x + wall_thickness) / 2.5) , size.y / 2, 0)
	
	left_wall.name = "LeftWall"
	
	add_child(left_wall)
	RoomCreatorPluginUtilities.set_owner_to_edited_scene_root(left_wall)

#endregion
