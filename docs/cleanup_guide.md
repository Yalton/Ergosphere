# Complete Codebase Cleanup Guide

## Overview
This guide provides a practical, step-by-step approach to cleaning up your Godot codebase. Focus on quick wins first, then tackle larger refactoring tasks. Remember: simple solutions over perfect ones.

## Phase 1: Quick Wins (Do These First)

### 1.1 Standardize Debug Module Registration

**Problem:** Inconsistent module naming and registration patterns across classes.

**Solution:** Create a base class that all debuggable nodes inherit from:

```gdscript
# base_module.gd
extends Node
class_name BaseModule

## Enable debug logging for this module
@export var enable_debug: bool = true

var module_name: String = ""

func _ready() -> void:
    if module_name.is_empty():
        module_name = get_class()
    DebugLogger.register_module(module_name, enable_debug)
    _on_ready()

## Override this instead of _ready() in child classes
func _on_ready() -> void:
    pass
```

**Migration example:**
```gdscript
# Before:
extends Node3D
class_name StorageWall

@export var enable_debug: bool = true
var module_name: String = "StorageWall"

func _ready() -> void:
    DebugLogger.register_module(module_name, enable_debug)
    # ... rest of code

# After:
extends BaseModule
class_name StorageWall

func _on_ready() -> void:
    # ... rest of code
```

### 1.2 Remove Dead Code

**What to remove:**
- Commented out code blocks
- Unused variables and functions
- Empty functions that only call super
- Old TODO comments that are no longer relevant
- Duplicate or unreachable code

**Search patterns to find dead code:**
- `#.*func` - commented functions
- `^\s*#.*\n.*#.*\n.*#` - large comment blocks
- `pass\s*$` - empty functions
- `var .* = .*\s*#\s*unused` - marked unused variables

### 1.3 Consolidate Audio Playing

**Problem:** Multiple audio playing implementations (Audio singleton vs individual implementations).

**Solution:** Use only the Audio singleton for all audio:

```gdscript
# Replace all instances of:
audio_player.stream = sound
audio_player.play()

# With:
Audio.play_sound(sound)

# For positional audio:
Audio.play_sound(sound, true, global_position)
```

### 1.4 Fix Export Variable Documentation

**Current good pattern (keep using):**
```gdscript
## Brief description visible in inspector tooltip
@export var variable_name: Type = default_value

## Longer description for complex features.
## Can span multiple lines for clarity.
@export var complex_variable: Type = default_value
```

**Add missing descriptions to all exports following this pattern.**

## Phase 2: Structural Improvements

### 2.1 Organize File Structure

**Create this folder structure:**
```
res://
├── autoloads/           # Singletons (GameManager, Audio, etc.)
├── player/              # Player controller and components
│   ├── player.gd
│   ├── components/      # Player-specific components
│   └── player.tscn
├── systems/             # Game systems
│   ├── storage/         # Storage system files
│   ├── events/          # Event system files
│   ├── tasks/           # Task system files
│   └── audio/           # Audio system files
├── ui/                  # All UI elements
│   ├── hud/            # In-game UI
│   ├── menus/          # Menu screens
│   └── components/      # Reusable UI components
├── resources/           # Resource files
│   ├── items/          # ShopItem resources
│   ├── events/         # EventData resources
│   └── tasks/          # TaskData resources
├── utilities/           # Utility scripts
└── scenes/             # Game scenes
    ├── levels/         # Level scenes
    └── objects/        # Interactive object scenes
```

### 2.2 Standardize Resource Classes

**Create base resource class:**
```gdscript
# base_resource.gd
extends Resource
class_name BaseResource

## Unique identifier for this resource
@export var id: String = ""
## Display name for UI
@export var display_name: String = ""
## Detailed description
@export_multiline var description: String = ""

func _init() -> void:
    if id.is_empty():
        id = str(get_instance_id())

func get_display_text() -> String:
    return display_name if not display_name.is_empty() else id
```

**Update resources to inherit from BaseResource:**
- ShopItem
- EventData
- TaskData
- TerminalLog

### 2.3 Improve Signal Organization

**Standard signal format at the top of each class:**
```gdscript
extends BaseModule
class_name MyClass

## Emitted when [what happens]
signal something_happened(param: Type)
## Emitted when [what happens]
signal another_thing(param1: Type, param2: Type)

# Then export variables
@export var my_variable: int = 0
```

### 2.4 Reduce Manager Coupling

**Problem:** Direct GameManager references everywhere.

**Solution:** Use signals and dependency injection:

```gdscript
# Instead of:
func complete_task():
    GameManager.task_manager.complete_task(task_id)

# Use:
signal task_completion_requested(task_id: String)

func complete_task():
    task_completion_requested.emit(task_id)
```

