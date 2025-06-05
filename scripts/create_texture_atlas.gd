@tool
extends EditorScript

# Creates a texture atlas for voxel materials
func _run():
	create_voxel_atlas()

func create_voxel_atlas():
	var atlas_size = 256
	var tile_size = 64
	var tiles_per_row = atlas_size / tile_size
	
	var atlas_image = Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGB8)
	
	# Generate textures for each voxel type
	var textures = [
		create_grass_pattern(tile_size),
		create_dirt_pattern(tile_size), 
		create_stone_pattern(tile_size),
		create_ore_pattern(tile_size)
	]
	
	# Place textures in atlas
	for i in range(textures.size()):
		var x_offset = (i % tiles_per_row) * tile_size
		var y_offset = (i / tiles_per_row) * tile_size
		
		atlas_image.blit_rect(textures[i], Rect2i(0, 0, tile_size, tile_size), Vector2i(x_offset, y_offset))
	
	# Save atlas
	var atlas_texture = ImageTexture.new()
	atlas_texture.set_image(atlas_image)
	
	ResourceSaver.save(atlas_texture, "res://textures/voxel_atlas.tres")
	print("Created voxel texture atlas at res://textures/voxel_atlas.tres")

func create_grass_pattern(size: int) -> Image:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	for y in range(size):
		for x in range(size):
			var noise = (sin(x * 0.3) + cos(y * 0.4)) * 0.1
			var green = 0.4 + noise + randf() * 0.1
			var color = Color(0.1, green, 0.05)
			image.set_pixel(x, y, color)
	
	return image

func create_dirt_pattern(size: int) -> Image:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	for y in range(size):
		for x in range(size):
			var noise = (sin(x * 0.5) * cos(y * 0.3)) * 0.15
			var brown = 0.35 + noise + randf() * 0.1
			var color = Color(brown, brown * 0.7, brown * 0.4)
			image.set_pixel(x, y, color)
	
	return image

func create_stone_pattern(size: int) -> Image:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	for y in range(size):
		for x in range(size):
			var noise = (sin(x * 0.2) + cos(y * 0.25)) * 0.1
			var gray = 0.5 + noise + randf() * 0.05
			var color = Color(gray, gray, gray * 1.1)
			image.set_pixel(x, y, color)
	
	return image

func create_ore_pattern(size: int) -> Image:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	for y in range(size):
		for x in range(size):
			var base_gray = 0.3 + randf() * 0.1
			var ore_chance = randf()
			var color: Color
			
			if ore_chance > 0.8:
				# Gold ore vein
				color = Color(0.8, 0.6, 0.2)
			elif ore_chance > 0.6:
				# Iron ore vein  
				color = Color(0.6, 0.4, 0.3)
			else:
				# Regular stone
				color = Color(base_gray, base_gray, base_gray)
			
			image.set_pixel(x, y, color)
	
	return image
