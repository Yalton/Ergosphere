# Godot 4.3 Post-Processing Shader Effects Collection

This document contains a collection of post-processing shader effects for use with Godot 4.3's new compositor feature. These effects can be added to your game to create various visual styles and atmospheres.

## How to Use These Shaders

1. Create a script that extends `CompositorEffect` (see implementation documentation)
2. Add a Compositor resource to your WorldEnvironment or Camera3D node
3. Add your CompositorEffect to the Compositor
4. Copy the shader code you want from below into the shader_code property
5. Adjust parameters as needed

---

## PS1 Style Pixelation Effect

Creates a PlayStation 1 aesthetic with low resolution, reduced color depth, texture wobble, and dithering.

```glsl
// PS1 style pixelation and color reduction
// Set resolution (lower = more pixelated)
float resolution = 320.0; // Classic PS1 horizontal resolution was around 320
float pixel_size = params.raster_size.x / resolution;

// Calculate the pixelated coordinate
ivec2 pixelated_coord = ivec2(floor(vec2(uv) / pixel_size) * pixel_size);

// Sample the color at the pixelated coordinate
vec4 pixelated_color = imageLoad(color_image, pixelated_coord);

// Reduce color depth (PS1 used 5:5:5 RGB color)
vec3 reduced_color = floor(pixelated_color.rgb * 32.0) / 32.0;

// Apply texture wobble/jitter (characteristic of PS1)
// Adjust strength for more or less wobble
float wobble_strength = 0.5;
float wobble = sin(float(uv.y) * 0.1) * wobble_strength;
ivec2 wobble_coord = ivec2(pixelated_coord.x + int(wobble), pixelated_coord.y);
wobble_coord = clamp(wobble_coord, ivec2(0), size - ivec2(1));

// Use the wobbled color
vec4 final_color = imageLoad(color_image, wobble_coord);
final_color.rgb = floor(final_color.rgb * 32.0) / 32.0;

// Apply affine texture mapping simulation (loss of perspective correction)
// This creates the "swimming" effect of PS1 textures
float affine_factor = 0.002;
float distance_from_center = length(vec2(uv) - vec2(size) * 0.5);
final_color.rgb = mix(final_color.rgb, pixelated_color.rgb, affine_factor * distance_from_center);

// Combine with some dithering for that classic look
float dither_pattern = fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 43758.5453);
final_color.rgb += (dither_pattern - 0.5) / 32.0;

color = final_color;
```

---

## VHS/VCR Effect

Simulates the look of old VHS tapes with scanlines, noise, and color distortion.

```glsl
// VHS/VCR Effect
// Creates scanlines, noise, and color distortion like old VHS tapes
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
color.rgb = mix(color.rgb, vec3(dot(color.rgb, vec3(0.299, 0.587, 0.114))), 0.1); // Slight desaturation
```

---

## Film Grain Effect

Adds a subtle grain texture, warm coloring, and vignette to create a film-like appearance.

```glsl
// Film Grain Effect
// Adds subtle grain like traditional film
float grain_strength = 0.05; // Adjust for more/less grain
float random = fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 43758.5453);
vec3 grain = vec3(random) * grain_strength;

// Slightly warm the colors for film feel
vec3 warmer = vec3(1.05, 1.0, 0.9); // Slight sepia tone

// Vignette effect (darker corners)
vec2 center = vec2(size) * 0.5;
float distance_from_center = length(vec2(uv) - center) / length(center);
float vignette = 1.0 - distance_from_center * 0.5;

color.rgb = (color.rgb * warmer + grain) * vignette;
```

---

## Retro CRT Monitor Effect

Simulates an old CRT monitor with RGB subpixels, scanlines, and screen curvature.

