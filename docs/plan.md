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


Clean up code

Simplify task resources

----
Sleep camera tween needs fixing

Impact sounds on props

Sounds coming through walls should be muted
----


Using toilet is brown note

Add Typable terminal


Make failing emergency tasks have consequences

Game against Hermes

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