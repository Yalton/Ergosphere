### Week 1: Greyboxing and Core Systems

**Days 1-2: Level Layout & First-Person Interaction**
1. **Create a basic level layout**:
   - Use simple shapes (cubes, planes) to define rooms and areas
   - Mark interaction points and collectible locations
   - Set up basic lighting

2. **Enhance the first-person controller**:
   - Setup camera settings and field of view

**Days 3-4: Interactive Environment**
1. **Implement diegetic UI**:
   - Add the DiegeticLabel system to show object names in-world
   - Create hover labels for interactable objects
   - Test visibility at different distances

2. **Add basic interactions**:
   - Set up doors using your existing door system
   - Create simple physics objects that can be pushed
   - Implement switches and triggers

**Days 5-7: Collectibles and Objectives**

2. **Implement the objective system**:
   - Define primary objectives for the game
   - Create the UI to display current objectives
   - Connect objectives to level interactions

### Week 2: Refinement and Gameplay Elements

**Days 8-10: Physics Puzzles**
1. **Create physics-based interactions**:
   - Implement the PhysicsObject class
   - Set up physics puzzles where objects need to be placed in specific areas
   - Add sound effects for physics interactions

2. **Add environmental storytelling**:
   - Create interactive notes or messages
   - Add visual clues in the environment
   - Implement audio logs or ambient sounds

**Days 11-14: Testing and Polish**
1. **Playtest and refinement**:
   - Test the full gameplay loop
   - Adjust physics parameters
   - Fix any movement or interaction issues

2. **Add final touches**:
   - Improve feedback for interactions
   - Add ambient audio
   - Polish transitions between areas


Add reverb to sounds that are far from player and have a wall in the way
Brainstorm potential mysteries to work into the game 

Tasks

~~Swap O2 Filters~~
~~Upload Data~~
~~Reset Power~~
~~Swap Engine Heatsink~~
~~Download Data~~
~~Re-allign Telescope~~
~~Close Window Shutters During Radiation~~
~~Sleep at end of day~~
~~Eat a meal~~

Play a game against Hermes
- Whackamole
- Pattern Memory
  
Read Terminal Entries

Hide from creature
Pray to the Obelisk
Drink Alcohol - Staves off insanity

## Thoughts organized


Still too dark
- Maybe this works 

Hermes voice still terrible
- Got VoiceActor

Fix Brown note
- Notes still teleport around but I cannot be fucked 

Get Events in the game

Get new Hermes voice in the game

New Event system

Start screen for all Uis

Make new Demo


---


## 1. **Pattern Memory** (Simon Says style)
- 4-9 colored squares that light up in a sequence
- Player clicks to repeat the pattern
- Each success adds one more to the sequence
- After 5-7 correct sequences, "system calibrated"
- Can't really lose, just resets if wrong

## 2. **Pipe Flow Puzzle** (Super simplified)
- Grid of pipe pieces that need to be rotated
- Click to rotate 90 degrees
- Connect START to END
- Only like 4x4 grid, very easy solutions
- "Rerouting coolant flow..."

## 3. **Frequency Matcher**
- Show a target waveform at top
- 3-4 sliders that control sine wave properties
- Click and drag to match the wave
- When close enough, it snaps to correct
- "Tuning communication frequency..."

## 4. **Node Connector**
- Several nodes with numbers (1,2,3 etc)
- Click and drag to connect matching numbers
- No crossing lines needed, very simple layouts
- "Reconnecting neural pathways..."

## 5. **Color Calibration**
- Grid of squares in slightly different shades
- Click the one that matches the target color
- Gets progressively easier (bigger differences)
- "Calibrating sensor array..."

## 6. **Defragmentation Sim**
- Grid with colored blocks scattered around
- Click blocks of same color to group them
- They automatically snap together
- "Defragmenting memory cores..."

## 7. **Simple Sokoban** (1-2 moves)
- Tiny 3x3 or 4x4 grid
- Click to move a box onto a target
- Only requires 1-3 moves to solve
- "Realigning power cells..."

## 8. **Circuit Breaker**
- Grid of switches, some on, some off
- Click to toggle, but it affects neighbors
- Very easy patterns (like all need to be on)
- "Resetting power grid..."

My personal favorite for your use case would be **Pattern Memory** or **Node Connector** because:
- Can't fail, just retry
- Takes 30-60 seconds
- Clear progress indication
- Fits the "assist with process errors" theme
- Easy to implement with just clicks
- Could add satisfying sound effects


<!-- Models required -->

<!-- 
Space Station
- Floors 
- Walls
- Ceiling 
- Doors  -->

Day Plan 

# 5-Day Horror Game Task & Event Planning

## Current Problems
- Day 4 & 5 are too light - no buildup to climax
- Secret endings need clear unlock conditions
- Events need better pacing/escalation
- Missing crucial story revelation moments

