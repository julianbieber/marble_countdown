#import bevy_sprite::{mesh2d_view_bindings, mesh2d_functions}

struct Vertex {
    @builtin(instance_index) instance_index: u32,
    @location(0) position: vec3<f32>,
    // Assuming UVs are at location 2 (adjust if different in your pipeline setup)
    @location(2) uv: vec2<f32>,
    // Add other attributes like normals or colors if needed
    // @location(1) normal: vec3<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    // Pass UVs to the fragment shader
    @location(0) uv: vec2<f32>,
};

@vertex
fn vertex(v: Vertex) -> VertexOutput {
let a = vec4f(0.0);
    a.
    var out: VertexOutput;
    let model = mesh2d_functions::get_world_from_local(vertex.instance_index);
    out.clip_position = mesh2d_functions::mesh2d_position_local_to_clip(model, vec4<f32>(vertex.position, 1.0));
    out.uv = vertex.uv; // Pass UVs through
    return out;
}




// Helper function: 4D vector permutation
fn permute(x: vec4f) -> vec4f {
  // Ensure positive results for modulo with 289.0
  let x_mod = x % vec4f(289.0);
  let result = ((x_mod * 34.0) + 1.0) * x_mod;

  return result % vec4f(289.0);
  // Alternative approach if direct WGSL mod differs significantly from GLSL mod for negatives:
  // return mod(((x*34.0)+1.0)*x, vec4f(289.0)); // Direct translation, check behavior
}

// Helper function: Taylor inverse square root approximation
fn taylorInvSqrt(r: vec4f) -> vec4f {
  return vec4f(1.79284291400159) - (vec4f(0.85373472095314) * r);
}

