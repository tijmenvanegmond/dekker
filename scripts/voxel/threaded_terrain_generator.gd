class_name ThreadedTerrainGenerator
extends RefCounted

# Threaded terrain generation system for voxel chunks
# Generates voxel data in background threads

signal terrain_generated(chunk_position: Vector3i, voxel_data: Array[int])

var thread_pool: Array[Thread] = []
var generation_queue: Array[Dictionary] = []
var active_generations: Dictionary = {}  # chunk_pos -> thread_id
var queue_mutex: Mutex = Mutex.new()
var should_exit: bool = false

const MAX_THREADS = 4
const MAX_QUEUE_SIZE = 16

func _init():
	_setup_thread_pool()

func _setup_thread_pool():
	VoxelLogger.info("TERRAIN_GEN", "Setting up " + str(MAX_THREADS) + " terrain generation threads")
	
	for i in MAX_THREADS:
		var thread = Thread.new()
		thread_pool.append(thread)
		thread.start(_terrain_worker_thread.bind(i))

func queue_terrain_generation(chunk_position: Vector3i, priority: int = 0):
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

func _terrain_worker_thread(thread_id: int):
	VoxelLogger.debug("TERRAIN_GEN", "Terrain worker thread " + str(thread_id) + " started")
	
	while not should_exit:
		var work_item = _get_next_work_item(thread_id)
		
		if work_item == null:
			# No work available, sleep briefly
			OS.delay_msec(10)
			continue
		
		# Generate terrain for this chunk
		var chunk_position = work_item.chunk_position
		VoxelLogger.debug("TERRAIN_GEN", "Thread " + str(thread_id) + " generating terrain for chunk " + str(chunk_position))
		
		var voxel_data = _generate_chunk_terrain(chunk_position)
		
		# Mark as complete
		queue_mutex.lock()
		active_generations.erase(chunk_position)
		queue_mutex.unlock()
		
		# Signal completion (must be called on main thread)
		call_deferred("_emit_terrain_generated", chunk_position, voxel_data)

func _get_next_work_item(thread_id: int):
	queue_mutex.lock()
	
	var work_item = null
	if generation_queue.size() > 0:
		work_item = generation_queue.pop_front()
		active_generations[work_item.chunk_position] = thread_id
	
	queue_mutex.unlock()
	return work_item

func _emit_terrain_generated(chunk_position: Vector3i, voxel_data: Array[int]):
	terrain_generated.emit(chunk_position, voxel_data)

func _generate_chunk_terrain(chunk_position: Vector3i) -> Array[int]:
	const CHUNK_SIZE = 16
	
	var voxel_data: Array[int] = []
	voxel_data.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	voxel_data.fill(0)
	
	# Generate terrain using the same logic as VoxelChunk
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var world_x = chunk_position.x * CHUNK_SIZE + x
			var world_z = chunk_position.z * CHUNK_SIZE + z
			
			var height = _generate_height(world_x, world_z)
			height = clamp(height, 0, CHUNK_SIZE - 1)
			
			for y in range(int(height)):
				var world_y = chunk_position.y * CHUNK_SIZE + y
				var voxel_type = _get_voxel_type(world_x, world_y, world_z, height)
				var index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
				voxel_data[index] = voxel_type
	
	return voxel_data

func _generate_height(world_x: int, world_z: int) -> float:
	# Base height using sine waves
	var base_height = 8.0 + 4.0 * sin(world_x * 0.1) * cos(world_z * 0.1)
	
	# Add some noise for variation
	var noise1 = sin(world_x * 0.05) * cos(world_z * 0.07) * 2.0
	var noise2 = sin(world_x * 0.02 + world_z * 0.03) * 1.5
	var noise3 = sin(world_x * 0.15) * sin(world_z * 0.12) * 0.5
	
	return base_height + noise1 + noise2 + noise3

func _get_voxel_type(world_x: int, world_y: int, world_z: int, surface_height: float) -> int:
	# More sophisticated material assignment
	var depth_from_surface = surface_height - world_y
	
	if depth_from_surface < 1.0:
		return 1  # Grass (top layer)
	elif depth_from_surface < 4.0:
		return 2  # Dirt (sub-surface)
	else:
		# Add some ore veins in deep stone - use world coordinates for consistency
		var ore_noise = sin(world_x * 0.3) * cos(world_y * 0.25) * sin(world_z * 0.35)
		if ore_noise > 0.7:
			return 4  # Could be ore or special stone
		return 3  # Regular stone

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

func get_stats() -> Dictionary:
	# Alias for get_debug_info for DebugUI compatibility
	return get_debug_info()

func shutdown():
	VoxelLogger.info("TERRAIN_GEN", "Shutting down...")
	should_exit = true
	
	# Wait for all threads to finish
	for thread in thread_pool:
		if thread.is_started():
			thread.wait_to_finish()
	
	thread_pool.clear()
	VoxelLogger.info("TERRAIN_GEN", "Shutdown complete")
