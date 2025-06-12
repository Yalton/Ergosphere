# DownloadUIControl.gd
extends DiageticUIContent

signal download_completed

@export var download_button: Button
@export var progress_bar: TextureProgressBar
@export var status_label: Label
@export var download_time: float = 3.0

@export var enable_debug: bool = true
var module_name: String = "DownloadUIControl"

var is_downloading: bool = false
var is_download_complete: bool = false
var download_tween: Tween

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if download_button:
		download_button.pressed.connect(_on_download_button_pressed)
	else:
		DebugLogger.error(module_name, "No download button assigned!")
	
	if progress_bar:
		progress_bar.value = 0
	else:
		DebugLogger.error(module_name, "No progress bar assigned!")
	
	if status_label:
		status_label.text = "Download: not started"
	else:
		DebugLogger.error(module_name, "No status label assigned!")
	
	DebugLogger.debug(module_name, "Download UI Control initialized")

func _on_download_button_pressed() -> void:
	if is_downloading or is_download_complete:
		DebugLogger.debug(module_name, "Download already in progress or completed")
		return
	
	start_download()

func start_download() -> void:
	if not progress_bar:
		DebugLogger.error(module_name, "Cannot start download - no progress bar")
		return
	
	is_downloading = true
	
	# Disable button during download
	if download_button:
		download_button.disabled = true
	
	# Reset progress bar
	progress_bar.value = 0
	
	# Create tween for smooth progress
	download_tween = create_tween()
	download_tween.tween_method(_update_progress, 0.0, 100.0, download_time)
	download_tween.finished.connect(_on_download_finished)
	
	DebugLogger.debug(module_name, "Download started - " + str(download_time) + " seconds")

func _update_progress(value: float) -> void:
	if progress_bar:
		progress_bar.value = value
	
	if status_label:
		var percent = int(value)
		status_label.text = "Download " + str(percent) + "%"

func _on_download_finished() -> void:
	is_downloading = false
	is_download_complete = true
	
	# Disable button permanently
	if download_button:
		download_button.disabled = true
	
	# Update status
	if status_label:
		status_label.text = "Download: Completed"
	
	# Emit signal to parent diegetic UI
	download_completed.emit()
	
	DebugLogger.debug(module_name, "Download completed")

func cancel_download() -> void:
	if not is_downloading or is_download_complete:
		return
	
	if download_tween and download_tween.is_valid():
		download_tween.kill()
	
	is_downloading = false
	
	if download_button:
		download_button.disabled = false
	
	if progress_bar:
		progress_bar.value = 0
	
	if status_label:
		status_label.text = "Download: not started"
	
	DebugLogger.debug(module_name, "Download cancelled")