```glsl
// Retro CRT Monitor Effect
// Simulate a CRT monitor with RGB subpixels, scanlines and screen curvature
// RGB subpixel effect
ivec2 grid_position = ivec2(uv.x % 3, uv.y);
float r = (grid_position.x == 0) ? 1.0 : 0.2;
float g = (grid_position.x == 1) ? 1.0 : 0.2;
float b = (grid_position.x == 2) ? 1.0 : 0.2;

// Scanlines
float scanline_intensity = 0.1;
float scanline = sin(uv.y * 200.0) * scanline_intensity;

// Screen curvature - makes edges bulge out slightly
vec2 cc = vec2(uv) / vec2(size); // Normalized coordinates
cc = (cc - 0.5) * 2.0; // Convert to -1 to 1 range
float d = length(cc);
float distortion = 0.1; // Screen curve amount
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

## Bloom/Glow Effect

Makes bright areas of the image glow by blurring and intensifying them.

```glsl
// Bloom/Glow Effect
// Makes bright areas glow by blurring the bright parts
// First, extract bright parts
float brightness = dot(color.rgb, vec3(0.299, 0.587, 0.114));
vec3 bright_parts = (brightness > 0.7) ? color.rgb : vec3(0.0);

// Then blur the bright parts (simple 9-tap blur)
vec3 bloom = vec3(0.0);
int blur_radius = 4;
int samples = 0;

for (int x = -blur_radius; x <= blur_radius; x += 2) {
    for (int y = -blur_radius; y <= blur_radius; y += 2) {
        ivec2 sample_pos = uv + ivec2(x, y);
        if (sample_pos.x >= 0 && sample_pos.y >= 0 && sample_pos.x < size.x && sample_pos.y < size.y) {
            vec4 sample_color = imageLoad(color_image, sample_pos);
            float sample_brightness = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
            vec3 sample_bright = (sample_brightness > 0.7) ? sample_color.rgb : vec3(0.0);
            bloom += sample_bright;
            samples++;
        }
    }
}

if (samples > 0) {
    bloom /= float(samples);
}

// Add bloom to original color
float bloom_intensity = 0.5;
color.rgb += bloom * bloom_intensity;
```

---

## Night Vision Effect

Creates a green-tinted night vision look with noise, scanlines, vignette, and occasional light flares.

```glsl
// Night Vision Effect
// Green-tinted effect with noise like night vision goggles
// Add noise
float noise_intensity = 0.1;
float rand = fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 43758.5453);
float noise = rand * noise_intensity;

// Green tint
vec3 night_vision_color = vec3(0.0, 1.0, 0.0); // Pure green
float brightness = dot(color.rgb, vec3(0.299, 0.587, 0.114));

// Vignette effect for edges
vec2 center = vec2(size) * 0.5;
float distance_from_center = length(vec2(uv) - center) / length(center);
float vignette = 1.0 - distance_from_center * 1.2;
vignette = clamp(vignette, 0.0, 1.0);

// Fine scanlines
float scanline = abs(sin(uv.y * 100.0)) * 0.1;

// Combine effects
color.rgb = vec3(brightness) * night_vision_color;
color.rgb += noise - scanline;
color.rgb *= vignette;
// Add hotspot flare in center occasionally
if (rand > 0.997) {
    float flare = 1.0 - distance_from_center * 5.0;
    flare = clamp(flare, 0.0, 1.0) * 2.0;
    color.rgb += flare * night_vision_color;
}
```

---

## Comic Book / Cel Shading Effect

Transforms the scene to look like a comic book with flat colors, edges, and stipple patterns.

```glsl
// Comic Book / Cel Shading Effect
// Makes 3D scenes look like a comic book with bold edges and flat colors
// Extract edges
ivec2 offsets[8] = ivec2[8](
    ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
    ivec2(-1, 0),                ivec2(1, 0),
    ivec2(-1, 1),  ivec2(0, 1),  ivec2(1, 1)
);

float edge = 0.0;
float edge_threshold = 0.1;
vec4 current = color;

for (int i = 0; i < 8; i++) {
    ivec2 sample_pos = uv + offsets[i];
    if (sample_pos.x >= 0 && sample_pos.y >= 0 && sample_pos.x < size.x && sample_pos.y < size.y) {
        vec4 sample_color = imageLoad(color_image, sample_pos);
        edge += length(current.rgb - sample_color.rgb);
    }
}

// Quantize colors to create flat comic look
int color_levels = 5;
vec3 quantized = floor(color.rgb * float(color_levels)) / float(color_levels);

