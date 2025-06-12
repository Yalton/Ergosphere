# Shaders & Technical Implementation

## Post-Processing Shader Effects for Godot 4.3

### How to Use These Shaders

1. Create a script that extends `CompositorEffect`
2. Add a Compositor resource to your WorldEnvironment or Camera3D node
3. Add your CompositorEffect to the Compositor
4. Copy the shader code into the shader_code property
5. Adjust parameters as needed

---

## Horror-Specific Effects

### VHS/VCR Effect (Perfect for retro horror aesthetic)

```glsl
// VHS/VCR Effect - Creates scanlines, noise, and color distortion like old VHS tapes
float time = float(uv.y + uv.x) * 0.01; // Simulated time value
float scanline = sin(uv.y * 800.0) * 0.04;
float noise = fract(sin(dot(vec2(uv) + time, vec2(12.9898, 78.233))) * 43758.5453) * 0.07;

// RGB shift effect
ivec2 rb_shift = ivec2(int(sin(time * 0.5) * 2.0), 0);
vec4 color_r = imageLoad(color_image, clamp(uv + rb_shift, ivec2(0), size - ivec2(1)));
vec4 color_b = imageLoad(color_image, clamp(uv - rb_shift, ivec2(0), size - ivec2(1)));

// Combine for VHS effect
color.r = color_r.r;
color.b = color_b.b;
color.rgb += vec3(noise) - scanline;
color.rgb = mix(color.rgb, vec3(dot(color.rgb, vec3(0.299, 0.587, 0.114))), 0.1);
```

### Glitch Effect (For entity manifestations)

```glsl
// Glitch Effect - Creates digital distortions and artifacts
float intensity = 0.3;
float time_seed = float(uv.y) * 0.01;

// Random horizontal shifts
if (fract(time_seed * 3.7) < 0.05) {
    int shift = int(10.0 * fract(time_seed * 9.1));
    if (fract(time_seed * 7.3) < 0.5) {
        shift = -shift;
    }

    ivec2 shifted_coord = ivec2(uv.x + shift, uv.y);
    shifted_coord = clamp(shifted_coord, ivec2(0), size - ivec2(1));

    if (fract(time_seed * 5.9) < 0.5) {
        // RGB split
        if (int(fract(time_seed * 4.1) * 3.0) == 0) {
            color.r = imageLoad(color_image, shifted_coord).r;
        } else if (int(fract(time_seed * 4.1) * 3.0) == 1) {
            color.g = imageLoad(color_image, shifted_coord).g;
        } else {
            color.b = imageLoad(color_image, shifted_coord).b;
        }
    } else {
        // Complete line shift
        color = imageLoad(color_image, shifted_coord);
    }
}

// Noise and static
if (fract(time_seed * 2.3) < 0.02) {
    float noise = fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 43758.5453);
    color.rgb = vec3(noise);
}
```

### Chromatic Aberration (For black hole distortion effects)

```glsl
// Chromatic Aberration - Splits RGB channels for lens distortion
float aberration_strength = 4.0; // Adjust for more/less effect

// Get RGB components from slightly offset positions
ivec2 r_offset = ivec2(int(-aberration_strength), 0);
ivec2 g_offset = ivec2(0, 0);
ivec2 b_offset = ivec2(int(aberration_strength), 0);

// Sample the color at each offset position
vec4 r_color = imageLoad(color_image, clamp(uv + r_offset, ivec2(0), size - ivec2(1)));
vec4 g_color = color; // Current pixel
vec4 b_color = imageLoad(color_image, clamp(uv + b_offset, ivec2(0), size - ivec2(1)));

// Create new color with RGB components from different offsets
color.r = r_color.r;
color.g = g_color.g;
color.b = b_color.b;

// Add radial increase to effect (stronger at edges)
vec2 center = vec2(size) * 0.5;
float distance_from_center = length(vec2(uv) - center) / length(center);
color.rgb = mix(g_color.rgb, color.rgb, distance_from_center * 0.8);
```

### Retro CRT Monitor Effect (For terminal displays)

