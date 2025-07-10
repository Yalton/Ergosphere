# ERGOSPHERE - Events & Implementation Guide

## Event System Overview

Events use a tension/disruption scoring system with cooldowns to pace the horror experience. Each event has:
- **Tension Score** (1-5): Psychological pressure
- **Disruption Score** (1-5): Gameplay interruption  
- **Cooldowns**: Prevent similar events from stacking
- **Day Requirements**: Control progression

## Early Game Events (Days 1-2)

### Subtle Horror Events

#### "Observation Echo"
- **ID**: `observation_echo`
- **Tension**: 2, **Disruption**: 1
- **Trigger**: After telescope alignment
- **Effect**: Hear your own voice repeat coordinates with 10-second delay
- **Implementation**: Cache and playback player audio with reverb
- **Hermes**: "Audio feedback detected. Adjusting communication array."

#### "Time Slip"
- **ID**: `time_slip`
- **Tension**: 2, **Disruption**: 1  
- **Trigger**: Random, 20% chance
- **Effect**: All clocks show different times (off by 5-30 minutes)
- **Implementation**: Override UI time displays with offset values
- **Duration**: 60 seconds then sync

#### "Wrong Reflection"
- **ID**: `wrong_reflection`
- **Tension**: 3, **Disruption**: 1
- **Trigger**: Looking in bathroom mirror
- **Effect**: Reflection moves independently for 1-2 seconds
- **Implementation**: Delay mirror animation by 0.5 seconds
- **Frequency**: Once per day maximum

## Mid Game Events (Days 2-3)

### Building Tension Events

#### "Black Hole Pulse"
- **ID**: `black_hole_pulse`
- **Tension**: 3, **Disruption**: 2
- **Trigger**: Extended observation (30+ seconds)
- **Effect**: Accretion disk pulses in sync with heartbeat
- **Implementation**: Modulate emission intensity with sine wave
- **Audio**: Subtle heartbeat sound that gradually increases

#### "Terminal Corruption"
- **ID**: `terminal_corruption`
- **Tension**: 3, **Disruption**: 2
- **Trigger**: Using any terminal
- **Effect**: Text briefly shows "HELLO [PLAYER_NAME]" or "I SEE YOU TOO"
- **Implementation**: Text replacement for 2 seconds
- **Escalation**: Messages become more personal each day

#### "Gravity Anomaly"
- **ID**: `gravity_anomaly`
- **Tension**: 2, **Disruption**: 3
- **Trigger**: Entering observation deck
- **Effect**: Objects slowly drift toward window
- **Implementation**: Add force toward window on physics objects
- **Duration**: 30 seconds
- **Hermes**: "Localized gravitational fluctuation detected."

#### "Previous Researcher Audio"
- **ID**: `researcher_voice`
- **Tension**: 4, **Disruption**: 2
- **Trigger**: In communications room
- **Effect**: Static resolves into desperate warning
- **Audio**: "Don't complete the pattern... It's not research, it's feeding..."
- **Implementation**: Crossfade static with voice clip

## Late Game Events (Days 3-4)

### Reality Breaking Events

#### "Door Malfunction"
- **ID**: `door_delay`
- **Tension**: 2, **Disruption**: 3
- **Trigger**: Any door use, 30% chance
- **Effect**: Doors take 3-5 seconds extra to open
- **Implementation**: Add random delay to door animation
- **Audio**: Groaning/straining mechanical sounds

#### "Emergency Light Mode"
- **ID**: `emergency_lighting`
- **Tension**: 3, **Disruption**: 4
- **Trigger**: Random, increases with insanity
- **Effect**: All lights switch to red emergency mode
- **Implementation**: Toggle lighting state globally
- **Duration**: 30-60 seconds
- **No explanation**: Hermes says nothing

#### "Shadow Disconnect"
- **ID**: `shadow_movement`
- **Tension**: 4, **Disruption**: 2
- **Trigger**: Walking past specific lights
- **Effect**: Player shadow moves independently
- **Implementation**: Decouple shadow from player animation
- **Duration**: 1-2 seconds per occurrence

#### "Wrong Room Teleport"
- **ID**: `spatial_confusion`
- **Tension**: 4, **Disruption**: 4
- **Trigger**: Room transition, 10% chance
- **Effect**: Enter one room, arrive in different room
- **Implementation**: Teleport player on door trigger
- **Hermes**: "Spatial indexing error. Recalibrating."

