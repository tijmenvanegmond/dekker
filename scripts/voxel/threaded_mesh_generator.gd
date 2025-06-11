class_name ThreadedMeshGenerator
extends RefCounted

# Threaded mesh generation system for voxel chunks
# Generates meshes from voxel data in background threads

signal mesh_generated(chunk_position: Vector3i, mesh_arrays: Array)

var thread_pool: Array[Thread] = []
var generation_queue: Array[Dictionary] = []
var active_generations: Dictionary = {}  # chunk_pos -> thread_id
var queue_mutex: Mutex = Mutex.new()
var should_exit: bool = false

# Shared marching cubes instance per thread
var marching_cubes_instances: Array[MarchingCubesAlgorithm] = []

const MAX_THREADS = 4
const MAX_QUEUE_SIZE = 16

func _init():
	_setup_marching_cubes_instances()
	_setup_thread_pool()

func _setup_marching_cubes_instances():
	# Create one marching cubes instance per thread to avoid conflicts
	for i in MAX_THREADS:
		var mc = MarchingCubesAlgorithm.new()
		mc.angular_mode = false  # Smooth mode for better performance
		marching_cubes_instances.append(mc)

func _setup_thread_pool():
	Logger.info("MESH_GEN", "Setting up " + str(MAX_THREADS) + " mesh generation threads")
	
	for i in MAX_THREADS:
		var thread = Thread.new()
		thread_pool.append(thread)
		thread.start(_mesh_worker_thread.bind(i))

func queue_mesh_generation(chunk_position: Vector3i, voxel_data: Array[int], chunk_ref: VoxelChunk, priority: int = 0):
	queue_mutex.lock()
	
	# Check if already queued or generating
	if _is_chunk_queued_or_generating(chunk_position):
		queue_mutex.unlock()
		return
	
	# Don't exceed queue size
	if generation_queue.size() >= MAX_QUEUE_SIZE:
		# Remove lowest priority item
		var lowest_priority_idx = 0
		for i in generation_queue.size():
			if generation_queue[i].priority < generation_queue[lowest_priority_idx].priority:
				lowest_priority_idx = i
		generation_queue.remove_at(lowest_priority_idx)
	
	# Add to queue
	var generation_data = {
		"chunk_position": chunk_position,
		"voxel_data": voxel_data,
		"chunk_ref": chunk_ref,  # Keep reference for neighbor access
		"priority": priority,
		"timestamp": Time.get_ticks_msec()
	}
	
	generation_queue.append(generation_data)
	
	# Sort by priority (higher priority first)
	generation_queue.sort_custom(func(a, b): return a.priority > b.priority)
	
	queue_mutex.unlock()

func _is_chunk_queued_or_generating(chunk_position: Vector3i) -> bool:
	# Check if generating
	if active_generations.has(chunk_position):
		return true
	
	# Check if queued
	for item in generation_queue:
		if item.chunk_position == chunk_position:
			return true
	
	return false

func _mesh_worker_thread(thread_id: int):
	Logger.debug("MESH_GEN", "Mesh worker thread " + str(thread_id) + " started")
	
	while not should_exit:
		var work_item = _get_next_work_item(thread_id)
		
		if work_item == null:
			# No work available, sleep briefly
			OS.delay_msec(10)
			continue
		
		# Generate mesh for this chunk
		var chunk_position = work_item.chunk_position
		var voxel_data = work_item.voxel_data
		var chunk_ref = work_item.chunk_ref
		
		Logger.debug("MESH_GEN", "Thread " + str(thread_id) + " generating mesh for chunk " + str(chunk_position))
		
		var mesh_arrays = _generate_chunk_mesh(chunk_position, voxel_data, chunk_ref, thread_id)
		
		# Mark as complete
		queue_mutex.lock()
		active_generations.erase(chunk_position)
		queue_mutex.unlock()
		
		# Signal completion (must be called on main thread)
		call_deferred("_emit_mesh_generated", chunk_position, mesh_arrays)

func _get_next_work_item(thread_id: int):
	queue_mutex.lock()
	
	var work_item = null
	if generation_queue.size() > 0:
		work_item = generation_queue.pop_front()
		active_generations[work_item.chunk_position] = thread_id
	
	queue_mutex.unlock()
	return work_item

func _emit_mesh_generated(chunk_position: Vector3i, mesh_arrays: Array):
	mesh_generated.emit(chunk_position, mesh_arrays)

func _generate_chunk_mesh(chunk_position: Vector3i, voxel_data: Array[int], chunk_ref: VoxelChunk, thread_id: int) -> Array:
	# Create a temporary chunk-like object for mesh generation
	var temp_chunk = ThreadedChunkData.new()
	temp_chunk.chunk_position = chunk_position
	temp_chunk.voxel_data = voxel_data
	temp_chunk.world_ref = chunk_ref.get_parent() if chunk_ref else null
	
	# Use thread-specific marching cubes instance
	var mc = marching_cubes_instances[thread_id]
	var mesh = mc.generate_chunk_mesh(temp_chunk)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	if mesh and mesh.get_surface_count() > 0:
		arrays = mesh.surface_get_arrays(0)
	
	return arrays

func get_debug_info() -> Dictionary:
	queue_mutex.lock()
	var info = {
		"queue_size": generation_queue.size(),
		"active_generations": active_generations.size(),
		"max_threads": MAX_THREADS,
		"max_queue_size": MAX_QUEUE_SIZE
	}
	queue_mutex.unlock()
	return info

func shutdown():
	Logger.info("MESH_GEN", "Shutting down...")
	should_exit = true
	
	# Wait for all threads to finish
	for thread in thread_pool:
		if thread.is_started():
			thread.wait_to_finish()
	
	thread_pool.clear()
	marching_cubes_instances.clear()
	Logger.info("MESH_GEN", "Shutdown complete")

# Helper class to hold chunk data for threaded mesh generation
class ThreadedChunkData extends RefCounted:
	var chunk_position: Vector3i
	var voxel_data: Array[int]
	var world_ref: Node3D
	
	const CHUNK_SIZE = 16
	
	func get_voxel(x: int, y: int, z: int) -> int:
		if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
			return 0
		
		var index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
		return voxel_data[index]
	
	func get_voxel_safe(x: int, y: int, z: int) -> int:
		# Safe voxel access with bounds checking and neighbor chunk sampling
		if x >= 0 and x < CHUNK_SIZE and y >= 0 and y < CHUNK_SIZE and z >= 0 and z < CHUNK_SIZE:
			return get_voxel(x, y, z)
		
		# For out-of-bounds access, try to get from world
		if world_ref and world_ref.has_method("get_voxel_world_pos"):
			var world_x = chunk_position.x * CHUNK_SIZE + x
			var world_y = chunk_position.y * CHUNK_SIZE + y
			var world_z = chunk_position.z * CHUNK_SIZE + z
			return world_ref.get_voxel_world_pos(world_x, world_y, world_z)
		
		return 0  # Return air/empty if no neighbor available
