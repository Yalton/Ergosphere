# ERGOSPHERE - Recommended Focus Areas

## 1. **Visual Horror Effects** (Highest Impact)

Since you have the player effects component but only blink/warp implemented, expand this for maximum horror impact:

### Quick Win Visual Effects:
- **Screen Corruption** - Text glitches, UI elements showing wrong values
- **Time Distortion** - Clocks showing different times, UI time jumping
- **Hallucination Flashes** - Brief images/scenes that appear and vanish
- **Static/Noise Buildup** - Progressive visual degradation

### Implementation Priority:
1. **Vision Corruption Shader** (Day 3-4 effect)
   - Use your existing warp_rect system
   - Add chromatic aberration + noise
   - Trigger during "observation_echo" events

2. **Emergency Lighting Improvements**
   - Your EffectsManager handles power, but add:
   - Flickering patterns
   - Random light failures
   - Color temperature shifts (cold blue → warm red)

3. **Black Hole Pulse Effect**
   - Modify black hole emission in sync with heartbeat
   - Use sine wave on emission_energy_multiplier
   - Tie to player proximity/observation time

## 2. **Audio System Enhancement** (High Impact, Low Effort)

You have audio players but limited implementation:

### Quick Audio Wins:
- **Spatial Audio Zones** - Different reverb in different rooms
- **Dynamic Ambience Layers** - Add/remove layers based on day/events
- **Audio Corruption** - Reverse/pitch-shift familiar sounds
- **Entity Whispers** - Barely audible voices in static

### Implementation:
```gdscript
# Add to your existing audio system
func corrupt_audio(audio_player: AudioStreamPlayer3D, corruption_level: float):
    var pitch_shift = AudioEffectPitchShift.new()
    pitch_shift.pitch_scale = 1.0 - (corruption_level * 0.3)
    
    var bus_idx = AudioServer.get_bus_index(audio_player.bus)
    AudioServer.add_bus_effect(bus_idx, pitch_shift)
```

## 3. **Event Pacing & Escalation** (Critical for Horror Flow)

Your event system needs better pacing control:

### Missing Pieces:
1. **Tension Tracking System**
   - Global tension value (0-100)
   - Events add/subtract tension
   - High tension = more aggressive events

2. **Event Clusters**
   - Group related events
   - "Reality Break" cluster: time_slip → wrong_reflection → spatial_confusion
   - Ensures thematic consistency

3. **Cooldown Categories**
   - Not just per-event cooldowns
   - Category cooldowns (visual, audio, gameplay)
   - Prevents overwhelming player

### Quick Implementation:
```gdscript
# Add to EventScheduler
var global_tension: float = 0.0
var category_cooldowns: Dictionary = {
    "visual": 0.0,
    "audio": 0.0,
    "gameplay": 0.0
}

func can_trigger_event(event: EventData) -> bool:
    # Check category cooldown
    if category_cooldowns.get(event.category, 0.0) > 0:
        return false
    
    # Check tension threshold
    if event.min_tension > global_tension:
        return false
        
    return true
```

## 4. **Environmental Storytelling** (Medium Effort, High Payoff)

Use your existing spawn system for environmental changes:

### Day-Based Environment Changes:
- **Day 1-2**: Subtle object misplacements
- **Day 3**: Objects in impossible locations
- **Day 4**: Geometry violations (doors lead wrong places)
- **Day 5**: Complete spatial breakdown

### Implementation Using Your Systems:
1. **Object State Manager**
   - Track original positions
   - Gradually move objects each day
   - Use your spawn points for relocated items

2. **Decal System**
   - Blood appears/disappears
   - Writing on walls changes
   - Shadows without sources

## 5. **Task Corruption** (Leverage Existing System)

Your task system is solid, now make it unsettling:

### Task Text Corruption:
```gdscript
# Add to task display
func corrupt_task_text(original: String, day: int) -> String:
    if day < 3: return original
    
    var corrupted = original
    if day >= 4:
        # Random character replacement
        var chars = corrupted.to_utf8_buffer()
        for i in range(chars.size()):
            if randf() < 0.1:
                chars[i] = randi_range(33, 126)
        corrupted = chars.get_string_from_utf8()
    
    return corrupted
```

### Task Behavior Corruption:
- Tasks complete themselves
- Completed tasks un-complete
- Task locations change mid-completion

## Implementation Order

### Week 1 Focus:
1. **Vision Corruption Shader** (1 day)
2. **Audio Corruption System** (1 day)
3. **Tension Tracking** (1 day)
4. **Environmental Object Displacement** (2 days)

### Week 2 Focus:
1. **Task Corruption** (1 day)
2. **Enhanced Emergency Lighting** (1 day)
3. **Event Clusters** (2 days)
4. **Testing & Polish** (1 day)

## Code Architecture Tips

### Centralize Effect Parameters:
```gdscript
# EffectIntensityManager.gd
extends Node

var corruption_level: float = 0.0  # 0-1 based on day/events
var tension_level: float = 0.0     # 0-1 based on recent events
var insanity_level: float = 0.0    # 0-1 based on player state

func get_visual_intensity() -> float:
    return corruption_level * 0.5 + tension_level * 0.3 + insanity_level * 0.2
```

### Use Signals for Effect Coordination:
```gdscript
# When event triggers
signal horror_spike(intensity: float)
signal reality_break(type: String)
signal entity_presence(distance: float)

# Connect all effect systems to these
```

## Performance Considerations

1. **Shader LOD System**
   - Reduce shader complexity at distance
   - Disable effects outside player FOV
   - Pool/reuse effect instances

2. **Audio Optimization**
   - Limit simultaneous whisper voices
   - Use audio LOD for ambient layers
   - Preload critical audio streams

3. **Event Throttling**
   - Max 1 major visual effect active
   - Queue non-critical events
   - Batch similar effects

## Final Recommendations

1. **Start with Visual Horror** - Biggest impact for effort
2. **Layer Audio Subtly** - Build atmosphere without overwhelming
3. **Use Existing Systems** - Corrupt what works rather than building new
4. **Test Pacing Constantly** - Horror is 90% timing
5. **Keep It Simple** - Your philosophy is right: simple but effective

The key is making the familiar become unfamiliar. You have solid systems - now make them betray the player's expectations.