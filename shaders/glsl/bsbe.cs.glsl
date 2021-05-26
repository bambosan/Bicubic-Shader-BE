
#define max0(x) max(0.0,x)
#define saturate(x) clamp(x,0.0,1.0)
#define dside(x,y,z) mix(x,y,max0(abs(z)))
#define rain smoothstep(0.6,0.3,FOG_CONTROL.x)
#define nfog pow(saturate(1.0-FOG_COLOR.r*1.5),1.2)
#define dfog saturate((FOG_COLOR.r-0.15)*1.25)*(1.0-FOG_COLOR.b)

float random(highp float p){
	return fract(sin(p)*43758.5453);
}
vec2 random2(highp vec2 p){
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

float noise2d(highp vec2 p){
	vec2 ip = floor(p);
	vec2 fp = fract(p);
		fp = smoothstep(0.0, 1.0, fp);
	float u = ip.x + ip.y * 57.0;
	return mix(mix(random(u), random(u + 1.0), fp.x), mix(random(u + 57.0), random(u + 58.0), fp.x), fp.y);
}

float voronoi(highp vec2 p){
	vec2 fp = fract(p);
	vec2 ip = floor(p);
	float dist = 1.0;
	for(int y = -1; y <= 1; y++){
		for(int x = -1; x <= 1; x++){
			vec2 neighbor = vec2(float(x), float(y));
			vec2 pointt = random2(ip + neighbor);
			dist = min(dist, length(neighbor + pointt - fp));
		}
	}
	return dist;
}

uniform highp float TOTAL_REAL_WORLD_TIME;

float fractalb(highp vec2 pos, float amp){
	float value = 0.0;
	float amplitude = 0.5;
	pos += TOTAL_REAL_WORLD_TIME * 0.001;

	for(int i = 0; i < 3; i++){
		value += voronoi(pos) * amplitude;
		pos *= 2.8;
		pos += TOTAL_REAL_WORLD_TIME * 0.03;
		amplitude *= amp;
	}
	return 1.0-pow(0.1,max0(1.0-value));
}

vec3 toLinear(vec3 col){
	return pow(col, vec3(2.2));
}

vec3 cloudcolor(){
	vec3 col = mix(mix(mix(vec3(1),vec3(0.15,0.2,0.29),nfog),vec3(1.0,0.3,0.5),dfog),FOG_COLOR.rgb * 1.5,rain);
		col = toLinear(col);
	return col;
}

vec3 calcskycolor(float hor){
	vec3 zenithc = mix(mix(mix(vec3(0.0,0.35,0.8),vec3(0.06,0.1,0.2),nfog),vec3(0.5,0.4,0.6),dfog),FOG_COLOR.rgb*2.0,rain);
	vec3 horc = mix(mix(mix(vec3(0.8,0.9,1.0),vec3(1.0,0.4,0.5),dfog),zenithc+0.15,nfog),FOG_COLOR.rgb*2.0,rain);
		zenithc = toLinear(zenithc);
		horc = toLinear(horc);
		zenithc = mix(zenithc,horc,hor);
	if(FOG_CONTROL.x == 0.0) zenithc = toLinear(FOG_COLOR.rgb);
	return zenithc;
}

vec3 rendersky(highp vec3 npos, highp vec3 uppos){
	float zenith = max0(dot(npos, uppos));
	float mie = pow(1.0 - length(npos.zy), 4.0) * 10.0;
	float hor = pow(1.0 - zenith, 2.5) + mie*dfog;
	vec3 col = calcskycolor(hor);
	return col;
}

vec3 colorcorrection(vec3 col){
	col *= 1.3;
 	col = col/(0.9813*col+0.1511);
	float lum = dot(col,vec3(0.2125,0.7154,0.0721));
	col = mix(vec3(lum),col,1.1);
	return col;
}
