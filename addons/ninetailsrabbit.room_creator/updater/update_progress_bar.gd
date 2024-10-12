@tool
extends ConfirmationDialog

signal update_finished

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var progress_content: RichTextLabel = %message
@onready var progress_bar: TextureProgressBar = %progress

var download_url: String = ""

func _process(_delta :float) -> void:
	if progress_content != null and progress_content.is_visible_in_tree():
		progress_content.queue_redraw()


func _enter_tree() -> void:
	hide()


func _ready() -> void:
	title = "Update %s to new version" % MyPluginSettings.PluginName

	set_process(false)
	
	if not http_request.request_completed.is_connected(on_http_request_request_completed):
		http_request.request_completed.connect(on_http_request_request_completed)
		

@warning_ignore("return_value_discarded")
func run_update(progress_steps: int = 5, message: String = "Press 'Start Update' to start!") -> void:
	if PluginUtilities.is_valid_url(download_url):
		show()
		set_process(true)
		get_cancel_button().disabled = true
		get_ok_button().disabled = true
		
		create_message_on_progress_bar(message)
		init_progress(progress_steps)
		
		await update_progress("Downloading Release...")
		download_release()
		
	else:
		push_warning("%s: The url %s is not valid, aborting download of the update..." % [MyPluginSettings.PluginName, download_url])
		get_cancel_button().disabled = false
		hide()
		reset_progress_bars()


func init_progress(max_value : int) -> void:
	progress_bar.max_value = max_value
	progress_bar.value = 1


func update_progress(message: String, color: Color = Color.GREEN) -> void:
	create_message_on_progress_bar(message, color)
	progress_bar.value += 1
	
	await get_tree().create_timer(1.0).timeout


func create_message_on_progress_bar(message: String, color: Color = Color.GREEN) -> void:
	progress_content.clear()
	progress_content.append_text("[font_size=14][color=#%s]%s[/color][/font_size]" % [color.to_html(), message])
	 

func reset_progress_bars() -> void:
	progress_bar.value = 1
	progress_content.text = ""
	
	
func download_release() -> void:
	http_request.request(download_url)


func extract_release_zip() -> bool:
	var zip_reader : ZIPReader = ZIPReader.new()
	var zip_error: Error = zip_reader.open(MyPluginSettings.PluginTemporaryReleaseFilePath)
	
	if zip_error != OK:
		push_error("Extracting `%s` failed! Please collect the error log and report this. Error Code: %s" % [MyPluginSettings.PluginTemporaryReleaseFilePath, zip_error])
		update_progress("Extracting `%s` failed! Please collect the error log and report this. Error Code: %s" % [MyPluginSettings.PluginTemporaryReleaseFilePath, zip_error], Color.RED)
		
		return false
	
	var downloaded_version_files: PackedStringArray = zip_reader.get_files()
	
	var archive_path := downloaded_version_files[0]
	downloaded_version_files.remove_at(0)

	for release_version_file: String in downloaded_version_files:
		var new_file_path: String = MyPluginSettings.PluginTemporaryReleaseUpdateDirectoryPath + "/" + release_version_file.replace(archive_path, "")
		
		if release_version_file.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(new_file_path)
			continue
			
		var file: FileAccess = FileAccess.open(new_file_path, FileAccess.WRITE)
		file.store_buffer(zip_reader.read_file(release_version_file))
		
	zip_reader.close()
	
	return true


func enable_plugin() -> void:
	EditorInterface.set_plugin_enabled(MyPluginSettings.PluginPrefixName, true)
	
	var enabled_plugins := PackedStringArray()
	
	if ProjectSettings.has_setting("editor_plugins/enabled"):
		enabled_plugins = ProjectSettings.get_setting("editor_plugins/enabled")
		
	if not enabled_plugins.has(MyPluginSettings.PluginLocalConfigFilePath):
		enabled_plugins.append(MyPluginSettings.PluginLocalConfigFilePath)
		
	ProjectSettings.set_setting("editor_plugins/enabled", enabled_plugins)
	ProjectSettings.save()


func on_confirmed() -> void:
	await run_update(7)
	

func on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("An http error %d happened, update could not be done, release cannot be retrieved from GitHub!" % result)
		await update_progress("Failed update, aborting...", Color.RED)
		get_cancel_button().disabled = false
		queue_free()
		
		return
	
	await update_progress("Saving release into temporary path %s " %  MyPluginSettings.PluginTemporaryReleaseFilePath)
	
	var downloaded_version: FileAccess = FileAccess.open(MyPluginSettings.PluginTemporaryReleaseFilePath, FileAccess.WRITE)
	downloaded_version.store_buffer(body)
	downloaded_version.close()
	
	if FileAccess.file_exists(MyPluginSettings.PluginTemporaryReleaseFilePath):
		await update_progress("Extracting release into %s " % MyPluginSettings.PluginTemporaryReleaseUpdateDirectoryPath)
		
		if extract_release_zip():
			await update_progress("Uninstalling %s ..." % MyPluginSettings.PluginName)
			
			EditorInterface.set_plugin_enabled(MyPluginSettings.PluginPrefixName, false)
			
			if MyPluginSettings.DebugMode:
				if DirAccess.dir_exists_absolute(MyPluginSettings.PluginDebugDirectoryPath):
					PluginUtilities.remove_files_recursive(MyPluginSettings.PluginDebugDirectoryPath)
			else:
				PluginUtilities.remove_files_recursive(MyPluginSettings.PluginBasePath)
				
			EditorInterface.get_resource_filesystem().scan()
			
			await update_progress("Installing new %s version ..." % MyPluginSettings.PluginName)
			
			if MyPluginSettings.DebugMode:
				if not DirAccess.dir_exists_absolute(MyPluginSettings.PluginDebugDirectoryPath):
					DirAccess.make_dir_absolute(MyPluginSettings.PluginDebugDirectoryPath)
				PluginUtilities.copy_directory_recursive(MyPluginSettings.PluginTemporaryReleaseUpdateDirectoryPath, MyPluginSettings.PluginDebugDirectoryPath)
			else:
				PluginUtilities.copy_directory_recursive(MyPluginSettings.PluginTemporaryReleaseUpdateDirectoryPath, "res://")
				
			EditorInterface.get_resource_filesystem().scan()
			
			await update_progress("New %s version successfully installed, Restarting Godot ..." % MyPluginSettings.PluginName)
			await get_tree().create_timer(2).timeout
			
			if FileAccess.file_exists(MyPluginSettings.PluginTemporaryReleaseFilePath):
				DirAccess.remove_absolute(MyPluginSettings.PluginTemporaryReleaseFilePath)
				
			EditorInterface.get_resource_filesystem().scan()
			enable_plugin()
			hide()
			update_finished.emit()
