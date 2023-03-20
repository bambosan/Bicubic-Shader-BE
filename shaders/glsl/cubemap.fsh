#version 310 es
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

float luminance(vec3 color){
    return dot(color, vec3(0.2125, 0.7154, 0.0721));
}

vec3 saturation(vec3 color, float sat){
    float gray = luminance(color);
    return mix(vec3(gray, gray, gray), color, sat);
}

vec3 uncharted2Tonemap(vec3 x){
    float A = 0.25;
    float B = 0.29;
    float C = 0.10;
    float D = 0.2;
    float E = 0.03;
    float F = 0.35;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 unchartedmod(vec3 color){
    const float W = 11.2;
    vec3 curr = uncharted2Tonemap(color);
    vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
    return curr * whiteScale;
}

vec3 calcSky(vec3 pos, vec3 lightPos, float offset){
    float lightAngle = clamp(lightPos.y + offset, 0.0, 1.0);
    vec3 horizonColor = mix(vec3(1.0, 0.2, 0.0), vec3(1.0, 1.0, 1.0), lightAngle) * lightAngle;
    vec3 zenithColor = mix(vec3(0.0, 0.3, 0.0), vec3(0.0, 0.2, 1.0), lightAngle) * lightAngle;

    float zenith = clamp(pos.y, 0.0, 1.0);
    vec3 result = mix(zenithColor, horizonColor, exp(-zenith));

    float mie = exp(-distance(pos, lightPos));
        result *= (1.0 + mie) * 0.7;
        result += saturation(horizonColor * 3.0, 2.5) * (mie * mie * mie) * clamp(lightPos.y + 0.3, 0.0, 1.0) * exp(-zenith * 3.5);
        result = pow(result, vec3(2.2, 2.2, 2.2));
    return result;
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

float fbm(vec2 pos, float density, float time){
    float sum = 0.0;
    float lacunarity = 1.0;
    pos = (pos * 6.0) + (time * 0.01);

    for(int i = 0; i < 3; i++){
        sum += voronoi2d(pos) * density / lacunarity;
        lacunarity *= 3.0;
        pos = (pos * 3.0) + (time * 0.1);
    }
    return smoothstep(1.0, 0.0, sum);
}

float mieCloud(vec3 pos, vec3 lightPos, float offset, float strength){
    return (1.0 + (exp(-distance(pos, lightPos) * 2.0) * exp(-clamp(pos.y, 0.0, 1.0) * 3.0) * strength) * clamp(lightPos.y + offset, 0.0, 1.0));
}

vec3 calcCloud(vec3 background, vec3 ambientColor, vec3 cloudColor, vec3 pos, vec3 lightPos, float time){

    cloudColor *= mieCloud(pos, lightPos, 0.3, 40.0);
    cloudColor *= mieCloud(pos, -lightPos, 0.1, 50.0);

    vec2 cloudPos = (pos.xz / pos.y) * 0.1;
    float density = 2.0;

    for(int i = 0; i < 10; i++){
        float cloudMap = fbm(cloudPos, density, time);
        cloudColor *= (ambientColor * 0.1 + (0.95 - clamp(lightPos.y, 0.0, 1.0) * 0.15));
        background = mix(background, cloudColor, cloudMap * smoothstep(0.1, 0.4, pos.y));

        density -= 0.1;
        cloudPos -= cloudPos * 0.04;
    }
    return background;
}

in vec3 position;
out vec4 fragcolor;

void main(){    
    float sunAngle = fogTime(FOG_COLOR.g);
    float rain = smoothstep(0.6, 0.3, FOG_CONTROL.x);

    vec3 lightPos = normalize(vec3(cos(sunAngle), sin(sunAngle), 0.0));
    vec3 pos = normalize(vec3(position.x, -position.y + 0.128, -position.z));

    vec3 zenithColor = calcSky(vec3(0.0, 2.0, 0.0), lightPos, 0.2);
        zenithColor += saturation(calcSky(vec3(0.0, 2.0, 0.0), -lightPos, 0.2), 0.0) * 0.1;

    vec3 sunColor = calcSky(vec3(0.0, 0.0, 0.0), lightPos, 0.3);
        sunColor += saturation(calcSky(vec3(0.0, 0.0, 0.0), -lightPos, 0.3), 0.0) * 0.005;
 
    vec3 color = calcSky(pos, lightPos, 0.4);
        color += saturation(calcSky(pos, -lightPos, 0.4), 0.0) * 0.05;

        color += normalize(sunColor) * smoothstep(0.999, 1.0, dot(pos, lightPos)) * 20.0 * pow(clamp(pos.y, 0.0, 1.0), 0.8);
        color += normalize(sunColor) * smoothstep(0.999, 1.0, dot(pos, -lightPos)) * 10.0 * pow(clamp(pos.y, 0.0, 1.0), 0.8);

        color = calcCloud(color, zenithColor, sunColor, pos, lightPos, TOTAL_REAL_WORLD_TIME);
        color = mix(color, pow(FOG_COLOR.rgb, vec3(2.2, 2.2, 2.2)), max(step(FOG_CONTROL.x, 0.0), rain));

        color = color * (Bayer64(gl_FragCoord.xy) * 0.5 + 0.5);
        color = unchartedmod(color * 6.0);
        color = saturation(color, 1.1);
        color = pow(color, vec3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));

    fragcolor = vec4(color, 1.0);
}
