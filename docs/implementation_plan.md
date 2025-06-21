# ERGOSPHERE - Next Milestone Focus Areas

## Priority 1: Complete the Full 5-Day Experience (Critical Path)

### Day 4 Completion
- **Finish remaining Day 4 tasks**: You mentioned having tasks "up till about day 4"
- **Implement Day 4's critical events**: Mass hallucination, pattern revelation, spatial confusion
- **Test Day 4 end-to-end**: Ensure progression to Day 5 works

### Day 5 Implementation
- **Core Day 5 tasks**: Emergency systems check, final transmission, prepare escape pod
- **The three endings**: Default consumption, escape, and merger paths
- **Obelisk interaction**: Key element for the merger ending
- **Constant supernatural activity**: Eyes everywhere, environment darkening

**Why this first**: You can't properly test the full horror arc without all 5 days implemented. This is your critical path.

## Priority 2: Polish What's Working (Player Experience)

### Fix Critical Bugs from dev_notes.md
1. **Power Lever animation plays twice** - Quick fix, high visibility
2. **Hard Drive falls through floor** - Game-breaking physics issue
3. **Carried objects colliding with player** - Frustrating gameplay issue
4. **Capacity reservation bug** - Breaks resource management

### UI Readability (Major feedback item)
- **Make ALL text bigger** - Multiple mentions in feedback
- **Center text properly** - Polish issue that affects perception
- **Make "align telescope" more obvious** - Player confusion point

### Lighting Improvements
- **"Too dark"** - Consistent feedback, needs addressing
- **Add contrast**: Brighten key areas, darken others for atmosphere
- **Emergency lighting improvements**: Make power outages more dramatic

**Why this second**: These are all "simple fixes" that will dramatically improve the experience without over-engineering.

## Priority 3: Implement Missing Horror Elements (Impact)

### Visual Horror Effects (Highest impact, builds on existing systems)
1. **Vision corruption shader** - You have warp_rect, expand it
2. **Screen/UI corruption** - Text glitches, wrong values
3. **Black hole pulse effect** - Heartbeat sync with emission

### Audio System Expansion
1. **Reverb for distant sounds** - Specifically requested in feedback
2. **Entity whispers in static** - High atmosphere, low effort
3. **Hermes voice replacement** - Major feedback item

### Environmental Details
- **Add more rigidbodies** - Requested multiple times
- **Moving parts and decals** - "Too static" feedback
- **Reality distortion on Day 5** - Flesh on walls, etc.

**Why this third**: These build atmosphere and address specific feedback without requiring new systems.

## Priority 4: Implement Secret Paths (Replayability)

### The Doubter's Path (Escape route)
1. **"Document Anomalies"** task (Day 2-3)
2. **"Research Previous Personnel"** task (Day 3-4)
3. **"Locate Emergency Protocols"** task (Day 4)

### The Seeker's Path (Merger route)
1. **"Extended Observation"** task (Day 2-3)
2. **"Decode the Signal"** task (Day 3-4)
3. **"Answer the Call"** task (Day 4)

**Why this fourth**: Adds depth but isn't required for basic completion.

## What NOT to Focus On Yet

### Avoid These Time Sinks:
- **Complex new systems** - You have enough systems
- **Perfect voice acting** - Placeholder is fine for now
- **Elaborate visual effects** - Simple corruption effects first
- **New mechanics** - Polish what exists

### Save for Post-Alpha:
- **Extensive playtesting balance**
- **Achievement system**
- **Options menu polish**
- **Localization prep**

## Recommended 2-Week Sprint

### Week 1: Critical Path
- **Days 1-2**: Finish Day 4 tasks and events
- **Days 3-4**: Implement Day 5 completely
- **Day 5**: Implement all three endings

### Week 2: Polish Sprint
- **Day 1**: Fix the 4 critical bugs
- **Days 2-3**: UI text improvements
- **Day 4**: Lighting pass
- **Day 5**: Test full 5-day playthrough

## Success Metrics

You'll know you've hit this milestone when:
1. **Player can complete all 5 days** without game-breaking bugs
2. **All three endings are reachable** and functional
3. **Critical bugs are fixed** (no falling hard drives!)
4. **UI text is readable** at normal viewing distance
5. **Full playthrough takes 2-3 hours** as intended

## Architecture Tips for This Phase

### Keep It Simple
```gdscript
# For Day 5 constant events, just use a timer
var day_5_event_timer: float = 0.0
var day_5_event_interval: float = 30.0  # Event every 30 seconds

func _process(delta):
    if current_day == 5:
        day_5_event_timer += delta
        if day_5_event_timer >= day_5_event_interval:
            trigger_random_day_5_event()
            day_5_event_timer = 0.0
            day_5_event_interval = randf_range(20.0, 40.0)
```

### Reuse Everything
- Power outage system → Use for Day 5 darkness
- Entity spawn system → Use for eyes/obelisk
- Task system → Minimal changes for secret tasks
- Event system → Just add Day 5 event pool

## Final Recommendation

**Do Day 5 first**. Everything else is polish on a working game. Once you can play from start to any ending, you have a complete experience that you can iterate on. The difference between "almost done" and "playable but rough" is huge for motivation and testing.