# filepath: /Users/tijmenvanegmond/Developer/dekker/scripts/voxel/marching_cubes.gd
class_name MarchingCubesAlgorithm
extends RefCounted

# Angular Marching Cubes implementation for voxel-style terrain
# Uses MarchingCubesTables for lookup data

@export var angular_mode: bool = false  # Temporarily disable for testing
@export var surface_threshold: float = 0.5

# Ensure consistent surface threshold across all chunks
static var global_surface_threshold: float = 0.5

func _init():
	surface_threshold = global_surface_threshold


# Generate mesh for a voxel chunk using marching cubes
func generate_chunk_mesh(chunk) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	
	# Process all cubes in the chunk
	# The key to preventing boundary issues is ensuring consistent voxel sampling
	# across chunk boundaries. Each chunk processes all its cubes (0 to CHUNK_SIZE-1),
	# and when a cube samples voxels beyond its chunk, get_voxel_safe() provides
	# consistent values from neighbors or theoretical generation.
	for x in range(chunk.CHUNK_SIZE):
		for y in range(chunk.CHUNK_SIZE):
			for z in range(chunk.CHUNK_SIZE):
				_process_cube(chunk, x, y, z, vertices, normals)
	
	# Create and return mesh
	var mesh = ArrayMesh.new()
	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		# No indices - vertices are already in triangle order
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

# Process a single cube for marching cubes (following reference implementation)
func _process_cube(chunk, x: int, y: int, z: int, 
				   vertices: PackedVector3Array, normals: PackedVector3Array):
	
	# Get triangulation for this cube
	var triangulation = _get_triangulation(x, y, z, chunk)
	
	# Skip if no triangulation (empty or full cube)
	if triangulation.is_empty() or triangulation[0] < 0:
		return
	
	# Process triangulation in groups of 3 (each triangle)
	var i = 0
	while i < triangulation.size() and triangulation[i] >= 0:
		# Get three edge indices for this triangle
		var edge_idx_0 = triangulation[i]
		var edge_idx_1 = triangulation[i + 1] if i + 1 < triangulation.size() else -1
		var edge_idx_2 = triangulation[i + 2] if i + 2 < triangulation.size() else -1
		
		# Check if we have a complete triangle
		if edge_idx_0 < 0 or edge_idx_1 < 0 or edge_idx_2 < 0:
			break
		
		# Validate edge indices
		if (edge_idx_0 >= MarchingCubesTables.EDGES.size() or 
			edge_idx_1 >= MarchingCubesTables.EDGES.size() or 
			edge_idx_2 >= MarchingCubesTables.EDGES.size()):
			i += 3
			continue
		
		# Calculate vertices for this triangle
		var vert_0 = _get_edge_vertex(edge_idx_0, x, y, z, chunk)
		var vert_1 = _get_edge_vertex(edge_idx_1, x, y, z, chunk)
		var vert_2 = _get_edge_vertex(edge_idx_2, x, y, z, chunk)
		
		# Add vertices with corrected winding order for proper face orientation
		vertices.append(vert_2)
		vertices.append(vert_1) 
		vertices.append(vert_0)
		
		# Calculate normal for the triangle (using cross product)
		var normal = _calculate_triangle_normal(vert_2, vert_1, vert_0)
		
		# Add the same normal for all three vertices
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
		
		i += 3

# Helper function to get vertex position for an edge
func _get_edge_vertex(edge_index: int, x: int, y: int, z: int, chunk) -> Vector3:
	# Get the two points that define this edge
	var point_indices = MarchingCubesTables.EDGES[edge_index]
	var p0 = MarchingCubesTables.POINTS[point_indices.x]
	var p1 = MarchingCubesTables.POINTS[point_indices.y]
	
	# Calculate world positions
	var pos_a = Vector3(x + p0.x, y + p0.y, z + p0.z)
	var pos_b = Vector3(x + p1.x, y + p1.y, z + p1.z)
	
	# Calculate interpolated position on the edge
	return _calculate_interpolation(pos_a, pos_b, chunk)

# Calculate normal for a triangle using cross product
func _calculate_triangle_normal(v0: Vector3, v1: Vector3, v2: Vector3) -> Vector3:
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var normal = edge1.cross(edge2).normalized()
	
	# Ensure normal is valid
	if normal.length() < 0.001:
		return Vector3.UP
	
	return normal

# Get triangulation configuration for a cube (following reference implementation)
func _get_triangulation(x: int, y: int, z: int, chunk) -> Array:
	var idx = 0b00000000
	idx |= int(_sample_density(chunk, Vector3(x, y, z)) < surface_threshold) << 0
	idx |= int(_sample_density(chunk, Vector3(x, y, z+1)) < surface_threshold) << 1
	idx |= int(_sample_density(chunk, Vector3(x+1, y, z+1)) < surface_threshold) << 2
	idx |= int(_sample_density(chunk, Vector3(x+1, y, z)) < surface_threshold) << 3
	idx |= int(_sample_density(chunk, Vector3(x, y+1, z)) < surface_threshold) << 4
	idx |= int(_sample_density(chunk, Vector3(x, y+1, z+1)) < surface_threshold) << 5
	idx |= int(_sample_density(chunk, Vector3(x+1, y+1, z+1)) < surface_threshold) << 6
	idx |= int(_sample_density(chunk, Vector3(x+1, y+1, z)) < surface_threshold) << 7
	
	return MarchingCubesTables.TRIANGULATIONS[idx]

