#version 300 es
#pragma optimize(on)
precision highp float;

uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform float TOTAL_REAL_WORLD_TIME;

uniform sampler2D TEXTURE_0;
uniform sampler2D TEXTURE_1;
uniform sampler2D TEXTURE_2;

#ifndef BYPASS_PIXEL_SHADER
    const float pi = 3.1415926;
    const float tau = 6.28318531;

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

    // https://github.com/robobo1221/robobo1221Shaders/
    float calcwave(vec2 pos, float waveLength, float magnitude, vec2 waveDir, float waveAmp, float waveStrength){
        float k = tau / waveLength;
        float x = sqrt(19.6 * k) * magnitude - (k * dot(waveDir, pos));
        return waveAmp * pow(sin(x) * 0.5 + 0.5, waveStrength);
    }

    float tWave(vec2 pos){
        float waveLength = 10.0;
        float magnitude = TOTAL_REAL_WORLD_TIME * 0.3;
        float waveAmp = 0.3;
        float waveStrength = 0.6;
        vec2 waveDir = vec2(1.0, 0.5);
        float sum = 0.0;
        for(int i = 0; i < 10; i++){
            sum += calcwave(pos, waveLength, magnitude, waveDir, waveAmp, waveStrength);
            waveLength *= 0.7;
            waveAmp *= 0.62;
            waveStrength *= 1.03;
            waveDir *= mat2(cos(0.5), -sin(0.5), sin(0.5), cos(0.5));
            magnitude *= 1.1;
        }
        return sum;
    }

    vec3 calcWN(vec2 pos){
        float w = tWave(pos);
        float wx = tWave(vec2(pos.x - 0.2, pos.y));
        float wy = tWave(vec2(pos.x, pos.y - 0.2));
        vec3 waterNormal = normalize(vec3(w - wx, w - wy, 1.0)) * 0.5 + 0.5;
        return waterNormal * 2.0 - 1.0;
    }

    float fresnelSchlick(float f0, float NdV){
        return f0 + (1.0 - f0) * pow(1.0 - NdV, 5.0);
    }

    float specularGGX(float ndl, float NdV, float NdH, float rough){
        float rs = pow(rough, 4.0);
        float d = (NdH * rs - NdH) * NdH + 1.0;
        float nd = rs / (pi * d * d);
        float k = (rough * rough) * 0.5;
        float v = NdV * (1.0 - k) + k;
        float l = ndl * (1.0 - k) + k;
        return max(nd * (0.25 / (v * l)), 0.0);
    }

    in vec4 color;
    in vec3 position;
    in vec3 worldpos;
    centroid in vec2 uv0;
    centroid in vec2 uv1;
#endif

#ifdef FOG
    in float fogr;
#endif

out vec4 fragcolor;

