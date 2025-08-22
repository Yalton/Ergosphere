
Get feedback 

Fix issues 

Get more feedback 

Write up all the log files 

Test more and polish more 

Scan anomaly light 
- Basically the same as it is now, except it doesent shatter 

Scan Anomaly heavy 
- Anomaly scanner shatters, and iconoclast spawns 

Finish polishing, then publish it 


## Misc 

Fix telescope terminal

### Audio

~~Eating a meal needs an sfx~~

Iconoclast needs sting for when it spawns

## Bug

Stats screen is broken  Incorrect stats displayed

Ordering system seems broken 
    - Seems like once a container is filled up it never tells the interface it is emptied so we cannot order new items to it 
    - Test this 

Resolution does nothing in full screen, only windowed 

Potential iconoclast warning 
    - W 0:01:06:373   set_transform: An invalid transform was passed to physics body '<unknown>'. The basis of the transform was singular, which is not supported by Jolt Physics. This is likely caused by one or more axes having a scale of zero. The basis (and thus its scale) will be treated as identity.
  <C++ Source>  modules/jolt_physics/objects/jolt_body_3d.cpp:545 @ set_transform()
