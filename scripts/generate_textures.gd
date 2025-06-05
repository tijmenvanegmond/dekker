@tool
extends EditorScript

# Run this script in the editor to generate default textures
func _run():
	# Load the texture generator
	var TextureGenerator = preload("res://scripts/TextureGenerator.gd")
	
	# Generate and save textures
	TextureGenerator.save_default_textures()
	
	print("Texture generation complete!")
	print("You can now assign these textures to the voxel_terrain_material.tres")
