class_name VoxelMeshGenerator
extends RefCounted

# Mesh generation for voxel chunks using marching cubes approach
const VERTICES_PER_QUAD = 6

# Cube face vertices (for simple cubic voxels)
const FACE_VERTICES = [
	# Front face (positive Z)
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	# Back face (negative Z)
	[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)],
	# Right face (positive X)
	[Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)],
	# Left face (negative X)
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	# Top face (positive Y)
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
	# Bottom face (negative Y)
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]
]

const FACE_NORMALS = [
	Vector3(0, 0, 1),   # Front
	Vector3(0, 0, -1),  # Back
	Vector3(1, 0, 0),   # Right
	Vector3(-1, 0, 0),  # Left
	Vector3(0, 1, 0),   # Top
	Vector3(0, -1, 0)   # Bottom
]

const FACE_DIRECTIONS = [
	Vector3i(0, 0, 1),   # Front
	Vector3i(0, 0, -1),  # Back
	Vector3i(1, 0, 0),   # Right
	Vector3i(-1, 0, 0),  # Left
	Vector3i(0, 1, 0),   # Top
	Vector3i(0, -1, 0)   # Bottom
]

func generate_chunk_mesh(chunk: VoxelChunk) -> Array:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_count = 0
	
	for x in range(chunk.CHUNK_SIZE):
		for y in range(chunk.CHUNK_SIZE):
			for z in range(chunk.CHUNK_SIZE):
				if not chunk.is_voxel_solid(x, y, z):
					continue
				
				# Check each face of the voxel
				for face_index in range(6):
					var neighbor_pos = Vector3i(x, y, z) + FACE_DIRECTIONS[face_index]
					
					# Only create face if neighbor is air or outside chunk
					if not chunk.is_voxel_solid(neighbor_pos.x, neighbor_pos.y, neighbor_pos.z):
						add_face(vertices, normals, uvs, indices, 
								Vector3(x, y, z), face_index, vertex_count, chunk.get_voxel(x, y, z))
						vertex_count += 4
	
	if vertices.size() == 0:
		return []
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	return arrays

func add_face(vertices: PackedVector3Array, normals: PackedVector3Array, 
			  uvs: PackedVector2Array, indices: PackedInt32Array,
			  voxel_pos: Vector3, face_index: int, vertex_offset: int, voxel_type: int):
	
	var face_verts = FACE_VERTICES[face_index]
	var face_normal = FACE_NORMALS[face_index]
	
	# Add vertices
	for i in range(4):
		var vert = voxel_pos + face_verts[i]
		vertices.append(vert)
		normals.append(face_normal)
		
		# Simple UV mapping based on voxel type
		var uv = Vector2(float(i % 2), float(i / 2))
		# Offset UV based on voxel type for texture atlas
		uv.x += float(voxel_type - 1) * 0.25  # Assume 4 textures per row
		uvs.append(uv)
	
	# Add triangles (two triangles per quad)
	var base_index = vertex_offset
	# First triangle
	indices.append(base_index)
	indices.append(base_index + 1)
	indices.append(base_index + 2)
	
	# Second triangle
	indices.append(base_index)
	indices.append(base_index + 2)
	indices.append(base_index + 3)
