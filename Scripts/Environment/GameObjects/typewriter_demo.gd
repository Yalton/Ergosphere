extends Node

# RetroTerminalLogs - Comprehensive retrofuturistic terminal log system
# Includes different categories of logs that can be selected

@export var typewriter: TypewriterEffect
@export var years_in_future: int = 100  # How many years to add to current date
@export_enum("General", "Narrative", "Cybernetic", "Navigation", "Food", "Weather") var log_category: int = 0

# Array of general terminal logs
var general_logs: Array[String] = [
	"[TIMESTAMP][THOTH-OS] System boot sequence initiated on terminal THX-1138...",
	"[TIMESTAMP][BIOS v9.5] 64K RAM SYSTEM  38911 BASIC BYTES FREE",
	"[TIMESTAMP][FLUXCOMP] Initializing quantum flux capacitors...",
	"[TIMESTAMP][DRIVE-A:] Diagnostics on holographic storage drive A: starting...",
	"[TIMESTAMP][DRIVE-A:] Holographic crystal integrity: 99.7% - ACCEPTABLE",
	"[TIMESTAMP][SYS] Loading THOTH-DOS v6.502...",
	"[TIMESTAMP][MEMORY] Testing memory banks... 64K OK",
	"[TIMESTAMP][MEMORY] Extended quantum memory detected: 128Q OK",
	"[TIMESTAMP][CHRONOS] Synchronizing with atomic timebase...",
	"[TIMESTAMP][CHRONOS] Temporal variance detected: 0.0003ms - ACCEPTABLE",
	"[TIMESTAMP][MODEM] Initializing tachyon modem...",
	"[TIMESTAMP][MODEM] Establishing connection to THOTHNET at 9600 BAUD...",
	"[TIMESTAMP][MODEM] CONNECT 9600bd",
	"[TIMESTAMP][SECURITY] Biometric handshake required...",
	"[TIMESTAMP][SECURITY] Identity confirmed: Dr. Eliza Harper",
	"[TIMESTAMP][ADMIN] Welcome to THOTH-OS v3.14, Dr. Harper",
	"[TIMESTAMP][SYS] Loading user preferences from PROFILE.DAT",
	"[TIMESTAMP][DAEMON] Starting background processes...",
	"[TIMESTAMP][DAEMON] Temporal monitoring active",
	"[TIMESTAMP][DAEMON] Crypto-shield enabled",
	"[TIMESTAMP][DAEMON] Quantum entanglement tracker online",
	"[TIMESTAMP][AUDIO] Initializing audio synthesizer chip...",
	"[TIMESTAMP][AUDIO] POKEY-2125 sound module ready",
	"[TIMESTAMP][DISPLAY] CRT phosphor warming up...",
	"[TIMESTAMP][DISPLAY] Setting resolution to 80x25 characters",
	"[TIMESTAMP][DISPLAY] Monochromatic amber display initialized",
	"[TIMESTAMP][NETWORK] Connecting to orbital mainframe...",
	"[TIMESTAMP][NETWORK] Connection established via ansible link",
	"[TIMESTAMP][NETWORK] Transfer rate: 1.21 gigaquads per second"
]

