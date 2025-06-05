@tool
extends RefCounted
class_name TextureGenerator

# Simple procedural texture generator for voxel materials
static func create_grass_texture(size: int = 64) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	for y in range(size):
		for x in range(size):
			# Create grass-like pattern
			var noise_val = (sin(x * 0.5) + cos(y * 0.3)) * 0.1
			var base_green = 0.3 + noise_val
			var green_variation = randf_range(-0.1, 0.1)
			
			var color = Color(
				0.1 + green_variation * 0.5,
				base_green + green_variation,
				0.05 + green_variation * 0.3
			)
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

static func create_dirt_texture(size: int = 64) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	for y in range(size):
		for x in range(size):
			# Create dirt-like pattern
			var noise_val = (sin(x * 0.7) * cos(y * 0.5)) * 0.1
			var base_brown = 0.4 + noise_val
			var brown_variation = randf_range(-0.1, 0.1)
			
			var color = Color(
				base_brown + brown_variation,
				(base_brown + brown_variation) * 0.7,
				(base_brown + brown_variation) * 0.4
			)
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

static func create_stone_texture(size: int = 64) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	for y in range(size):
		for x in range(size):
			# Create stone-like pattern
			var noise_val = (sin(x * 0.3) + cos(y * 0.4) + sin((x + y) * 0.2)) * 0.05
			var base_gray = 0.5 + noise_val
			var gray_variation = randf_range(-0.05, 0.05)
			
			var gray_val = base_gray + gray_variation
			var color = Color(gray_val, gray_val, gray_val * 1.1)
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

static func save_default_textures():
	# Save textures to the textures folder
	var grass_texture = create_grass_texture(128)
	var dirt_texture = create_dirt_texture(128)
	var stone_texture = create_stone_texture(128)
	
	ResourceSaver.save(grass_texture, "res://textures/grass.tres")
	ResourceSaver.save(dirt_texture, "res://textures/dirt.tres")
	ResourceSaver.save(stone_texture, "res://textures/stone.tres")
	
	print("Generated and saved default voxel textures")