// Main 3D Simplex Noise function
fn simplexNoise3D(v: vec3f) -> f32 {
  let C: vec2f = vec2f(1.0/6.0, 1.0/3.0); // Skewing factors
  let D: vec4f = vec4f(0.0, 0.5, 1.0, 2.0);
  // First corner (simplex origin)
  let i: vec3f = floor(v + dot(v, C.yyy));
  let x0: vec3f = v - i + dot(i, C.xxx);

  // Other corners
  // Determine which simplex we're in
  let g: vec3f = step(x0.yzx, x0.xyz);
  let l: vec3f = vec3f(1.0) - g;
  let i1: vec3f = min(g.xyz, l.zxy);
  let i2: vec3f = max(g.xyz, l.zxy);

  // x1 = x0 - i1 + C.xxx;
  // x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
  // x3 = x0 - 1.0 + C.zzz; // 3.0*C.x = 1/2 = C.z
  let x1: vec3f = x0 - i1 + C.xxx;
  let x2: vec3f = x0 - i2 + C.yyy; // Equivalent to C.xxx * 2.0
  let x3: vec3f = x0 - D.yyy; // Equivalent to x0 - vec3f(0.5) or x0 - 1.0 + 3.0 * C.xxx

  // Permutations for hash calculation
  // Ensure i is positive before modulo operation if necessary, though 289.0 is positive.
  let i_mod: vec3f = i % vec3f(289.0);

  let p = permute( permute( permute(
              i_mod.z + vec4f(0.0, i1.z, i2.z, 1.0 ))
            + i_mod.y + vec4f(0.0, i1.y, i2.y, 1.0 ))
            + i_mod.x + vec4f(0.0, i1.x, i2.x, 1.0 ));

  // Gradients: N*N points uniformly over a square, mapped onto an octahedron.
  // Constant assumes N=7; Adjust if necessary for different gradient patterns.
  let n_ : f32 = 0.142857142857; // 1.0/7.0
  let ns: vec3f = n_ * D.wyz - D.xzx;

  let j: vec4f = p - 49.0 * floor(p * ns.z * ns.z); // mod(p,N*N)

  let x_: vec4f = floor(j * ns.z);
  let y_: vec4f = floor(j - 7.0 * x_); // mod(j,N)

  let x: vec4f = x_ * ns.x + ns.yyyy;
  let y: vec4f = y_ * ns.x + ns.yyyy;
  let h: vec4f = vec4f(1.0) - abs(x) - abs(y);

  let b0: vec4f = vec4f(x.xy, y.xy);
  let b1: vec4f = vec4f(x.zw, y.zw);

  let s0: vec4f = floor(b0) * 2.0 + 1.0;
  let s1: vec4f = floor(b1) * 2.0 + 1.0;
  let sh: vec4f = -step(h, vec4f(0.0));

  let a0: vec4f = b0.xzyw + s0.xzyw * sh.xxyy;
  let a1: vec4f = b1.xzyw + s1.xzyw * sh.zzww;

  var p0: vec3f = vec3f(a0.xy, h.x);
  var p1: vec3f = vec3f(a0.zw, h.y);
  var p2: vec3f = vec3f(a1.xy, h.z);
  var p3: vec3f = vec3f(a1.zw, h.w);

  // Normalize gradients
  let norm: vec4f = taylorInvSqrt(vec4f(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 = p0 * norm.x;
  p1 = p1 * norm.y;
  p2 = p2 * norm.z;
  p3 = p3 * norm.w;

  // Mix final noise value Contributions from each corner are weighted.
  // Calculate squared distances and avoid negative contributions.
  var m: vec4f = max(vec4f(0.6) - vec4f(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), vec4f(0.0));
  m = m * m;
  m = m * m; // Cubic falloff

  // Sum contributions from the four corners
  let final_dot = dot(m, vec4f( dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3) ));

  // Rescale to output range (approximately -1.0 to 1.0)
  return 42.0 * final_dot;
}
// Inputs: center (vec2<f32>), radius (f32), angle_radians (f32)
fn point_on_circle(center: vec2<f32>, radius: f32, angle_radians: f32) -> vec2<f32> {
  let x = center.x + radius * cos(angle_radians);
  let y = center.y + radius * sin(angle_radians); // WGSL uses standard math coordinates (+Y up)
  return vec2<f32>(x, y);
}
// Define sphere properties
const SPHERE_RADIUS = 1.0;

// Define raymarching parameters
const MAX_STEPS = 80;
const MAX_DIST = 100.0;
const HIT_EPSILON = 0.001;

fn sphereSDF(p: vec3f) -> f32 {
    return length(p) - SPHERE_RADIUS;
}

fn calcNormal(p: vec3f) -> vec3f {
    let eps = vec2f(HIT_EPSILON, 0.0);
    return normalize(vec3f(
        sphereSDF(p + eps.xyy) - sphereSDF(p - eps.xyy),
        sphereSDF(p + eps.yxy) - sphereSDF(p - eps.yxy),
        sphereSDF(p + eps.yyx) - sphereSDF(p - eps.yyx)
    ));
}


const OKLAB2RGB_A : mat3x3<f32>  = mat3x3<f32>(
    vec3f(1.0, 1.0, 1.0),
    vec3f(0.3963377774, -0.1055613458, -0.0894841775),
    vec3f(0.2158037573, -0.0638541728, -1.2914855480) );

const OKLAB2RGB_B : mat3x3<f32>  = mat3x3<f32>(
    vec3f(4.0767416621, -1.2684380046, -0.0041960863),
    vec3f(-3.3077115913, 2.6097574011, -0.7034186147),
    vec3f(0.2309699292, -0.3413193965, 1.7076147010) );

fn oklab2rgb(oklab: vec3f) -> vec3f {
    let lms = OKLAB2RGB_A * oklab;
    return OKLAB2RGB_B * (lms * lms * lms);
}

@group(0) @binding(1) var<uniform> time: f32;

@fragment
fn fragment(
    @location(2) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    let LIGHT_DIR = normalize(vec3f(0.8, 0.6, -0.5));
    let rayOrigin: vec3<f32> = vec3f(0.0, 0.0, -4.0); // Camera looking towards +Z

    let rayDirection = (vec3f((uv - vec2f(0.5, 0.5)), 1.0)); // Direction through this pixel

    var t: f32 = 0.0;
    var hit: bool = false;
    var hitPos: vec3f;

    var densityAcc1 = 0.0;
    var densityAcc2 = 0.0;
    var densityAcc3 = 0.0;
    for (var i = 0; i < MAX_STEPS; i = i + 1) {
        let p = rayOrigin + rayDirection * t;
        let dist = sphereSDF(p);

        if dist < HIT_EPSILON {
            if (!hit) {
                hitPos = p;
            }
            hit = true;
            t = t + 0.01;
            let timeVec=vec3f(time);
            densityAcc1 += 0.4 * abs(simplexNoise3D(p * t + timeVec));
            densityAcc2 += 0.8 * abs(simplexNoise3D(p.zxy * t+ timeVec));
            densityAcc3 += 0.4 * abs(simplexNoise3D(p.yzx * t+ timeVec*2.0));
        }

        t = t + dist;

        
        if t > MAX_DIST {
            break;
        }
    }
       
    if hit {
        let normal = calcNormal(hitPos);
        let l = point_on_circle(vec2f(0.0), 10.0, time);
        let lightDir = vec3f(l.x, l.y, l.y);
        let diffuse = min(max(dot(normal, lightDir), 0.1), 0.4);

        let totalDensity = densityAcc1 + densityAcc2 + densityAcc3;
        densityAcc1 /= totalDensity;
        densityAcc2 /= totalDensity;
        densityAcc3 /= totalDensity;

        let blue = vec3f(densityAcc1, -0.03, -0.09);
        let red = vec3f(densityAcc2, 0.11, 0.08);
        let green = vec3f(densityAcc3, -0.13, 0.06);
        
        return vec4f(oklab2rgb(blue * densityAcc1 + red * densityAcc2 * diffuse + green * densityAcc3), 1.0);
    } else {
        return vec4f(0.0, 0.0, 0.0, 0.0);
    }
}