# Array of narrative-driven logs
var narrative_logs: Array[String] = [
	"[TIMESTAMP][AMIGA-9000] KICKSTART 47.11 ROM LOADED",
	"[TIMESTAMP][AMIGA-9000] QUANTUM ACCELERATOR DETECTED",
	"[TIMESTAMP][AMIGA-9000] 4096K CHIP RAM INSTALLED",
	"[TIMESTAMP][AMIGA-9000] 16384K FAST RAM INSTALLED",
	"[TIMESTAMP][AMIGA-9000] HOLODISK DRIVE DF0: ONLINE",
	"[TIMESTAMP][AMIGA-9000] LOADING LUNAR COLONY OS 3.9...",
	"[TIMESTAMP][LC-SECURITY] BIOMETRIC SCAN REQUIRED...",
	"[TIMESTAMP][LC-SECURITY] ANALYZING RETINAL PATTERN...",
	"[TIMESTAMP][LC-SECURITY] USER IDENTIFIED: CMDR HAYES, THOMAS J.",
	"[TIMESTAMP][LC-ADMIN] WELCOME COMMANDER HAYES",
	"[TIMESTAMP][LC-ADMIN] LAST LOGIN: YESTERDAY FROM TERMINAL GAMMA-7",
	"[TIMESTAMP][LC-COMMS] 3 PRIORITY MESSAGES WAITING",
	"[TIMESTAMP][LC-COMMS] OPENING MESSAGE 1 OF 3...",
	"[TIMESTAMP][LC-COMMS] FROM: LUNAR CONTROL",
	"[TIMESTAMP][LC-COMMS] SUBJECT: ANOMALY IN SECTOR 7",
	"[TIMESTAMP][LC-COMMS] BODY: Unusual energy signature detected in Mare Tranquillitatis. Please investigate.",
	"[TIMESTAMP][LC-COMMS] END OF MESSAGE 1",
	"[TIMESTAMP][LC-COMMS] OPENING MESSAGE 2 OF 3...",
	"[TIMESTAMP][LC-COMMS] FROM: DR. KENZO NAKAMURA",
	"[TIMESTAMP][LC-COMMS] SUBJECT: PROJECT PROMETHEUS UPDATE",
	"[TIMESTAMP][LC-COMMS] BODY: The quantum resonance cascade is stable. Ready for Phase II testing.",
	"[TIMESTAMP][LC-COMMS] END OF MESSAGE 2",
	"[TIMESTAMP][LC-COMMS] OPENING MESSAGE 3 OF 3...",
	"[TIMESTAMP][LC-COMMS] FROM: UNKNOWN SENDER",
	"[TIMESTAMP][LC-COMMS] SUBJECT: URGENT - TIME SENSITIVE",
	"[TIMESTAMP][LC-COMMS] BODY: T̷̨̧h̸̖̩ȩ̶̩ÿ̵̨'̵͙̼r̶̖͔e̷͓͘ ̶̦̈c̸̲̍o̸̧̾m̵̢̀i̵̠̎ñ̸̥g̵̮̅",
	"[TIMESTAMP][LC-COMMS] END OF MESSAGE 3",
	"[TIMESTAMP][LC-ALERT] WARNING: POSSIBLE DATA CORRUPTION IN MESSAGE 3"
]

# Cybernetic maintenance terminal logs
var cybernetic_logs: Array[String] = [
	"[TIMESTAMP][CYBERDOC-8086] INITIALIZING NEURAL INTERFACE DIAGNOSTICS",
	"[TIMESTAMP][CYBERDOC-8086] CONNECTING TO PATIENT CYBERNETICS...",
	"[TIMESTAMP][CYBERDOC-8086] PATIENT ID: CY-2977-DELTA",
	"[TIMESTAMP][CYBERDOC-8086] MODEL: ARASAKA MILITECH MK.IV NEURAL AUGMENT",
	"[TIMESTAMP][CYBERDOC-8086] FIRMWARE: v7.5.2.91",
	"[TIMESTAMP][CYBERDOC-8086] CHECKING NEURAL PATHWAYS...",
	"[TIMESTAMP][CYBERDOC-8086] MEMORY IMPLANT: 89% EFFICIENCY",
	"[TIMESTAMP][CYBERDOC-8086] OPTICAL ENHANCEMENT: 94% EFFICIENCY",
	"[TIMESTAMP][CYBERDOC-8086] REFLEX AUGMENTOR: 78% EFFICIENCY - MAINTENANCE RECOMMENDED",
	"[TIMESTAMP][CYBERDOC-8086] WARNING: REJECTION DETECTED IN SPINAL INTERFACE",
	"[TIMESTAMP][CYBERDOC-8086] ADMINISTERING ANTI-REJECTION COMPOUND...",
	"[TIMESTAMP][CYBERDOC-8086] PRESCRIBING SYNTHCORTEX-5 FOR DAILY USE"
]

