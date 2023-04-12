#version 300 es
#pragma optimize(on)
precision highp float;

uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform float TOTAL_REAL_WORLD_TIME;

// bayer dither by Jodie
// used it for reduce strange color banding
float Bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

#define Bayer4(a) (Bayer2(0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer8(a) (Bayer4(0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer16(a) (Bayer8(0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer32(a) (Bayer16(0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer64(a) (Bayer32(0.5 * (a)) * 0.25 + Bayer2(a))

// https://github.com/bWFuanVzYWth/OriginShader
float fogTime(float fogColorG){
    return clamp(((349.305545 * fogColorG - 159.858192) * fogColorG + 30.557216) * fogColorG - 1.628452, -1.0, 1.0);
}

float getLum(vec3 color){
    return dot(color, vec3(0.2125, 0.7154, 0.0721));
}

vec3 linColor(vec3 color){
    return pow(color, vec3(2.2, 2.2, 2.2));
}

vec3 saturation(vec3 color, float sat){
    float gray = getLum(color);
    return mix(vec3(gray, gray, gray), color, sat);
}

vec3 jodieTonemap(vec3 c){
    vec3 tc = c / (c + 1.0);
    return mix(c / (getLum(c) + 1.0), tc, tc);
}

vec3 sunColor(float sunAngle){
    sunAngle = clamp(sin(sunAngle) + 0.1, 0.0, 1.0);
    return vec3((1.0 - sunAngle) + sunAngle, sunAngle, sunAngle * sunAngle) * exp2(log2(sunAngle) * 0.6);
}

vec3 moonColor(float sunAngle){
    sunAngle = clamp(-sin(sunAngle), 0.0, 1.0);
    return vec3((1.0 - sunAngle) * 0.2 + sunAngle, sunAngle, sunAngle) * exp2(log2(sunAngle) * 0.6) * 0.05;
}

vec3 zenithColor(float sunAngle){
    sunAngle = clamp(sin(sunAngle), 0.0, 1.0);
    return vec3(0.0, sunAngle * 0.13 + 0.003, sunAngle * 0.5 + 0.01);
}

float hash(vec2 coord){
    return fract(cos(coord.x + coord.y * 332.0) * 335.552);
}

float voronoi2d(vec2 pos){
    float result = 1.0;
    for(int i = -1; i <= 1; i++){
        for(int j = -1; j <= 1; j++){
            vec2 o = vec2(j, i);
            result = min(result, length(o - fract(pos) + hash(floor(pos) + o)));
        }
    }
    return result;
}

float fbm(vec2 pos, float pdensity){
    float sum = 0.0;
    float density = 1.0;
    pos += TOTAL_REAL_WORLD_TIME * 0.005;
    for(int i = 0; i < 3; i++){
        sum += voronoi2d(pos) * density * pdensity;
        density *= 0.5;
        pos *= 3.0;
        pos += TOTAL_REAL_WORLD_TIME * 0.05;
    }
    return smoothstep(1.0, 0.0, sum);
}

vec3 renderCloud(vec3 backg, vec3 pos, vec3 sunPos, float sunAngle){
    vec3 cloudColor = sunColor(sunAngle) + moonColor(sunAngle);
        cloudColor = saturation(cloudColor, 0.6);
        cloudColor *= 1.5;
    vec3 ambColor = zenithColor(sunAngle);

    vec2 cloudPos = (pos.xz / pos.y) * 0.6;
        cloudPos -= cloudPos * Bayer64(gl_FragCoord.xy) * 0.05;
    float density = 2.1;

    for(int i = 0; i < 10; i++){
        float cloudMap = fbm(cloudPos, density);
        cloudColor *= (ambColor * 0.1 + 0.88 + exp(-distance(pos, sunPos) * 3.0) * 0.1);
        backg = mix(backg, cloudColor, cloudMap * smoothstep(0.0, 0.3, pos.y));
        density -= 0.13;
        cloudPos -= cloudPos * 0.04;
    }
    return backg;
}

in vec3 position;
out vec4 fragcolor;

void main(){    
    float sunAngle = fogTime(FOG_COLOR.g);
    vec3 sunPos = normalize(vec3(cos(sunAngle), sin(sunAngle), 0.0));
    vec3 pos = normalize(vec3(position.x, -position.y + 0.127, -position.z));

    vec3 color = mix(zenithColor(sunAngle), saturation(sunColor(sunAngle) + moonColor(sunAngle), 0.5), exp(-clamp(pos.y, 0.0, 1.0) * 5.0));

        color += sunColor(sunAngle) * exp(-distance(pos, sunPos) * 2.0) * exp(-clamp(pos.y, 0.0, 1.0) * 2.0) * 5.0;
        color += moonColor(sunAngle) * exp(-distance(pos, -sunPos) * 2.0) * exp(-clamp(pos.y, 0.0, 1.0) * 2.0) * 5.0;

        color += sunColor(sunAngle) * smoothstep(0.999, 1.0, dot(pos, sunPos)) * 100.0 * pow(clamp(pos.y, 0.0, 1.0), 0.8);
        color += moonColor(sunAngle) * smoothstep(0.999, 1.0, dot(pos, -sunPos)) * 100.0 * pow(clamp(pos.y, 0.0, 1.0), 0.8);
        color = renderCloud(color, pos, sunPos, sunAngle);

        color = mix(color, linColor(FOG_COLOR.rgb), max(step(FOG_CONTROL.x, 0.0), smoothstep(0.6, 0.3, FOG_CONTROL.x)));

        color = color * (Bayer64(gl_FragCoord.xy) * 0.5 + 0.5);
        color = jodieTonemap(color * 5.0);
        color = saturation(color, 1.1);
        color = pow(color, vec3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));

    fragcolor = vec4(color, 1.0);
}