**In GameManager, connect to these signals:**
```gdscript
func _ready():
    # Find all nodes that can request task completion
    var task_requesters = get_tree().get_nodes_in_group("task_requesters")
    for requester in task_requesters:
        if requester.has_signal("task_completion_requested"):
            requester.task_completion_requested.connect(_on_task_completion_requested)
```

## Phase 3: Code Quality Standards

### 3.1 Naming Conventions

**Enforce these consistently:**
- Classes: `PascalCase` (PlayerController, StorageManager)
- Variables: `snake_case` (player_speed, max_health)
- Constants: `UPPER_SNAKE_CASE` (MAX_ITEMS, DEFAULT_SPEED)
- Signals: `snake_case` verb phrases (item_picked_up, door_opened)
- Private methods: `_snake_case` (_update_internal, _calculate_damage)
- Groups: `snake_case` (storage_walls, interactables)

### 3.2 Error Handling Pattern

**Standardize error checking:**
```gdscript
func do_something(param: Type) -> bool:
    # Validate inputs first
    if not _validate_param(param):
        DebugLogger.error(module_name, "Invalid parameter: " + str(param))
        return false
    
    # Check requirements
    if not _check_requirements():
        DebugLogger.warning(module_name, "Requirements not met")
        return false
    
    # Do the actual work
    _perform_action(param)
    DebugLogger.debug(module_name, "Action completed successfully")
    return true

func _validate_param(param: Type) -> bool:
    return param != null and param.is_valid()

func _check_requirements() -> bool:
    # Check all requirements
    return true
```

### 3.3 Node Reference Pattern

**Use @onready for all node references:**
```gdscript
# Good:
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var player: Player = $Player

# Avoid:
var health_bar: ProgressBar

func _ready():
    health_bar = $UI/HealthBar  # Finding in _ready
```

### 3.4 Timer Creation Pattern

**Always use CommonUtils for timers:**
```gdscript
# Good:
var timer = CommonUtils.create_timer(self, 5.0, true, true)
timer.timeout.connect(_on_timer_timeout)

# Avoid:
var timer = Timer.new()
timer.wait_time = 5.0
timer.one_shot = true
timer.autostart = true
add_child(timer)
timer.timeout.connect(_on_timer_timeout)
```

## Phase 4: Documentation Standards

### 4.1 Class Documentation Template

```gdscript
## Brief one-line description of the class purpose
##
## Detailed description explaining:
## - What this class does
## - When it should be used
## - How it interacts with other systems
## - Any important limitations or requirements
##
## Example usage:
## ```
## var storage = StorageManager.new()
## storage.order_item("item_001", "A1")
## ```
extends BaseModule
class_name MyClass
```

### 4.2 Function Documentation

```gdscript
## Brief description of what the function does
## @param param_name Description of the parameter
## @return Description of return value
func my_function(param_name: Type) -> ReturnType:
    pass
```

## Phase 5: Performance Optimization

### 5.1 Caching Patterns

```gdscript
# Cache expensive lookups
var _cached_player: Player = null

func get_player() -> Player:
    if not _cached_player:
        _cached_player = get_tree().get_first_node_in_group("player")
    return _cached_player
```

### 5.2 String Operation Optimization

```gdscript
# Avoid string concatenation in loops
# Bad:
var result = ""
for item in items:
    result += item.name + ", "

# Good:
var parts = []
for item in items:
    parts.append(item.name)
var result = ", ".join(parts)
```

## Implementation Order

1. **Week 1: Quick Wins**
   - Standardize module registration (1 day)
   - Remove dead code (1 day)
   - Fix audio consolidation (1 day)
   - Document all exports (2 days)

2. **Week 2: Structure**
   - Reorganize file structure (1 day)
   - Implement base classes (2 days)
   - Standardize signals (2 days)

3. **Week 3: Quality**
   - Fix naming conventions (2 days)
   - Implement error handling patterns (2 days)
   - Update node references (1 day)

4. **Week 4: Polish**
   - Add class documentation (3 days)
   - Performance optimization (2 days)

## Testing After Each Phase

After each phase, test:
1. All basic functionality still works
2. Debug logging shows expected output
3. No new errors in console
4. Performance hasn't degraded

## Maintenance Going Forward

1. **Code Reviews:** Check new code follows these patterns
2. **Regular Cleanup:** Schedule monthly dead code removal
3. **Documentation:** Update docs when changing functionality
4. **Refactoring:** When touching old code, update it to new standards

## Red Flags to Avoid

- Don't create abstractions until needed 3+ times
- Don't nest inheritance more than 2-3 levels deep
- Don't optimize without measuring first
- Don't break working code for perfect patterns
- Don't add complexity to save a few lines

## Remember

- Simple and working > complex and perfect
- Gradual improvement > big bang refactoring
- Consistency > individual perfection
- Clear code > clever code