// Create stipple/dot pattern for shading
float stipple_size = 8.0;
vec2 stipple_pos = mod(vec2(uv), stipple_size);
float stipple = length(stipple_pos - stipple_size/2.0) < (stipple_size/2.0 * brightness) ? 1.0 : 0.7;

// Combine
float edge_line = edge > edge_threshold ? 0.0 : 1.0;
color.rgb = quantized * edge_line * stipple;
```

---

## Underwater Effect

Creates a wavy, blue-tinted underwater look with caustic light patterns and occasional bubbles.

```glsl
// Underwater Effect
// Simulates being underwater with blue tint, caustics, and wavy distortion
// Blue tint
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
// Add bubbles
if (fract(sin(dot(vec2(uv) + time * 10.0, vec2(12.9898, 78.233))) * 43758.5453) > 0.997) {
    color.rgb += vec3(0.7);
}
```

---

## Thermal Vision Effect

Creates a heat map visualization with blue (cold) to red (hot) gradient based on brightness.

```glsl
// Thermal Vision Effect
// Heat detection look with a gradient from blue (cold) to red (hot)
// Compute brightness as heat
float heat = dot(color.rgb, vec3(0.299, 0.587, 0.114));

// Create heat map colors
vec3 cold = vec3(0.0, 0.0, 1.0); // Blue
vec3 medium = vec3(1.0, 1.0, 0.0); // Yellow
vec3 hot = vec3(1.0, 0.0, 0.0); // Red

// Mix based on heat level
vec3 thermal_color;
if (heat < 0.33) {
    thermal_color = mix(cold, medium, heat * 3.0);
} else if (heat < 0.66) {
    thermal_color = mix(medium, hot, (heat - 0.33) * 3.0);
} else {
    thermal_color = hot;
}

// Add scanlines for electronic display feel
float scanline = sin(uv.y * 200.0) * 0.05;

// Add some noise
float noise = fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 43758.5453) * 0.1;

color.rgb = thermal_color - scanline + noise;
```

---

## Glitch Effect

Creates digital distortions and artifacts like screen tearing, RGB splitting, and noise.

```glsl
// Glitch Effect
// Creates digital glitches and artifacts
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

// Block glitches
if (fract(time_seed * 1.7) < 0.01) {
    ivec2 block_pos = ivec2(floor(uv.x / 16.0) * 16.0, floor(uv.y / 16.0) * 16.0);
    block_pos = clamp(block_pos, ivec2(0), size - ivec2(16));
    color = imageLoad(color_image, block_pos);
}

// Vertical color bars
if (fract(time_seed * 1.1) < 0.005) {
    color.rgb = vec3(fract(uv.x / 64.0 + time_seed * 0.5));
}
```

---

## Chromatic Aberration

Separates RGB channels to create a lens distortion effect that intensifies toward the edges.

```glsl
// Chromatic Aberration
// Splits RGB channels for a lens distortion effect
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

// Add slight radial increase to effect (stronger at edges)
vec2 center = vec2(size) * 0.5;
float distance_from_center = length(vec2(uv) - center) / length(center);
color.rgb = mix(g_color.rgb, color.rgb, distance_from_center * 0.8);
```

---

## Outline/Edge Detection Effect

Highlights the edges of objects in the scene with customizable colored outlines.

```glsl
// Outline/Edge Detection Effect
// Highlights edges of objects in the scene
ivec2 offsets[8] = ivec2[8](
    ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
    ivec2(-1, 0),                ivec2(1, 0),
    ivec2(-1, 1),  ivec2(0, 1),  ivec2(1, 1)
);

float edge = 0.0;
vec4 current = color;

for (int i = 0; i < 8; i++) {
    ivec2 sample_pos = uv + offsets[i];
    if (sample_pos.x >= 0 && sample_pos.y >= 0 && sample_pos.x < size.x && sample_pos.y < size.y) {
        vec4 sample_color = imageLoad(color_image, sample_pos);
        edge += length(current.rgb - sample_color.rgb);
    }
}

// Threshold and create outline
float outline_threshold = 0.2;
float outline = edge > outline_threshold ? 1.0 : 0.0;

