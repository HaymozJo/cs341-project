precision highp float;
		
varying vec3 v2f_position;

const float ambient_intensity = 0.5;
const float threshold = 0.85;
const float threshold_gaussian = 0.87;
const float dv = 0.005;

#define NUM_GRADIENTS 12

// -- Gradient table --
vec2 gradients(int i) {
	if (i ==  0) return vec2( 1,  1);
	if (i ==  1) return vec2(-1,  1);
	if (i ==  2) return vec2( 1, -1);
	if (i ==  3) return vec2(-1, -1);
	if (i ==  4) return vec2( 1,  0);
	if (i ==  5) return vec2(-1,  0);
	if (i ==  6) return vec2( 1,  0);
	if (i ==  7) return vec2(-1,  0);
	if (i ==  8) return vec2( 0,  1);
	if (i ==  9) return vec2( 0, -1);
	if (i == 10) return vec2( 0,  1);
	if (i == 11) return vec2( 0, -1);
	return vec2(0, 0);
}

float hash_poly(float x) {
	return mod(((x*34.0)+1.0)*x, 289.0);
}

// -- Hash function --
// Map a gridpoint to 0..(NUM_GRADIENTS - 1)
int hash_func(vec2 grid_point) {
	return int(mod(hash_poly(hash_poly(grid_point.x) + grid_point.y), float(NUM_GRADIENTS)));
}

// -- Smooth interpolation polynomial --
// Use mix(a, b, blending_weight_poly(t))
float blending_weight_poly(float t) {
	return t*t*t*(t*(t*6.0 - 15.0)+10.0);
}

float perlin_noise(vec2 point) {

	vec2 c00 = floor(point);
	vec2 c10 = c00 + vec2(1., 0.);
	vec2 c01 = c00 + vec2(0.,1.);
	vec2 c11 = c00 + vec2(1.,1.);

	vec2 g00 = gradients(hash_func(c00));
	vec2 g10 = gradients(hash_func(c10));
	vec2 g01 = gradients(hash_func(c01));
	vec2 g11 = gradients(hash_func(c11));

	vec2 a = point - c00;
	vec2 b = point - c10;
	vec2 c = point - c01;
	vec2 d = point - c11;

	float s = dot(g00, a);
	float t = dot(g10, b);
	float u = dot(g01, c);
	float v = dot(g11, d);

	float fx = blending_weight_poly(point.x - c00.x);
	float fy = blending_weight_poly(point.y- c00.y);

	float st = mix(s,t,fx);
	float uv = mix(u,v,fx);

	return mix(st, uv, fy);
}

// for marble
const float freq_multiplier = 2.17;
const float ampl_multiplier = 0.5;
const int num_octaves = 4;

float perlin_fbm(vec2 point) {
	float acc = 0.;
	for (int i = 0; i < num_octaves; i++) {
		acc += pow(ampl_multiplier, float(i)) * perlin_noise(point * pow(freq_multiplier, float(i)));
	}

	return acc;
}

const vec3 light 	= vec3(0.95, 0.5, 0.0);
const vec3 white = vec3(1., 0.99, 0.99);


vec3 tex_marble(vec2 point) {
	vec2 q = vec2(perlin_fbm(point),perlin_fbm(point+vec2(2.8,4.6)));
	float alpha = (1. + perlin_fbm(point+4.*q)) / 2.;

	return (alpha * white + (1. - alpha) * light);
}

vec3 gaussian_marble(vec2 point){
	vec3 acc = vec3(0.);
	for (highp float x = 0.; x < 5.; x+=1.) {
		for (highp float y = 0.; y < 5.; y+=1.) {
			vec3 color = tex_marble(vec2(point.x+(x-2.)*dv,point.y+(y-2.)*dv));
			if (dot(color, vec3(0.2126, 0.7152, 0.0722)) > threshold_gaussian){
				// if (x == 3. && y == 3.){
				// 	acc += color;
				// }
				acc += color * (3.-abs(x-2.)) * (3.-abs(y-2.));	
			}
		}
	}
	vec3 r_acc = acc*0.01234567901;

	return r_acc;
}

void main() {
	vec3 color = ambient_intensity*tex_marble(v2f_position.xy);
	float brightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
	if (brightness > 0.36){ //this threshold is used to minimize gauss calculations
		gl_FragColor = vec4(ambient_intensity*gaussian_marble(v2f_position.xy), 1.)*0.5 + vec4(color,1.)*1.;
	} else {
		gl_FragColor = vec4(color,1.);
	}
}