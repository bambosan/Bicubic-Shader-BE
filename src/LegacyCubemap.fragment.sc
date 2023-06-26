$input v_position, v_fogColor, v_fogDistControl
#include <bgfx_shader.sh>

SAMPLER2D(s_MatTexture, 0);

// random, noise, fbm
// https://github.com/patriciogonzalezvivo/lygia/tree/main/generative
float hash(float h){
    return fract(sin(h) * 43758.5453);
}

float voronoi2d(vec2 pos){
    vec2 p = floor(pos);
    vec2 f = fract(pos);
    float dist = 1.0;
    for(float y = -1.0; y <= 1.0; y++){
        for(float x = -1.0; x <= 1.0; x++){
            vec2 ne = vec2(x, y);
            vec2 pn = p + ne;
            float n = pn.x + pn.y * 57.0;
            dist = min(dist, length(ne + hash(n) - f));
        }
    }
    return dist;
}

float fbm(vec2 pos, float pDens, float fTime){
    float sum = 0.0;
    float sDens = 1.0;
    pos += fTime * 0.001;
    for(int i = 0; i < 4; i++){
        sum += voronoi2d(pos) * sDens * pDens;
        sDens *= 0.5;
        pos *= 2.5;
        pos += fTime * 0.05;
    }
    return saturate(1.0 - sum);
}
// random, noise, fbm

float dStars(vec3 pos){
    pos = floor(pos * 265.0);
    return smoothstep(0.9975, 1.0, hash(pos.x + pos.y * 157.0 + pos.z * 113.0));
}

float getLL(vec3 color){
    return dot(color, vec3(0.2125, 0.7154, 0.0721));
}

vec3 cSatur(vec3 color, float sat){
    float lum = getLL(color);
    return mix(vec3_splat(lum), color, sat);
}

// tonemap
// https://github.com/dmnsgn/glsl-tone-map/blob/main/filmic.glsl
vec3 filmic(vec3 x){
    return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}
// tonemap

vec3 getSunC(float sunH){
    sunH = saturate(sunH + 0.1);
    return vec3((1.0 - sunH) + sunH, sunH, sunH * sunH) * pow(sunH, 0.6);
}

vec3 getMoonC(float sunH){
    sunH = saturate(-sunH);
    return vec3(fma((1.0 - sunH), 0.2, sunH), sunH, sunH) * pow(sunH, 0.6);
}

vec3 getZenC(float sunH){
    sunH = pow(saturate(sunH + 0.1), 0.6);
    return vec3(0.0, fma(sunH, 0.12, 0.0001), fma(sunH, 0.5, 0.0005));
}

float getMie(vec3 lightPos, vec3 pos){
    return exp(-distance(pos, lightPos) * 2.0) * exp(-saturate(pos.y) * 4.0);
}

void main(){
    // sun angle
    // https://github.com/bWFuanVzYWth/OriginShader
    float sunA = clamp(((349.305545 * v_fogColor.g - 159.858192) * v_fogColor.g + 30.557216) * v_fogColor.g - 1.628452, -1.0, 1.0);
    // sun angle

    vec3 sunP = normalize(vec3(cos(sunA), sin(sunA), 0.0));
    vec3 nPos = normalize(vec3(v_position.x, -v_position.y + 0.2, -v_position.z));

    vec3 sunC = getSunC(sunP.y);
    vec3 moonC = getMoonC(sunP.y);
    vec3 zenC = getZenC(sunP.y);
    vec3 horC = fma(moonC, vec3(0.0, 0.1, 0.2), sunC);
        horC = cSatur(horC, 0.5);

    vec3 color = mix(zenC, horC, exp(-saturate(nPos.y) * 4.0) * 0.25);
        color += dStars(nPos + v_position.w * 0.0001) * saturate(1.0 - getLL(sunC));
        color += sunC * getMie(sunP, nPos) * 4.0;
        color += moonC * getMie(-sunP, nPos) * vec3(0.15, 0.2, 0.25);
        color += sunC * smoothstep(0.9975, 1.0, dot(nPos, sunP)) * 100.0 * pow(saturate(nPos.y), 0.7);
        color += moonC * smoothstep(0.999, 1.0, dot(nPos, -sunP)) * 100.0 * pow(saturate(nPos.y), 0.7);

    vec2 cloudP = (nPos.xz / nPos.y) * 0.7;
        cloudP -= cloudP * texture2D(s_MatTexture, fract(gl_FragCoord.xy / 256.0)).r * 0.05;
    float sDens = 1.8;
    vec3 cloDirC = horC * 1.5;
    vec3 cloAmbC = cSatur(zenC, 0.7);

    for(int i = 0; i < 10; i++){
        float cloudM = fbm(cloudP, sDens, v_position.w);
        cloDirC = mix(cloDirC, cloAmbC, 0.2);
        color = mix(color, cloDirC, cloudM * smoothstep(0.0, 0.5, nPos.y));
        sDens += (i <= 6) ? -0.1 : 0.1;
        cloudP -= cloudP * 0.045;
    }
        color = mix(color, v_fogColor.rgb * v_fogColor.rgb, max(step(v_fogDistControl.x, 0.0), smoothstep(0.6, 0.3, v_fogDistControl.x)));
        
        color *= vec3(1.5, 1.4, 1.3);
        color = cSatur(color, 1.1);
        color = filmic(color);
    
	gl_FragColor = vec4(color, 1.0);
}
