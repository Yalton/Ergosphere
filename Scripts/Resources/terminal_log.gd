extends Resource
class_name TerminalLog

## Resource that contains a terminal log entry

## The title of the log entry
@export var log_title: String = "Log Entry"

## The full content of the log
@export_multiline var log_content: String = ""

## Whether this log is locked initially
@export var is_locked: bool = false

## Whether this log requires the session password to access
@export var password_protected: bool = false

## State requirement to unlock this log (if locked)
@export_group("Unlock Requirements")
## The state name to check for unlocking
@export var unlock_state_name: String = ""
## The value the state must have to unlock
@export var unlock_state_value: Variant = true
## Custom unlock message when locked
@export var locked_message: String = "Access Denied - Insufficient Clearance"

## Optional metadata
@export_group("Metadata")
## Date/time stamp for the log
@export var log_date: String = ""
## Author of the log
@export var log_author: String = ""
## Security level (for display purposes)
@export var security_level: String = "PUBLIC"

func is_accessible() -> bool:
	if not is_locked:
		return true
		
	# Check unlock state if locked
	if unlock_state_name.is_empty():
		return false
		
	if GameManager and GameManager.state_manager:
		var current_value = GameManager.state_manager.get_state(unlock_state_name)
		return current_value == unlock_state_value
	
	return false

func get_formatted_content() -> String:
	var formatted = ""
	
	# Add header
	formatted += "=== " + log_title + " ===\n"
	
	# Add metadata if available
	if not log_author.is_empty():
		formatted += "Author: " + log_author + "\n"
	if not log_date.is_empty():
		formatted += "Date: " + log_date + "\n"
	if not security_level.is_empty():
		formatted += "Security Level: " + security_level + "\n"
	
	formatted += "\n" + log_content
	
	return formatted
