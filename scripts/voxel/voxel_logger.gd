class_name VoxelLogger
extends RefCounted

# Logging system for voxel world with file output and console filtering
enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3
}

static var instance: VoxelLogger
static var log_file: FileAccess
static var console_log_level: LogLevel = LogLevel.WARNING  # Only show warnings and errors in console
static var file_log_level: LogLevel = LogLevel.DEBUG      # Log everything to file

static func get_instance() -> VoxelLogger:
	if not instance:
		instance = VoxelLogger.new()
		_init_logging()
	return instance

static func _init_logging():
	# Create logs directory in the project folder if it doesn't exist
	var project_path = ProjectSettings.globalize_path("res://")
	var logs_dir = project_path + "logs"
	
	if not DirAccess.dir_exists_absolute(logs_dir):
		DirAccess.open(project_path).make_dir("logs")
	
	# Open log file with timestamp in project logs directory
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var log_path = logs_dir + "/voxel_world_%s.log" % timestamp
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	
	if log_file:
		log_file.store_line("=== Voxel World Log Started: %s ===" % Time.get_datetime_string_from_system())
		log_file.flush()
		print("VoxelLogger: Logging to ", log_path)
	else:
		print("VoxelLogger: Failed to open log file at ", log_path)

static func write_log(level: LogLevel, category: String, message: String):
	if not log_file:
		_init_logging()
	
	var timestamp = Time.get_datetime_string_from_system()
	var level_str = ["DEBUG", "INFO", "WARN", "ERROR"][level]
	var log_line = "[%s] [%s] [%s] %s" % [timestamp, level_str, category, message]
	
	# Write to file if level is high enough
	if level >= file_log_level and log_file:
		log_file.store_line(log_line)
		log_file.flush()
	
	# Print to console if level is high enough
	if level >= console_log_level:
		print(log_line)

static func debug(category: String, message: String):
	write_log(LogLevel.DEBUG, category, message)

static func info(category: String, message: String):
	write_log(LogLevel.INFO, category, message)

static func warning(category: String, message: String):
	write_log(LogLevel.WARNING, category, message)

static func error(category: String, message: String):
	write_log(LogLevel.ERROR, category, message)

static func set_console_level(level: LogLevel):
	console_log_level = level
	info("LOGGER", "Console log level set to: " + ["DEBUG", "INFO", "WARNING", "ERROR"][level])

static func set_file_level(level: LogLevel):
	file_log_level = level
	info("LOGGER", "File log level set to: " + ["DEBUG", "INFO", "WARNING", "ERROR"][level])

static func close_log():
	if log_file:
		log_file.store_line("=== Voxel World Log Ended: %s ===" % Time.get_datetime_string_from_system())
		log_file.close()
		log_file = null
