$input v_color0, v_position, v_worldPos, v_texcoord0, v_lightmapUV
#include <bgfx_shader.sh>

uniform vec4 FogAndDistanceControl;
uniform vec4 ViewPositionAndTime;
uniform vec4 FogColor;

SAMPLER2D(s_MatTexture, 0);
SAMPLER2D(s_SeasonsTexture, 1);
SAMPLER2D(s_LightMapTexture, 2);

// random, noise, fbm
// https://github.com/patriciogonzalezvivo/lygia/tree/main/generative
float hash(float h){
    return fract(sin(h) * 43758.5453);
}

float noise2d(vec2 pos){
    vec2 p = floor(pos);
    vec2 f = fract(pos);
        f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 57.0;
    return mix(mix(hash(n), hash(n + 1.0), f.x), mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y);
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

float fbm(vec2 pos, float pDens){
    float sum = 0.0;
    float sDens = 1.0;
    pos += ViewPositionAndTime.w * 0.001;
    for(int i = 0; i < 4; i++){
        sum += voronoi2d(pos) * sDens * pDens;
        sDens *= 0.5;
        pos *= 2.5;
        pos += ViewPositionAndTime.w * 0.05;
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
    return vec3((1.0 - sunH) * 0.2 + sunH, sunH, sunH) * pow(sunH, 0.6);
}

vec3 getZenC(float sunH){
    sunH = pow(saturate(sunH + 0.1), 0.6);
    return vec3(0.0, sunH * 0.12 + 0.0001, sunH * 0.5 + 0.0005);
}

float getMie(vec3 lPos, vec3 pos){
    return exp(-distance(pos, lPos) * 2.0) * exp(-saturate(pos.y) * 4.0);
}

float getMie1(vec3 lPos, vec3 pos){
    return exp(-distance(pos, lPos) * 2.0);
}

#define rot2d(x) mat2(cos(x), -sin(x), sin(x), cos(x))
float getWH(vec2 pos){
    pos *= vec2(1.3, 0.5);
    pos.x += ViewPositionAndTime.w;

    vec2 wind = vec2(ViewPositionAndTime.w, 0.0);
    float hMap = noise2d(mul(pos, rot2d(0.5)) + wind) * 0.45;
        hMap += noise2d(mul(pos, rot2d(-0.5)) + wind) * 0.45;

    pos *= 3.5;
        hMap += noise2d(mul(pos, rot2d(0.5)) - wind) * 0.05;
        hMap += noise2d(mul(pos, rot2d(-0.5)) - wind) * 0.05;
	return saturate(hMap);
}
#undef rot2d

float fSchlick(float f0, float nd){
    return f0 + (1.0 - f0) * pow(1.0 - nd, 5.0);
}

// specular
// http://filmicworlds.com/blog/optimizing-ggx-shaders-with-dotlh/
float G1V(float dotNV, float k){
    return rcp(dotNV * (1.0 - k) + k);
}

float ggx(vec3 N, vec3 V, vec3 L, float roughness, float f0){
    float alpha = roughness * roughness;
    vec3 H = normalize(V + L);

    float dotNL = saturate(dot(N, L));
    float dotNV = saturate(dot(N, V));
    float dotNH = saturate(dot(N, H));
    float dotLH = saturate(dot(L, H));

    float alphaSqr = alpha * alpha;
    float denom = dotNH * dotNH * (alphaSqr - 1.0) + 1.0;
    float D = alphaSqr / (3.1415926 * denom * denom);
    float F = fSchlick(f0, dotLH);

    float k = alpha / 2.0;
    float vis = G1V(dotNL, k) * G1V(dotNV, k);
    return dotNL * D * F * vis;
}
// specular

void main(){
#if defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY)
    gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
#else
    vec4 diffuse = texture2D(s_MatTexture, v_texcoord0);
    #if defined(ALPHA_TEST)
        if(diffuse.a < 0.5) discard;
    #endif
    #if defined(SEASONS) && (defined(OPAQUE) || defined(ALPHA_TEST))
        diffuse.rgb *= mix(vec3_splat(1.0), texture2D(s_SeasonsTexture, v_color0.rg).rgb * 2.0, v_color0.b);
        diffuse.rgb *= v_color0.aaa;
    #else
        diffuse *= v_color0;
    #endif
    #ifndef TRANSPARENT
        diffuse.a = 1.0;
    #endif

    diffuse.rgb *= diffuse.rgb;

    vec3 N = normalize(cross(dFdx(v_position.xyz), dFdy(v_position.xyz)));
    mat3 TBN = mat3(abs(N).y + N.z, 0.0, -N.x, 0.0, -abs(N).x - abs(N).z, abs(N).y, N);

    // sun angle
    // https://github.com/bWFuanVzYWth/OriginShader
    float sunA = clamp(((349.305545 * FogColor.g - 159.858192) * FogColor.g + 30.557216) * FogColor.g - 1.628452, -1.0, 1.0);
    // sun angle
    
    vec3 sunP = normalize(vec3(cos(sunA), sin(sunA), 0.0));
    vec3 tLP = sunP.y > 0.0 ? sunP : -sunP;

    vec3 sunC = getSunC(sunP.y);
    vec3 moonC = getMoonC(sunP.y);
    vec3 zenC = getZenC(sunP.y);
    vec3 horC = moonC * vec3(0.0, 0.1, 0.2) + sunC;
        horC = cSatur(horC, 0.5);

    float rain = smoothstep(0.6, 0.3, FogAndDistanceControl.x);
    float shMap = mix(saturate(dot(tLP, N)) * (2.0 - saturate(tLP.y)), 0.0, max(smoothstep(0.94, 0.92, v_lightmapUV.y), rain));

    float bLight = max(v_lightmapUV.x * (1.0 - saturate(sunP.y) * v_lightmapUV.y), v_lightmapUV.x * rain * v_lightmapUV.y);

    float glowT = float(texture2DLod(s_MatTexture, v_texcoord0, 0.0).a > 0.91 && texture2DLod(s_MatTexture, v_texcoord0, 0.0).a < 0.93) * mix(2.0, 0.0, v_position.w);
    
    bool isNeth = texture2D(s_LightMapTexture, vec2(0, 0)).r > 0.5 && texture2D(s_LightMapTexture, vec2(0, 0)).r < 0.52;
    bool isEndw = texture2D(s_LightMapTexture, vec2(0, 0)).r > 0.42 && texture2D(s_LightMapTexture, vec2(0, 0)).r < 0.44;

    vec3 ambVL = texture2D(s_LightMapTexture, vec2(0.0, v_lightmapUV.y)).rgb;
    vec3 ambL = mix(cSatur(zenC, 0.3) * 2.0 * ambVL, ambVL * 0.25, max(float(isNeth), float(isEndw)));
        ambL += glowT;
        ambL += mix(horC, FogColor.rgb * FogColor.rgb, rain) * shMap;
        ambL += mix(vec3(1.0, 0.7, 0.4), vec3(1.0, 0.5, 0.6), float(isEndw)) * ((bLight * bLight) * 0.25 + pow(bLight, 16.0) * 5.0);

    diffuse.rgb = cSatur(diffuse.rgb, 1.0 - (pow(saturate(-sunP.y), 0.7) * v_lightmapUV.y) * 0.5);
    diffuse.rgb *= ambL;

    vec3 nWP = normalize(v_worldPos.xyz);

    vec3 parP = normalize(mul(v_worldPos, TBN));
        parP.xy = (parP.xy / parP.z) * 0.1;
    vec2 waPos = v_position.xz;
    for(int i = 0; i < 4; i++) waPos += parP.xy * saturate(1.0 - getWH(waPos));

    vec3 wN = vec3(0.0, 0.0, 1.0);
        wN.x += getWH(waPos + vec2(0.02, 0.0));
        wN.x -= getWH(waPos - vec2(0.02, 0.0));
        wN.y += getWH(waPos + vec2(0.0, 0.02));
        wN.y -= getWH(waPos - vec2(0.0, 0.02));
        wN = normalize(mul(normalize(wN), TBN));

    bool isWat = false;
    #if !defined(SEASONS) && !defined(ALPHA_TEST)
        if(v_color0.a > 0.4 && v_color0.a < 0.6){
            isWat = true;
            diffuse.rgb *= 0.0;

            vec3 rPos = reflect(nWP, wN);
            vec3 refl = mix(zenC, horC, exp(-saturate(rPos.y) * 4.0) * 0.25);
                refl += dStars(rPos + ViewPositionAndTime.w * 0.0001) * saturate(1.0 - getLL(sunC));
                refl += sunC * getMie(sunP, rPos) * 4.0;
                refl += moonC * getMie(-sunP, rPos) * vec3(0.15, 0.2, 0.25);

            vec2 cloudP = (rPos.xz / rPos.y) * 0.7;
            float sDens = 1.8;
            vec3 cloDirC = horC * 1.5;
            vec3 cloAmbC = cSatur(zenC, 0.7);

            for(int i = 0; i < 10; i++){
                float cloudM = fbm(cloudP, sDens);
                cloDirC = mix(cloDirC, cloAmbC, 0.2);
                refl = mix(refl, cloDirC, cloudM * smoothstep(0.0, 0.5, rPos.y));
                sDens += (i <= 6) ? -0.1 : 0.1;
                cloudP -= cloudP * 0.045;
            }
                refl = mix(refl, FogColor.rgb * FogColor.rgb, max(step(FogAndDistanceControl.x, 0.0), rain));

            vec3 vDir = normalize(-v_worldPos.xyz);
            float fresnel = fSchlick(0.2, saturate(dot(wN, vDir))) * v_lightmapUV.y;
            diffuse.rgb = mix(diffuse.rgb, refl, fresnel);
            diffuse.a = mix(diffuse.a, 1.0, saturate(fresnel * 2.0));

            diffuse += vec4(horC, 1.0) * ggx(wN, vDir, tLP, 0.1, 0.05) * smoothstep(0.92, 0.94, v_lightmapUV.y);
        }
    #endif

    if(FogAndDistanceControl.x <= 0.0){
        if(!isWat){
            vec3 causDir = normalize(mul(vec3(-1.0, -1.0, 0.1), TBN));
            vec3 uwAmb = ambVL * vec3(0.0, 0.3, 0.8) + pow(v_lightmapUV.x, 3.0);
                uwAmb += pow(saturate(dot(causDir, wN)), 3.0) * v_lightmapUV.y * 3e3;
            diffuse.rgb *= uwAmb;
        }
    } else {
        if(!isNeth && !isEndw){
            vec3 nFogC = zenC * (3.0 - saturate(sunP.y) * 0.5);
                nFogC += sunC * getMie1(sunP, nWP) * 4.0;
                nFogC += moonC * getMie1(-sunP, nWP) * vec3(0.15, 0.2, 0.25);
                nFogC = mix(nFogC, FogColor.rgb * FogColor.rgb, max(step(FogAndDistanceControl.x, 0.0), rain));
            float nFogD = 1.0 - exp(-saturate(length(-v_worldPos.xyz) * 0.01) * (0.1 - saturate(sunP.y) * 0.09));
            diffuse.rgb = mix(diffuse.rgb, nFogC, nFogD);
        }
    }

    vec3 bFogC = mix(zenC, horC, exp(-saturate(nWP.y) * 4.0) * 0.25);
        bFogC += sunC * getMie(sunP, nWP) * 4.0;
        bFogC += moonC * getMie(-sunP, nWP) * vec3(0.15, 0.2, 0.25);
        bFogC = mix(bFogC, FogColor.rgb * FogColor.rgb, max(step(FogAndDistanceControl.x, 0.0), rain));
    diffuse.rgb = mix(diffuse.rgb, bFogC, v_position.w);

    diffuse.rgb *= vec3(1.5, 1.4, 1.3);
    diffuse.rgb = cSatur(diffuse.rgb, 1.1);
    diffuse.rgb = filmic(diffuse.rgb);

    gl_FragColor = diffuse;
#endif
}