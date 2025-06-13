# Game Design Documents

Add insanity/visibility meter



## Game Concept

**ERGOSPHERE** - A first-person psychological horror experience where a lone researcher stationed in orbit around a black hole gradually discovers they are not simply observing the void—the void is observing them back.

### Setting
- **Year**: 2157 
- **Location**: Thoth Observatory station in stable orbit within the ergosphere of the Sejanus Singularity
- **Aesthetic**: Retro-futuristic (1970s/80s sci-fi) with bulky CRT monitors, physical switches, paper logs

### Station Layout
- **Observation Deck**: Primary workspace with reinforced viewport windows
- **Control Room**: Cramped space with analog equipment and monitoring stations  
- **Living Quarters**: Minimalist personal space with sleeping pod and kitchen
- **Storage Room**: Spare parts and essentials
- **Server Room**: Station infrastructure and AI core systems
- **Engine Room**: Critical systems (delicate area)
- **Maintenance Bay**: Utility area for repairs and life support

## Core Gameplay Loop

### Daily Tasks (4 primary activities each day)
1. **Black Hole Observation Protocol** - Align telescope, adjust parameters, document anomalies
2. **Station Positioning** - Monitor orbital decay, perform thruster burns  
3. **Communications Management** - Realign dish, process transmissions from Earth
4. **System Maintenance** - Monitor life support, repair malfunctions, manage resources

### Task Examples
- Swap O2 Filters ✓
- Upload/Download Data ✓  
- Reset Power ✓
- Swap Engine Heatsink ✓
- Re-align Telescope ✓
- Close Window Shutters During Radiation ✓
- Sleep at end of day ✓
- Eat a meal ✓
- Play games against Hermes AI
- Read Terminal Entries
- Hide from creature
- Pray to the Obelisk  
- Drink Alcohol (staves off insanity)

### Mini-Games (with Hermes AI)
1. **Pattern Memory** (Simon Says) - 4-9 colored squares, repeat sequence
2. **Pipe Flow Puzzle** - Rotate pieces to connect START to END
3. **Frequency Matcher** - Match target waveform with sliders
4. **Node Connector** - Connect matching numbered nodes
5. **Color Calibration** - Find matching color shade
6. **Defragmentation Sim** - Group colored blocks together
7. **Simple Sokoban** - Move boxes onto targets (1-3 moves)
8. **Circuit Breaker** - Toggle switches affecting neighbors

## 5-Day Progression Structure

### Day 1 (Establish Normal)
**Tasks**: Tour Station, Align Telescope, Download Data, Upload Data, Power Outage (Forced)
**Events**: Minimal - entity appears briefly in peripheral vision

### Day 2 (First Cracks)
**Tasks**: Eat Food, Memorization Game, Defragment Hard Drive, Order Heatsink, Reboot Systems
**Events**: 1-2 minor incidents - random teleportation, blood decals, spooky sounds

### Day 3 (Escalation Begins)
**Tasks**: Eat Food, Lube Engine Blades, Run Diagnostics, Sample Anomalies, Snake
**Events**: 2-3 aggressive incidents - entity follows player, small black hole appears, fire, Replace Generator Heatsink

### Day 4 (Breaking Point)
**Tasks**: Eat Food, Align Telescope, Download Data, Upload Data, Investigate Anomalous Readings, Attempt Communication with Earth
**Events**: 3-4 major incidents - shadowy figures, vision distortion, flesh on walls, lightning barriers

### Day 5 (Final Descent)
**Tasks**: Emergency Systems Check, Final Data Transmission Attempt, Prepare Escape Pod, Choose Your Fate
**Events**: Constant supernatural activity - eyes everywhere, environment darkening, mysterious obelisk

## Endings

### Main Endings
1. **Consumed** (Default) - Player and station sucked into black hole
2. **Escape** - Player flees in escape pod (requires completing "Prepare Escape Pod")
3. **Acceptance** - Player willingly merges with black hole (requires interacting with Obelisk)

### Secret Endings  
1. **The Researcher's Gambit** - Complete all optional data analysis + find hidden logs → "Activate Experimental Protocol"
2. **The Witness** - Never flee from supernatural events → Entity offers direct communication

## Core Mysteries (Left Deliberately Open-Ended)

### The Black Hole
- Doesn't behave like normal black holes
- Sometimes "responds" to observation  
- Telescope alignment isn't for viewing—it's for something else
- Looking too long causes headaches/nausea

### The Station's True Purpose
- Food production facility for 6-person crew seems excessive
- Areas never allowed to access
- Emergency protocols for threats that don't make sense
- Power requirements for small city

### Time Anomalies
- Clocks show different times in different areas
- Personal logs with future dates
- Dreams about events that later come true
- Tasks feel like they've been done hundreds of times

### The Corporation (Thoth Corp)
- Logo is an eye (Egyptian god of wisdom/judgment)
- All Earth communication filtered through Thoth
- Employment contract sections can't remember signing
- Daily "biographical data" collection

### The Truth
The "black hole" is actually a membrane containing an ancient cosmic entity. The station's true purpose is ritualistic:
- Each observation sequence focuses the entity's attention on reality
- Orbital adjustments position station at membrane weak points  
- Communications equipment creates conduit for entity's influence
- Maintenance tasks unknowingly maintain ritual configuration

Previous researchers either went insane, committed suicide, or were "consumed." Player was selected as final catalyst—psychologically resilient enough to complete the ritual sequence before breaking down.

## Voice Acting & Audio

### Hermes AI Lines (Use SAM voice synthesizer)
**Settings**: Voice: SAM, Pitch: 90, Speed: 120

**Introduction**: "Welcome to Thoth Observatory. I am Hermes, coordinator intelligence. You've been selected as my steward under Policy 735.4 of the Machine Intelligence Act..."

**Room Descriptions**: 
- "Storage room. Spare parts and essentials here."
- "Observation room. We monitor and collect singularity data here."
- "Your quarters. Bed, kitchen, toilet. Everything for survival."

**Warnings** (Progressive deterioration):
- Normal: "Warning. Master fuse tripped. Manual reset required in engine room."
- Existential: "Warning we are alone now, we dance on the precipice of oblivion..."
- Critical: "Warning. Sejanus will consume us. Mathematical certainty. No countermeasures exist."

### Introduction Cutscene
"The year is 2125, humanity has achieved interstellar colonization, in desperation to escape their failing bio-sphere humans spread themselves too thin.

Communication across the vast cosmic distances proved to be a challenge, outpost after outpost keep vanishing leaving only a few pleading final words arriving years after disaster.

In order to survive, mankind must develop better communication methods, they must learn to bend space time to their whim. Thus they started studying the only known natural phenomenon which does the same: Black holes.

They began searching for the holy grail, a stable microsingularity, and with time it was found. SJ-1765 or the Sejanus Singularity was a perfect candidate for research.

The Thoth Observatory station was constructed in stable orbit, and researchers have been sent one after another to gather data from this miraculous stellar object.

The fact that few of them return upon their rotation coming to its end is irrelevant; what mankind stands to gain from this research is too great.

Your rotation begins now.

The cosmos is unforgiving to those lost within it."

**EncryptionKey**: 651a9f4efa9704561dc8770630ea9de91868846847222dc13a521d64cf5ed009