```glsl
// Retro CRT Monitor Effect - Simulate old CRT with RGB subpixels and scanlines
// RGB subpixel effect
ivec2 grid_position = ivec2(uv.x % 3, uv.y);
float r = (grid_position.x == 0) ? 1.0 : 0.2;
float g = (grid_position.x == 1) ? 1.0 : 0.2;
float b = (grid_position.x == 2) ? 1.0 : 0.2;

// Scanlines
float scanline_intensity = 0.1;
float scanline = sin(uv.y * 200.0) * scanline_intensity;

// Screen curvature
vec2 cc = vec2(uv) / vec2(size);
cc = (cc - 0.5) * 2.0;
float d = length(cc);
float distortion = 0.1;
vec2 curved_uv = uv;
if (d > 0.0) {
    float z = 1.0 + d * distortion;
    curved_uv = uv + (cc / z) * size * distortion;
}
curved_uv = clamp(curved_uv, ivec2(0), size - ivec2(1));
vec4 curved_color = imageLoad(color_image, curved_uv);

// Final combined effect
vec3 crt_color = curved_color.rgb * vec3(r, g, b);
crt_color -= scanline;
color.rgb = crt_color;
```

---

## Atmospheric Effects

### Film Grain Effect (For general atmosphere)

```glsl
// Film Grain Effect - Adds subtle grain and warm coloring
float grain_strength = 0.05;
float random = fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 43758.5453);
vec3 grain = vec3(random) * grain_strength;

// Slightly warm the colors
vec3 warmer = vec3(1.05, 1.0, 0.9);

// Vignette effect (darker corners)
vec2 center = vec2(size) * 0.5;
float distance_from_center = length(vec2(uv) - center) / length(center);
float vignette = 1.0 - distance_from_center * 0.5;

color.rgb = (color.rgb * warmer + grain) * vignette;
```

### Underwater Effect (For entity influence)

```glsl
// Underwater Effect - Wavy, blue-tinted with caustic patterns
vec3 underwater_color = vec3(0.0, 0.3, 0.8);

// Caustics (light patterns through water)
float caustic = sin(uv.x * 15.0 + time) * sin(uv.y * 15.0 + time * 0.8) * 0.25 + 0.75;

// Distortion effect (wavy)
float distortion_strength = 3.0;
float wave_x = sin(uv.y * 0.05 + time) * distortion_strength;
float wave_y = sin(uv.x * 0.05 + time * 0.8) * distortion_strength;
ivec2 distorted_uv = ivec2(uv.x + int(wave_x), uv.y + int(wave_y));
distorted_uv = clamp(distorted_uv, ivec2(0), size - ivec2(1));
vec4 distorted_color = imageLoad(color_image, distorted_uv);

// Combine effects
color.rgb = mix(distorted_color.rgb, underwater_color, 0.2) * caustic;
```

---

## Technical Systems

### Performance Optimization Tips

1. **Quality Scaling**: Implement quality slider that adjusts blur radius and sample count
2. **Platform Detection**: Lower effect intensity on mobile/lower-end hardware
3. **Effect Combining**: Merge multiple simple effects rather than layering complex ones
4. **LOD System**: Reduce effect complexity when framerate drops

### Effect Combination Strategy

```glsl
// Example: Combining VHS + Chromatic Aberration for retro horror
// 1. Apply chromatic aberration first
// 2. Then apply VHS effect to the result
// 3. Manage variable naming to avoid conflicts
```

### Debugging Shaders

- Use `console.log()` equivalent debugging in shader development
- Test effects individually before combining
- Start with low intensity values and increase gradually
- Always provide fallback/disable options

## Audio Technical Implementation

### 3D Audio System for Events
- **Distance attenuation**: Sounds fade with distance from source
- **Occlusion**: Walls block and muffle sounds appropriately  
- **Reverb zones**: Different areas have different acoustic properties
- **Binaural positioning**: Accurate left/right ear positioning for headphone users

### Dynamic Audio Mixing
- **Adaptive music**: Changes based on player stress/event intensity
- **Procedural ambience**: Layered ambient sounds that respond to game state
- **Audio event triggering**: Sounds triggered by player actions and supernatural events

### SAM Voice Synthesis Integration
```
Settings for Hermes