void main(){
#ifdef BYPASS_PIXEL_SHADER
    fragcolor = vec4(0, 0, 0, 0);
    return;
#else
    vec4 albedo = texture(TEXTURE_0, uv0);
    #ifdef SEASONS_FAR
        albedo.a = 1.0;
    #endif
    #ifdef ALPHA_TEST
        if(albedo.a < 0.05) discard;
    #endif
    vec4 inColor = color;
    #if defined(BLEND)
        albedo.a *= inColor.a;
    #endif
    #ifndef SEASONS
        #if !defined(USE_ALPHA_TEST) && !defined(BLEND)
            albedo.a = inColor.a;
        #endif
        albedo.rgb *= inColor.rgb;
    #else
        albedo.rgb *= mix(vec3(1.0, 1.0, 1.0), texture(TEXTURE_2, inColor.xy).rgb * 2.0, inColor.b);
        albedo.rgb *= inColor.aaa;
        albedo.a = 1.0;
    #endif

        albedo.rgb = linColor(albedo.rgb);

    float rain = smoothstep(0.6, 0.3, FOG_CONTROL.x);
    float lightVis = texture(TEXTURE_1, vec2(0.0, 1.0)).r;
    float indoor = smoothstep(0.87, 0.84, uv1.y);
    float blockLight = max(uv1.x * smoothstep(lightVis * uv1.y, 1.0, uv1.x), uv1.x * rain * uv1.y);

    vec3 fnormal = normalize(cross(dFdx(position), dFdy(position)));
    float sunAngle = fogTime(FOG_COLOR.g);
    vec3 sunPos = normalize(vec3(cos(sunAngle), sin(sunAngle), 0.0));
    vec3 lightPos = sunPos.y > 0.0 ? sunPos : -sunPos;
    vec3 ambLight = texture(TEXTURE_1, vec2(0.0, uv1.y)).rgb * 0.2;
        ambLight += float(textureLod(TEXTURE_0, uv0, 0.0).a > 0.91 && textureLod(TEXTURE_0, uv0, 0.0).a < 0.93) * 3.0;
        ambLight += vec3(1.0, 0.5, 0.2) * (blockLight + pow(blockLight, 5.0));

    float shadowMap = mix(mix(mix(clamp(dot(lightPos, fnormal), 0.0, 1.0) * (2.0 - clamp(lightPos.y, 0.0, 1.0)), 0.0, indoor), 0.0, rain), 1.0, smoothstep(lightVis * uv1.y, 1.0, uv1.x));
        ambLight += mix(sunColor(sunAngle) * vec3(1.5, 1.3, 1.1), linColor(FOG_COLOR.rgb), rain) * shadowMap;
        albedo.rgb *= ambLight;

    bool isWater = false;
    #if !defined(SEASONS) && !defined(ALPHA_TEST)
        isWater = inColor.a > 0.5 && inColor.a < 0.7;
    #endif

    mat3 TBN = mat3(abs(fnormal.y) + fnormal.z, 0.0, fnormal.x, 0.0, 0.0, fnormal.y, -fnormal.x, fnormal.y, fnormal.z);
    vec3 waterNormal = calcWN(position.xz);
        waterNormal = normalize(waterNormal * TBN);

    if(isWater){
        vec3 refPos = reflect(normalize(worldpos), waterNormal);
        vec3 viewDir = normalize(-worldpos);
        vec3 halfDir = normalize(viewDir + lightPos);

        float NdH = clamp(dot(waterNormal, halfDir), 0.0, 1.0);
        float NdV = clamp(dot(waterNormal, viewDir), 0.0, 1.0);
        float fresnel = fresnelSchlick(0.06, NdV) * smoothstep(0.7, 1.0, uv1.y);

        vec3 reflection = mix(zenithColor(sunAngle), saturation(sunColor(sunAngle) + moonColor(sunAngle), 0.5), exp(-clamp(refPos.y, 0.0, 1.0) * 4.0));
            reflection += sunColor(sunAngle) * exp(-distance(refPos, sunPos) * 2.0) * exp(-clamp(refPos.y, 0.0, 1.0) * 2.0) * 5.0;
            reflection += moonColor(sunAngle) * exp(-distance(refPos, -sunPos) * 2.0) * exp(-clamp(refPos.y, 0.0, 1.0) * 2.0) * 5.0;
            reflection = renderCloud(reflection, refPos, lightPos, sunAngle);
            reflection = mix(reflection, linColor(FOG_COLOR.rgb), max(step(FOG_CONTROL.x, 0.0), rain));

        albedo = vec4(0.0, 0.0, 0.0, 0.8);
        albedo = mix(albedo, vec4(reflection, 1.0), fresnel);
        albedo += vec4(sunColor(sunAngle) + moonColor(sunAngle), 1.0) * specularGGX(clamp(dot(lightPos, waterNormal), 0.0, 1.0), NdV, NdH, 0.05) * uv1.y;
    }

    vec3 npos = normalize(worldpos);
    vec3 fogColor = mix(zenithColor(sunAngle), saturation(sunColor(sunAngle) + moonColor(sunAngle), 0.5), exp(-clamp(npos.y, 0.0, 1.0) * 4.0));
        fogColor += sunColor(sunAngle) * exp(-distance(npos, sunPos) * 2.0) * exp(-clamp(npos.y, 0.0, 1.0) * 2.0) * 5.0;
        fogColor += moonColor(sunAngle) * exp(-distance(npos, -sunPos) * 2.0) * exp(-clamp(npos.y, 0.0, 1.0) * 2.0) * 5.0;
        fogColor = mix(fogColor, linColor(FOG_COLOR.rgb), max(step(FOG_CONTROL.x, 0.0), rain));

    bool isUnderwater = FOG_CONTROL.x <= 0.0;
    if(isUnderwater){
        if(!isWater){
            vec3 causticDir = normalize(vec3(-1.0, -1.0, 0.1) * TBN);
            vec3 uwAmb = FOG_COLOR.rgb;
                uwAmb += pow(uv1.x, 3.0);
                uwAmb += albedo.rgb * clamp(dot(causticDir, waterNormal), 0.0, 1.0) * 500.0 * uv1.y;
            albedo.rgb *= uwAmb;
        }
    } else {
        albedo.rgb = mix(albedo.rgb, zenithColor(sunAngle) * 2.0, clamp(length(-worldpos.xyz) * 0.01, 0.0, 1.0) * 0.05);
    }

    #ifdef FOG
        albedo.rgb = mix(albedo.rgb, fogColor, isUnderwater ?  (fogr * fogr) : fogr);
    #endif

        albedo.rgb = albedo.rgb * (Bayer64(gl_FragCoord.xy) * 0.5 + 0.5);
        albedo.rgb = jodieTonemap(albedo.rgb * 5.0);
        albedo.rgb = saturation(albedo.rgb, 1.1);
        albedo.rgb = pow(albedo.rgb, vec3(1.0 / 2.2));

    fragcolor = albedo;
#endif
}
