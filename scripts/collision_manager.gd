extends Node

const CELL_SIZE = 128

# Grid: Dictionary[Vector2i, Array of entities]
var grid = {}

# Entity registration
var registered_entities = {}

func _physics_process(_delta: float) -> void:
	grid.clear()

func register(entity: Node2D, entity_type: String) -> void:
	if not entity or not is_instance_valid(entity):
		return
	var cell = _pos_to_cell(entity.global_position)
	if cell not in grid:
		grid[cell] = []
	grid[cell].append({"node": entity, "type": entity_type})

func query_radius(position: Vector2, radius: float, entity_type: String = "") -> Array:
	var results = []
	var cell_radius = int(ceil(radius / CELL_SIZE)) + 1
	var center_cell = _pos_to_cell(position)

	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell = Vector2i(x, y)
			if cell not in grid:
				continue
			for entry in grid[cell]:
				if entity_type != "" and entry["type"] != entity_type:
					continue
				var node: Node2D = entry["node"]
				if not is_instance_valid(node):
					continue
				if node.global_position.distance_squared_to(position) <= radius * radius:
					results.append(node)
	return results

func query_nearest(position: Vector2, entity_type: String, max_radius: float = 800.0) -> Node2D:
	var best_node: Node2D = null
	var best_dist_sq = max_radius * max_radius
	var cell_radius = int(ceil(max_radius / CELL_SIZE)) + 1
	var center_cell = _pos_to_cell(position)

	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell = Vector2i(x, y)
			if cell not in grid:
				continue
			for entry in grid[cell]:
				if entry["type"] != entity_type:
					continue
				var node: Node2D = entry["node"]
				if not is_instance_valid(node):
					continue
				var dist_sq = node.global_position.distance_squared_to(position)
				if dist_sq < best_dist_sq:
					best_dist_sq = dist_sq
					best_node = node
	return best_node

func query_cell(position: Vector2, entity_type: String = "") -> Array:
	var results = []
	var center_cell = _pos_to_cell(position)
	for x in range(center_cell.x - 1, center_cell.x + 2):
		for y in range(center_cell.y - 1, center_cell.y + 2):
			var cell = Vector2i(x, y)
			if cell not in grid:
				continue
			for entry in grid[cell]:
				if entity_type != "" and entry["type"] != entity_type:
					continue
				if is_instance_valid(entry["node"]):
					results.append(entry["node"])
	return results

func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE)))