## Critical Events (Days 4-5)

### Full Breakdown Events

#### "Mass Hallucination"
- **ID**: `mass_hallucination`
- **Tension**: 5, **Disruption**: 4
- **Trigger**: Day 4 evening
- **Effect**: All screens show live feed of player from impossible angles
- **Implementation**: Replace all monitor textures with camera feeds
- **Duration**: 2 minutes

#### "The Pattern Revealed"
- **ID**: `pattern_revelation`
- **Tension**: 5, **Disruption**: 3
- **Trigger**: After completing 3+ tasks on Day 4
- **Effect**: Map shows tasks form ritual circle
- **Implementation**: Update map UI to show connected lines
- **Text**: "PATTERN COMPLETION: 87.3%"

#### "Everything is 47"
- **ID**: `number_obsession`
- **Tension**: 5, **Disruption**: 5
- **Trigger**: Day 5 morning
- **Effect**: Every number display shows "47"
- **Implementation**: Override all numeric UI elements
- **Duration**: 3 minutes

## Emergency Task Events

### Power Outage
- **ID**: `power_outage`
- **Category**: PLANNED or UNPLANNED
- **Triggers Emergency Task**: "Restore Power"
- **Effect**: Lights out, emergency lighting only
- **Implementation**: Use EffectsManager.kill_power()
- **Time Limit**: 180 seconds
- **Failure**: Permanent emergency lighting

### Oxygen System Failure  
- **ID**: `oxygen_failure`
- **Triggers Emergency Task**: "Replace O2 Filter"
- **Effect**: Breathing becomes labored, vision blurs
- **Implementation**: Post-process effect + breathing audio
- **Time Limit**: 120 seconds
- **Failure**: Health degradation

### Fire Emergency
- **ID**: `fire_emergency`
- **Triggers Emergency Task**: "Extinguish Fire"
- **Effect**: Fire particle effect in random room
- **Implementation**: Spawn fire prefab at predetermined locations
- **Time Limit**: 90 seconds
- **Failure**: Fire spreads to adjacent room

## Implementation Guidelines

### Event Scheduling
```gdscript
# Example event configuration
var observation_echo = EventData.new()
observation_echo.event_id = "observation_echo"
observation_echo.event_name = "Observation Echo"
observation_echo.category = EventData.EventCategory.UNPLANNED
observation_echo.tension_score = 2
observation_echo.disruption_score = 1
observation_echo.base_chance = 30.0
observation_echo.min_day = 1
observation_echo.max_day = 3
observation_echo.tension_cooldown = 60.0
```

### Modifiers
- **Insanity**: +1% chance per insanity point
- **Day Progression**: +10% chance per day after Day 1
- **Task Completion**: 2x chance for 5 seconds after task
- **Cooldowns**: Reduced by 10% per day

### Event Handler Pattern
```gdscript
extends EventHandler
class_name ObservationEchoHandler

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
    # Cache current audio
    var cached_audio = record_player_audio()
    
    # Wait 10 seconds
    await get_tree().create_timer(10.0).timeout
    
    # Play back with reverb
    play_audio_with_effect(cached_audio, "reverb")
    
    # Show Hermes response
    CommonUtils.send_player_hint("Hermes", "Audio feedback detected.")
```

### Best Practices

1. **Reuse Existing Systems**
   - Use current lighting, audio, UI systems
   - Modify parameters rather than creating new systems
   - Leverage post-processing for visual effects

2. **Maintain Ambiguity**
   - Never fully explain supernatural events
   - Let player rationalize or accept impossibility
   - Hermes provides technical explanations that don't quite fit

3. **Progressive Intensity**
   - Start subtle, build to overwhelming
   - Each day should feel noticeably worse
   - Save biggest effects for Days 4-5

4. **Audio is Key**
   - Layer sounds for unease
   - Use silence strategically  
   - Corrupt familiar sounds (footsteps, machinery)

5. **Simple But Effective**
   - Text corruption: Replace random characters
   - Time distortion: Offset clocks differently
   - Spatial confusion: Teleport to wrong rooms
   - Light flickers: Simple on/off patterns

## Testing Considerations

- Use console commands to trigger specific events
- Test cooldown systems with time acceleration
- Verify events respect day restrictions
- Ensure emergency tasks spawn correctly
- Check that events don't soft-lock gameplay