// Original with outlines (you can change outline color)
vec3 outline_color = vec3(1.0, 0.5, 0.0); // Orange outline
color.rgb = mix(color.rgb, outline_color, outline);
```

---

## Oil Painting Effect

Gives the scene a painted look with color quantization and canvas texture.

```glsl
// Oil Painting Effect
// Gives the scene a painted look
int radius = 5;
int neighbor_count = (2 * radius + 1) * (2 * radius + 1);
vec3 color_sum = vec3(0.0);
float weight_sum = 0.0;

// Simplified oil paint effect with color quantization
for (int dx = -radius; dx <= radius; dx += 2) {
    for (int dy = -radius; dy <= radius; dy += 2) {
        ivec2 sample_pos = uv + ivec2(dx, dy);
        if (sample_pos.x >= 0 && sample_pos.y >= 0 && sample_pos.x < size.x && sample_pos.y < size.y) {
            vec4 sample_color = imageLoad(color_image, sample_pos);

            // Quantize
            int intensity_levels = 8;
            vec3 quantized = floor(sample_color.rgb * float(intensity_levels)) / float(intensity_levels);

            // Add to weighted sum
            float weight = 1.0 / (1.0 + float(dx*dx + dy*dy));
            color_sum += quantized * weight;
            weight_sum += weight;
        }
    }
}

// Normalize
if (weight_sum > 0.0) {
    color.rgb = color_sum / weight_sum;
}

// Add slight canvas texture
float canvas_texture = fract(sin(dot(vec2(uv) * 0.1, vec2(12.9898, 78.233))) * 43758.5453) * 0.05;
color.rgb += vec3(canvas_texture);
```

---

## Miniature/Tilt-Shift Effect

Creates a diorama-like effect by applying selective focus and color enhancement.

```glsl
// Miniature/Tilt-Shift Effect
// Makes the scene look like a miniature model
// Define the in-focus band
float focus_center = 0.5; // Position of the in-focus band (0.0-1.0)
float focus_width = 0.2; // Width of the in-focus band

// Calculate normalized vertical position
float v_pos = float(uv.y) / float(size.y);

// Calculate blur amount based on distance from focus band
float blur_amount = abs(v_pos - focus_center) / focus_width;
blur_amount = clamp(blur_amount, 0.0, 1.0);

// Apply blur for out-of-focus areas
vec3 blurred_color = vec3(0.0);
int blur_radius = int(15.0 * blur_amount);
int samples = 0;

for (int dx = -blur_radius; dx <= blur_radius; dx += 2) {
    for (int dy = -blur_radius; dy <= blur_radius; dy += 2) {
        ivec2 sample_pos = uv + ivec2(dx, dy);
        if (sample_pos.x >= 0 && sample_pos.y >= 0 && sample_pos.x < size.x && sample_pos.y < size.y) {
            vec4 sample_color = imageLoad(color_image, sample_pos);
            blurred_color += sample_color.rgb;
            samples++;
        }
    }
}

if (samples > 0) {
    blurred_color /= float(samples);
}

// Add slight color enhancement for miniature look
vec3 enhanced = color.rgb * 1.2; // Increase saturation
enhanced = clamp(enhanced, 0.0, 1.0);

// Mix based on blur amount
color.rgb = mix(enhanced, blurred_color, blur_amount * 0.8);
```

---

## Combining Effects

To combine multiple effects, you'll need to carefully merge the code and manage variables with overlapping names. The best approach is to:

1. Choose which effects you want to combine
2. Rename variables that conflict between effects
3. Process each effect in sequence, passing the output of one effect as input to the next
4. Adjust parameters for each effect to achieve the desired balance

For example, you might combine the PS1 effect with VHS for a retro gaming look, or Bloom with Night Vision for a sci-fi surveillance aesthetic.

## Tips for Performance

- More complex effects (particularly ones with larger blur radii or many sample points) will have a higher performance cost
- Consider implementing a quality slider that adjusts parameters like blur radius or sample count based on performance needs
- Test on lower-end hardware to ensure your effects remain performant

## Conclusion

These shader effects provide a starting point for creating unique visual styles in your Godot 4.3 projects. Feel free to modify, combine, and experiment with these effects to create your own custom look.