## Revised Daily Structure

### Day 1 (Establish Normal)
**Tasks:**
- Tour Station ✓
- Align Telescope ✓
- Download Data ✓
- Upload Data ✓
- **Power Outage (Forced)** ✓

**Events:** Keep minimal - maybe one subtle thing
- Entity appears briefly in peripheral vision (no interaction)

### Day 2 (First Cracks)
**Tasks:**
- Eat Food ✓
- Memorization Game ✓
- Defragment Hard Drive ✓
- **Order Wrench** (sets up Day 3)
- Reboot Systems ✓

**Events:** 1-2 minor incidents
- Random teleportation OR Blood decals appear/disappear
- Spooky sound at predetermined position

### Day 3 (Escalation Begins)
**Tasks:**
- Lube Engine Blades ✓
- Sample Oxygen ✓
- Download Data ✓
- Upload Data ✓
- Terminal Game ✓
- **Replace Generator Heatsink** (use the wrench ordered Day 2)

**Events:** 2-3 more aggressive
- Entity follows player around (more persistent)
- Smaller black hole appears in hallway
- Fire appears (must be put out)

### Day 4 (Breaking Point)
**Tasks:**
- Align Telescope ✓
- **Oxygen Tank Filter Failure** (emergency task)
- Download Data ✓
- Upload Data ✓
- **Investigate Anomalous Readings** (reveals story)
- **Attempt Communication with Earth** (gets no response)

**Events:** 3-4 major incidents
- Shadowy figure at end of hall
- Player vision goes wonky
- Flesh appears on walls
- Lightning/smoke wall blocks path

### Day 5 (Final Descent)
**Tasks:**
- **Emergency Systems Check** (reveals station damage)
- **Final Data Transmission Attempt** (fails)
- **Prepare Escape Pod** (unlocks ending paths)
- **Choose Your Fate** (triggers ending selection)

**Events:** Constant supernatural activity
- Eyes appear all around station
- Environment outside gets darker
- Mysterious Obelisk appears
- Black hole accretion disk color changes

## Secret Ending Unlock Conditions

### Secret Ending 1: "The Researcher's Gambit"
**Unlock Condition:** Complete all optional data analysis tasks on Days 1-3 + find hidden research logs
**Trigger:** During Day 5, option appears to "Activate Experimental Protocol"
**Outcome:** Player attempts to reverse the black hole formation

### Secret Ending 2: "The Witness"
**Unlock Condition:** Never flee from supernatural events (stand still during Entity encounters, don't run from shadows)
**Trigger:** On Day 5, Entity offers direct communication
**Outcome:** Player learns the truth about what happened to previous crew

## Main Ending Paths (Day 5)

### Ending 1: Consumed
**Default if player makes no choice or fails escape preparation**
Player and station sucked into black hole

### Ending 2: Escape
**Unlocked by completing "Prepare Escape Pod" task**
Player flees in escape pod

### Ending 3: Acceptance
**Unlocked by interacting with Mysterious Obelisk**
Player willingly merges with black hole

## Event Escalation Pattern

### Days 1-2: Subtle
- Brief appearances
- Environmental changes
- Audio cues

### Days 3-4: Active
- Direct interaction required
- Multiple simultaneous events
- System failures

### Day 5: Overwhelming
- Constant supernatural presence
- Multiple overlapping crises
- Reality breaking down

## Key Story Beats to Add

**Day 3:** Player finds log revealing previous crew's fate
**Day 4:** Communication systems show Earth is gone/changed
**Day 5:** Player realizes they may be the last human alive

## Implementation Notes

- Each day should have 1 fewer normal tasks and 1-2 more emergency/story tasks
- Events should interrupt tasks more frequently as days progress
- Secret ending conditions should be trackable via state manager
- Day 5 should feel completely different - more horror, less routine



Intro Cutscene

The year is 2125, humanity has achieved interstellar colonization, in desperation to escape their failing bio-sphere humans spread themselves too thin.

Communication across the vast cosmic distances proved to be a challenge, outpost after outpost keep vanishing leaving only a few pleading final words arriving years after disaster

In order to survive, mankind must develop better communication methods, they must learn to bend space time to their whime. Thus they started covering the only known natural phenemenon which does the same

Black holes

They began searching for the holy grail, a stable microsingularity, and with time it was found. SJ-1765 or the Sejanus Singularity was a perfect canditate for research.

The Thoth Observatory station was constructed in stable orbit, and researchers have been sent one after another to gather data from this miraculous stellar object.

The fact that few of them return upon their rotation coming to its end is irrelevant; what mankind stands to gain from this research is too great.

Your rotation begins now.

The cosmos is unforgiving to those lost within it

EncryptionKey 

651a9f4efa9704561dc8770630ea9de91868846847222dc13a521d64cf5ed009