# Navigation computer logs
var navigation_logs: Array[String] = [
	"[TIMESTAMP][NAVCOM-64] ASTROGATION SYSTEM ONLINE",
	"[TIMESTAMP][NAVCOM-64] CURRENT LOCATION: MARS ORBIT - PHOBOS STATION",
	"[TIMESTAMP][NAVCOM-64] CALCULATING JUPITER TRAJECTORY...",
	"[TIMESTAMP][NAVCOM-64] STELLAR INTERFERENCE DETECTED - RECALIBRATING",
	"[TIMESTAMP][NAVCOM-64] SOLAR FLARE WARNING: RADIATION SHIELDS RECOMMENDED",
	"[TIMESTAMP][NAVCOM-64] DOWNLOADING LATEST ASTEROID BELT CARTOGRAPHY",
	"[TIMESTAMP][NAVCOM-64] FUEL EFFICIENCY: 87.32%",
	"[TIMESTAMP][NAVCOM-64] ESTIMATED JOURNEY TIME: 47 DAYS 13 HOURS",
	"[TIMESTAMP][NAVCOM-64] GRAVITY ASSIST CALCULATED FOR EUROPA APPROACH",
	"[TIMESTAMP][NAVCOM-64] CHECKING CRYOSLEEP PODS FOR 3-PERSON CREW"
]

# Food production logs
var food_logs: Array[String] = [
	"[TIMESTAMP][FOODCOMP-80] PROTEIN SYNTHESIS CHAMBER ONLINE",
	"[TIMESTAMP][FOODCOMP-80] NUTRIENT TANK LEVELS: 73%",
	"[TIMESTAMP][FOODCOMP-80] FLAVOR MATRIX LOADED: CLASSIC EARTH CUISINE v3.1",
	"[TIMESTAMP][FOODCOMP-80] SELECTED RECIPE: SYNTHESIZED BEEF BOURGUIGNON",
	"[TIMESTAMP][FOODCOMP-80] MISSING COMPONENT: AUTHENTIC WINE CULTURE",
	"[TIMESTAMP][FOODCOMP-80] SUBSTITUTING WITH SYNTHETIC VARIANT B12",
	"[TIMESTAMP][FOODCOMP-80] CALORIC OUTPUT ADJUSTED TO COLONY PARAMETERS",
	"[TIMESTAMP][FOODCOMP-80] PRODUCTION TIME: 4.7 MINUTES PER SERVING",
	"[TIMESTAMP][FOODCOMP-80] INITIATING MOLECULAR GASTRONOMY SUBROUTINES",
	"[TIMESTAMP][FOODCOMP-80] SATISFACTION RATING FROM LAST BATCH: 83%"
]

# Weather control logs
var weather_logs: Array[String] = [
	"[TIMESTAMP][METEORCOM-86] WEATHER MANIPULATION SYSTEM v4.12",
	"[TIMESTAMP][METEORCOM-86] DOME SECTOR: AGRICULTURAL QUADRANT 7",
	"[TIMESTAMP][METEORCOM-86] CURRENT CONDITIONS: ARTIFICIAL SPRING",
	"[TIMESTAMP][METEORCOM-86] TEMPERATURE: 22.7°C",
	"[TIMESTAMP][METEORCOM-86] HUMIDITY: 65%",
	"[TIMESTAMP][METEORCOM-86] RAINFALL SCHEDULED: 06:00-06:25 TOMORROW",
	"[TIMESTAMP][METEORCOM-86] WARNING: DUST STORM APPROACHING EXTERNAL DOME",
	"[TIMESTAMP][METEORCOM-86] REINFORCING ATMOSPHERIC SHIELDS",
	"[TIMESTAMP][METEORCOM-86] POLLEN DISTRIBUTION CYCLE COMPLETE",
	"[TIMESTAMP][METEORCOM-86] SUNRISE SIMULATION ADJUSTED: 15% MORE ORANGE"
]

