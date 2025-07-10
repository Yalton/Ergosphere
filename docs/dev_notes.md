# Development Notes & Bugs





## Claude Help


Play/test Game and take notes

Scan Anomalies on day 2 and have it show the anomalous entity, and then on day 4 anomaly explodes 

Password Revelation - During power failure, emergency lighting creates shadows that spell out admin password on wall

## Monster

Create creates dark zone

## Lore/Setting

Figure out the monster
Nail the story 
Brighten it on day 1


## Manual

Floor Look bad 
- Re-make floor
Add SFX to stuff
Test Systems thouroughly
New Hermes voice

### Notes

Item on ground sometimes not let me pick it up
Visible on screen should check if mesh is in the way 

---


Event points acrue too quickly 

## Cant replicate 

Go to sleep task not removed when new tasks assigned 
Object fall through floor 




## Current Known Bugs

## Misc 

Make entity impossible to record with recording software

Make entity/events dissapear when game is paused

Get Power outage to use new effects node


### Critical Issues
- Power Lever animation plays twice
- Hard Drive sometimes falls through floor  
- Carried objects can collide with player
- It is impossible to reserve less capacity than is currently available

### UI/Polish Issues
- Text should be centered and very easily readable on the UI
- Make the text bigger - all of it
- Make align telescope more obvious

### Audio Issues  
- They don't like Hermes voice (need voice actor)
- Brown note still has issues
- Notes still teleport around

### Level Design Issues
- Still too dark (maybe works though)
- Too clean, too static - add moving parts and decals
- Need more rigidbodies

## Development Philosophy

**KEEP ALL CHANGES AS SIMPLE AS POSSIBLE - AVOID OVER-ENGINEERING AT ALL COSTS**

- Simple solutions over everything else
- Over-engineering is a death sentence  
- Rather get it working than get it perfect
- Brutal honest and realistic takes over "maybes" and "it can work"

## Debug Logging Guidelines

**When adding print statements to anything, use the DebugLogger Singleton and register the Module with the DebugLogger if not already registered.**

```gdscript
# Example usage
DebugLogger.register_module("ModuleName", enable_debug)
DebugLogger.info(module_name, "Message here")
```

## Code Comments Standard

**Keep description comments on export variables:**

```gdscript
## Longer description of what the player needs to do. Can be shown as tooltip or help text.
@export var task_description: String = ""
```

The text after ## is very important for documentation.

## Art & Asset Guidelines

### Simple Station Props for Easy Modeling

#### Basic Geometric Props (Cylinders)
- **Cans** - Soda, energy drinks, spray paint, air freshener
- **Batteries** - Various sizes (AA, D-cell)  
- **Rolls** - Paper towels, toilet paper, tape rolls
- **Thermos/bottles** - Simple cylinder with cap
- **Fire extinguisher** - Cylinder with nozzle
- **Oxygen canisters** - Small emergency air
- **Pipe sections** - Spare parts

#### Boxes/Rectangles  
- **Cardboard boxes** - Various sizes, some open
- **Storage crates** - Plastic or metal
- **Books** - Just rectangles with simple textures
- **Tablets/datapads** - Flat rectangles
- **Clipboards** - Rectangle with clip
- **Food packages** - Cereal boxes, MREs
- **Tissue box** - Rectangle with opening

#### Spheres/Simple Shapes
- **Balls** - Tennis ball, stress ball, ping pong
- **Light bulbs** - Sphere with base  
- **Oranges/apples** - Just textured spheres
- **Pills/vitamins** - Bottle of spheres
- **Marbles** - In a jar or scattered

#### Easy Combinations
- **Wrench** - Rectangle handle + hexagon head
- **Hammer** - Cylinder handle + box head
- **Screwdriver** - Cylinder handle + cylinder tip
- **Mug** - Cylinder + handle (torus)
- **Bucket** - Tapered cylinder
- **Traffic cone** - Tapered cylinder (space safety)

#### Texture-Dependent Props
- **Patches/badges** - Flat circles/rectangles
- **Stickers** - Flat shapes
- **Money/credits** - Flat rectangles  
- **ID badges** - Rectangle with lanyard
- **Maps** - Rolled cylinder or flat
- **Posters** - Rolled or flat planes

### UI Theme Colors
- **00d9ff** - Blue
- **1c1c1c93** - Black (transparent)
- **00ff00** - Green
- **00ff005c** - Green (transparent)

## Audio Attribution

### Sound Effects Used
- [Electric buzz sound](https://freesound.org/people/visualasylum/sounds/329778/)
- [Bathroom Sound](https://freesound.org/people/snapssound/sounds/700470/)
- [Steam Hiss](https://freesound.org/people/jesabat/sounds/119741/)
- [Metal Open](https://freesound.org/people/DWOBoyle/sounds/151575/)

## Feedback from Testing

### General Feedback
- They don't like Hermes voice → Add more rigidbodies (?)
- Too dark → Make everything lighter or blacken certain parts  
- Maybe done with lighting improvements

### Missing Features to Add
- Add reverb to sounds that are far from player and have a wall in the way
- Make more events
- Make failing emergency tasks have consequences  
- Simplify task resources

## Performance Considerations

### Post-Processing Shader Effects
- More complex effects (particularly ones with larger blur radii or many sample points) will have higher performance cost
- Consider implementing quality slider that adjusts parameters like blur radius or sample count  
- Test on lower-end hardware to ensure effects remain performant

### General Optimization
- Focus on creating complete, functional solutions rather than perfect ones
- Build complete, functional experiences with meaningful interactivity
- Ensure all artifacts are comprehensive and ready for immediate use

## Implementation Priorities

1. **Fix critical bugs** (power lever, hard drive physics, object collision)
2. **Improve UI readability** (bigger text, better centering)
3. **Add environmental details** (moving parts, decals, more physics objects)
4. **Sound improvements** (reverb system, voice actor for Hermes)
5. **Event system expansion** (more events, consequences for failures)
6. **Task resource simplification**