# Calculate interpolated position on edge (following reference implementation)
func _calculate_interpolation(a: Vector3, b: Vector3, chunk) -> Vector3:
	var val_a = _sample_density(chunk, a)
	var val_b = _sample_density(chunk, b)
	
	# Handle edge case where values are equal
	if abs(val_b - val_a) < 0.001:
		return (a + b) * 0.5
	
	# Calculate interpolation factor
	var t = (surface_threshold - val_a) / (val_b - val_a)
	t = clamp(t, 0.0, 1.0)
	
	if angular_mode:
		# Angular mode: snap to discrete positions for cleaner geometry
		# Round to the nearest 0.5 increment to maintain angular appearance
		var interpolated = a + t * (b - a)
		interpolated.x = round(interpolated.x * 2.0) / 2.0
		interpolated.y = round(interpolated.y * 2.0) / 2.0
		interpolated.z = round(interpolated.z * 2.0) / 2.0
		return interpolated
	else:
		# Smooth mode: standard linear interpolation
		return a + t * (b - a)

# Calculate angular normal (face-aligned)
func _calculate_angular_normal(vertex_pos: Vector3, cube_pos: Vector3) -> Vector3:
	var cube_center = cube_pos + Vector3(0.5, 0.5, 0.5)
	var to_vertex = vertex_pos - cube_center
	
	# Snap to primary axis for angular appearance
	var abs_x = abs(to_vertex.x)
	var abs_y = abs(to_vertex.y)
	var abs_z = abs(to_vertex.z)
	
	if abs_x > abs_y and abs_x > abs_z:
		return Vector3(sign(to_vertex.x), 0, 0)
	elif abs_y > abs_z:
		return Vector3(0, sign(to_vertex.y), 0)
	else:
		return Vector3(0, 0, sign(to_vertex.z))

# Calculate smooth normal using gradient
func _calculate_smooth_normal(chunk, pos: Vector3) -> Vector3:
	var epsilon = 0.1
	
	# Sample density gradient
	var dx = _sample_density(chunk, pos + Vector3(epsilon, 0, 0)) - _sample_density(chunk, pos - Vector3(epsilon, 0, 0))
	var dy = _sample_density(chunk, pos + Vector3(0, epsilon, 0)) - _sample_density(chunk, pos - Vector3(0, epsilon, 0))
	var dz = _sample_density(chunk, pos + Vector3(0, 0, epsilon)) - _sample_density(chunk, pos - Vector3(0, 0, epsilon))
	
	var gradient = Vector3(dx, dy, dz)
	return gradient.normalized() if gradient.length() > 0.001 else Vector3.UP

# Sample density at a position
func _sample_density(chunk, pos: Vector3) -> float:
	var x = int(floor(pos.x))
	var y = int(floor(pos.y))
	var z = int(floor(pos.z))
	
	var voxel_type = chunk.get_voxel_safe(x, y, z)
	return 1.0 if voxel_type > 0 else 0.0

# Check if this mesh generation might cause overlaps with neighbors
func should_generate_boundary_faces(chunk, x: int, y: int, z: int) -> bool:
	# For faces on chunk boundaries, only generate them from one side to prevent overlaps
	# This helps reduce visual seams and z-fighting
	
	# Check if we're on the positive boundary (higher coordinate side)
	var on_x_boundary = (x == chunk.CHUNK_SIZE - 1)
	var on_y_boundary = (y == chunk.CHUNK_SIZE - 1)  
	var on_z_boundary = (z == chunk.CHUNK_SIZE - 1)
	
	# If we're on a positive boundary, let the neighboring chunk handle the face
	# This prevents duplicate geometry at chunk boundaries
	if on_x_boundary or on_y_boundary or on_z_boundary:
		# Check if neighboring chunks exist
		var world = chunk.get_parent()
		if world and world.has_method("chunks"):
			var chunk_pos = chunk.chunk_position
			
			if on_x_boundary and world.chunks.has(Vector3i(chunk_pos.x + 1, chunk_pos.y, chunk_pos.z)):
				return false
			if on_y_boundary and world.chunks.has(Vector3i(chunk_pos.x, chunk_pos.y + 1, chunk_pos.z)):
				return false  
			if on_z_boundary and world.chunks.has(Vector3i(chunk_pos.x, chunk_pos.y, chunk_pos.z + 1)):
				return false
	
	return true