func _ready() -> void:
	# Register with DebugLogger if available
	if Engine.has_singleton("DebugLogger"):
		DebugLogger.register_module("RetroTerminalLogs", true)
	
	if typewriter:
		# Connect to signals
		typewriter.typing_completed.connect(_on_typing_completed)
		typewriter.line_completed.connect(_on_line_completed)
		typewriter.screen_cleared.connect(_on_screen_cleared)
		
		# Start the demo
		start_demo()
	else:
		push_error("RetroTerminalLogs: No TypewriterEffect node assigned!")

func start_demo() -> void:
	# Get logs based on selected category
	var logs_to_show = get_logs_for_category()
	
	# Apply timestamps to logs
	var processed_logs = apply_timestamps_to_logs(logs_to_show)
	
	# Set logs and start typing
	typewriter.set_lines(processed_logs)
	typewriter.start_typing()
	DebugLogger.debug("RetroTerminalLogs", "Started typing logs for category: " + str(log_category))

# Get the logs array based on the selected category
func get_logs_for_category() -> Array[String]:
	match log_category:
		0: # General
			return general_logs
		1: # Narrative
			return narrative_logs
		2: # Cybernetic
			return cybernetic_logs
		3: # Navigation
			return navigation_logs
		4: # Food
			return food_logs
		5: # Weather
			return weather_logs
		_:
			return general_logs

# Apply current timestamp plus 100 years to all logs
func apply_timestamps_to_logs(logs: Array[String]) -> Array[String]:
	var processed_logs: Array[String] = []
	
	# Get current date and add years_in_future
	var current_time = Time.get_datetime_dict_from_system()
	var future_year = current_time.year + years_in_future
	
	# Format timestamp
	var timestamp = "%d-%02d-%02d %02d:%02d:%02d" % [
		future_year, 
		current_time.month, 
		current_time.day,
		current_time.hour,
		current_time.minute,
		current_time.second
	]
	
	# Apply timestamps to each log_line
	for log_line in logs:
		var processed_log = log_line.replace("[TIMESTAMP]", "[" + timestamp + "]")
		
		# Handle special case for "YESTERDAY" in narrative logs
		if "YESTERDAY" in processed_log:
			var yesterday = "%d-%02d-%02d" % [
				future_year, 
				current_time.month, 
				max(1, current_time.day - 1)  # Ensure day doesn't go below 1
			]
			processed_log = processed_log.replace("YESTERDAY", yesterday)
		
		processed_logs.append(processed_log)
	
	return processed_logs

# Signal handlers
func _on_typing_completed() -> void:
	DebugLogger.debug("RetroTerminalLogs", "Typing completed")
	
	# Restart after delay
	await get_tree().create_timer(3.0).timeout
	start_demo()

func _on_line_completed() -> void:
	DebugLogger.debug("RetroTerminalLogs", "Line completed")
	
	# You can add different sounds for different log types here
	var current_line = typewriter._current_lines[typewriter._current_line_index - 1]
	if "[LC-ALERT]" in current_line or "[WARNING]" in current_line:
		# Play alert sound if you have one
		# Audio.play_sound(alert_sound)
		pass

func _on_screen_cleared() -> void:
	DebugLogger.debug("RetroTerminalLogs", "Screen cleared")

# Public function to change log category
func set_log_category(category: int) -> void:
	log_category = category
	DebugLogger.debug("RetroTerminalLogs", "Log category changed to: " + str(log_category))
	
	# If typing is in progress, restart with new category
	if typewriter._is_typing:
		typewriter.stop_typing()
		
	# Small delay before starting new category
	await get_tree().create_timer(0.5).timeout
	start_demo()
