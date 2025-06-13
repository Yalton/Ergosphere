Alright I need to revamp the entire event system, basically it should be entirely separate from the task system 

Events should fall into a few categories 

- Planned
- Unplanned 
- Hybrid 

These categories determine whether the event was always going to occur at a schedule time, or if it was just triggered based on some conditions 

Then we have two severity scores 

- Tension
- Disruption 

Events serve two purpose, to disrupt the player, and to apply tension to the player 

But events that do the same thing very well should not occur at the same time 

Lets talk about how they are actually triggered 

Unplanned events have specific triggers and methods we need to go into

Events can have pre-requisites for their execution, a major pre-req would be current day, but others could be related to the current game state 

Events must also be spaced and balanced carefully, we dont want too many, but we dont want too few 

For this lets talk about Cooldowns and Chance 

Cool-downs are unique to each event, these tell you when events can be triggered after another event and they are sorted by severity i.e a Severity 3 in disruption could occur, this Sev3 disruptive event could have a cooldown of 20 seconds. What this means is no other events with that level of Disruptiveness can be executed until this cooldown is finished, however a Sev2 Disruptive event could occur during this time

Cooldowns should also be somewhat randomized, i.e plus or minus half of their value in variation

Chance put very simply is the chance that an event will occur. Once an event can occur, we then run it against chance to see if it will occur. We evaluate this every few seconds or so until an event triggers.

Lets talk modifiers 

Modifiers can either modify chance, or cooldowns

All of these modifiers should be variables that we can use to compute chance at the time of evaluation, no modifying the base value 

Insanity is the main cooldown modifier, there will be others but this one is the most prevalent 
Insanity is a player value that can increase or decrease with certain events/criteria 
Insanity should increase the chance, and decrease cooldown timers with its scale, i.e the more insane the player is the more events will happen 
Another modifier would be task completion, 2 seconds after a task is completed chance should multiplied by 2 for 5 seconds, then return it to its normal value 
Another modifier is current day, Each day beyond day 1 increases chance by 10% and decreased cooldown by 10%
Other modifiers are certain game criteria, i.e is the player following a secret quest tree, that we can implement later 

Then we just trigger events based off of this, we evaluate if an event can be executed and if it can, we do it 

Obviously we should keep in support for forced event executions, this is how Planned events will occur, Planned events just bypass everything else and execute instantly 