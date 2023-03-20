#version 300 es
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

    float luminance(vec3 color){
        return dot(color, vec3(0.2125, 0.7154, 0.0721));
    }

    vec3 linearColor(vec3 color){
        return pow(color, vec3(2.2, 2.2, 2.2));
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
        return linearColor(result);
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

    // https://github.com/robobo1221/robobo1221Shaders/tree/master/shaders/lib/fragment
    float calcwave(vec2 pos, float waveLength, float magnitude, vec2 waveDir, float waveAmp, float waveStrength){
        float k = tau / waveLength;
        float x = sqrt(19.6 * k) * magnitude - (k * dot(waveDir, pos));
        return waveAmp * pow(sin(x) * 0.5 + 0.5, waveStrength);
    }

    #define rot2d(rain) mat2(cos(rain), -sin(rain), sin(rain), cos(rain))
    float trochoidalwave(vec2 pos, float time){
        float waveLength = 10.0;
        float magnitude = time * 0.3;
        float waveAmp = 0.5;
        float waveStrength = 0.6;
        vec2 waveDir = vec2(1.0, 0.5);
        float sum = 0.0;
        for(int i = 0; i < 10; i++){
            sum += calcwave(pos, waveLength, magnitude, waveDir, waveAmp, waveStrength);
            waveLength *= 0.7;
            waveAmp *= 0.62;
            waveStrength *= 1.03;
            waveDir *= rot2d(0.5);
            magnitude *= 1.1;
        }
        return sum;
    }
    #undef rot2d

    vec3 calcWN(vec2 pos, float time){
        float w = trochoidalwave(pos, time);
        float wx = trochoidalwave(vec2(pos.x - 0.2, pos.y), time);
        float wy = trochoidalwave(vec2(pos.x, pos.y - 0.2), time);
        vec3 waterNormal = normalize(vec3(w - wx, w - wy, 1.0)) * 0.5 + 0.5;
        return waterNormal * 2.0 - 1.0;
    }

    float fschlick(float f0, float ndv){
        return f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
    }

    float ggx(float ndl, float ndv, float ndh, float roughness){
        float rs = pow(roughness, 4.0);
        float d = (ndh * rs - ndh) * ndh + 1.0;
        float nd = rs / (pi * d * d);
        float k = (roughness * roughness) * 0.5;
        float v = ndv * (1.0 - k) + k;
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
        albedo.rgb *= (inColor.r == inColor.g && inColor.g == inColor.b) ? sqrt(inColor.rgb) : inColor.rgb / (luminance(inColor.rgb) * 1.5);
    #else
        albedo.rgb *= mix(vec3(1.0, 1.0, 1.0), texture(TEXTURE_2, inColor.xy).rgb * 2.0, inColor.b);
        albedo.rgb *= inColor.aaa;
        albedo.a = 1.0;
    #endif

        albedo.rgb = linearColor(albedo.rgb);

    float rain = smoothstep(0.6, 0.3, FOG_CONTROL.x);
    float lightVis = texture(TEXTURE_1, vec2(0.0, 1.0)).r;
    float indoor = smoothstep(0.87, 0.84, uv1.y);
    float blockLight = max(uv1.x * smoothstep(lightVis * uv1.y, 1.0, uv1.x), uv1.x * rain * uv1.y);

    vec3 fnormal = normalize(cross(dFdx(position), dFdy(position)));
    float sunAngle = fogTime(FOG_COLOR.g);
    vec3 lightPos = normalize(vec3(cos(sunAngle), sin(sunAngle), 0.0));
    vec3 tlightPos = lightPos.y > 0.0 ? lightPos : -lightPos;
    
    vec3 zenithColor = calcSky(vec3(0.0, 2.0, 0.0), lightPos, 0.2);
        zenithColor += saturation(calcSky(vec3(0.0, 2.0, 0.0), -lightPos, 0.2), 0.0) * 0.1;
        zenithColor = mix(zenithColor, linearColor(FOG_COLOR.rgb), rain);

    vec3 sunColor = calcSky(vec3(0.0, 0.0, 0.0), lightPos, 0.3);
        sunColor += saturation(calcSky(vec3(0.0, 0.0, 0.0), -lightPos, 0.3), 0.0) * 0.005;
        sunColor = mix(sunColor, linearColor(FOG_COLOR.rgb), rain);

    vec3 dirColor = calcSky(vec3(0.0, 0.0, 0.0), lightPos, 0.2) * vec3(1.0, 0.8, 0.6);
        dirColor += saturation(calcSky(vec3(0.0, 0.0, 0.0), -lightPos, 0.2), 0.0) * 0.005;
        dirColor = mix(dirColor, linearColor(FOG_COLOR.rgb), rain);

    vec3 ambLight = texture(TEXTURE_1, vec2(0.0, uv1.y)).rgb * 0.15;
        ambLight += (vec3(1.0, 0.5, 0.2) * (blockLight + pow(blockLight, 5.0)));

    float shadowMap = mix(mix(mix(
        clamp(dot(tlightPos, fnormal), 0.0, 1.0) * (2.0 - clamp(tlightPos.y, 0.0, 1.0)), 0.0, indoor),
        0.0, rain),
        1.0, smoothstep(lightVis * uv1.y, 1.0, uv1.x));

    #ifndef ALPHA_TEST
        if(albedo.a > 0.5 && albedo.a < 0.6){
            ambLight += albedo.rgb * 2.0 * (1.0 - shadowMap);
        }
    #endif
        
        ambLight += (dirColor * shadowMap);
        albedo.rgb = albedo.rgb * ambLight;

    bool isWater = false;
    #if !defined(SEASONS) && !defined(ALPHA_TEST)
        isWater = inColor.a > 0.6 && inColor.a < 0.7;
    #endif

    mat3 fakeTBN = mat3(abs(fnormal.y) + fnormal.z, 0.0, fnormal.x, 0.0, 0.0, fnormal.y, -fnormal.x, fnormal.y, fnormal.z);
    vec3 waterNormal = calcWN(position.xz, TOTAL_REAL_WORLD_TIME);
        waterNormal = normalize(waterNormal * fakeTBN);

    if(isWater){
        vec3 reflectedPos = reflect(normalize(worldpos), waterNormal);
        vec3 viewDir = normalize(-worldpos);
        vec3 halfDir = normalize(viewDir + tlightPos);

        float ndh = clamp(dot(waterNormal, halfDir), 0.0, 1.0);
        float ndv = clamp(dot(waterNormal, viewDir), 0.0, 1.0);

        float fresnel = fschlick(0.05, ndv) * smoothstep(0.5, 1.0, uv1.y);

        vec3 reflection = calcSky(reflectedPos, lightPos, 0.4);
            reflection += saturation(calcSky(reflectedPos, -lightPos, 0.4), 0.0) * 0.05;

            reflection += normalize(sunColor) * smoothstep(0.999, 1.0, dot(reflectedPos, lightPos)) * 20.0 * pow(clamp(reflectedPos.y, 0.0, 1.0), 0.8);
            reflection += normalize(sunColor) * smoothstep(0.999, 1.0, dot(reflectedPos, -lightPos)) * 10.0 * pow(clamp(reflectedPos.y, 0.0, 1.0), 0.8);
    
            reflection = calcCloud(reflection, zenithColor, sunColor, reflectedPos, lightPos, TOTAL_REAL_WORLD_TIME);

            reflection = mix(reflection, linearColor(FOG_COLOR.rgb), max(step(FOG_CONTROL.x, 0.0), rain));

        albedo.rgb = vec3(0.0, 0.0, 0.0);
        albedo = mix(albedo, vec4(reflection, 1.0), fresnel);
        albedo += normalize(vec4(sunColor, 1.0)) * ggx(clamp(dot(tlightPos, waterNormal), 0.0, 1.0), ndv, ndh, 0.05) * uv1.y;

        vec3 lBlockDir = normalize(cross(dFdx(position) * dFdy(uv1.x) - dFdy(position) * dFdx(uv1.x), fnormal));
            lBlockDir = normalize(lBlockDir + fnormal * 0.01);
        albedo += vec4(1.0, 0.5, 0.2, 1.0) * clamp((dot(lBlockDir, waterNormal) * dot(lBlockDir, waterNormal)) * 180.0 * (blockLight * blockLight), 0.0, 1.0);
    }

    vec3 fogColor = calcSky(normalize(worldpos), lightPos, 0.4);
        fogColor += saturation(calcSky(normalize(worldpos), -lightPos, 0.4), 0.0) * 0.05;
        fogColor = mix(fogColor, linearColor(FOG_COLOR.rgb), max(step(FOG_CONTROL.x, 0.0), rain));

    bool isUnderwater = FOG_CONTROL.x <= 0.0;
    if(isUnderwater){
        if(!isWater){
            vec3 causticDir = normalize(vec3(-1.0, -1.0, 0.05) * fakeTBN);
            albedo.rgb = albedo.rgb * vec3(0.3, 0.4, 0.5) + (albedo.rgb * clamp(dot(causticDir, waterNormal), 0.0, 0.7) * 20.0 * uv1.y);
        }
    } else {
        albedo.rgb = mix(albedo.rgb, fogColor, clamp(length(-worldpos.xyz) * 0.01, 0.0, 1.0) * 0.05);
    }

    #ifdef FOG
        albedo.rgb = mix(albedo.rgb, fogColor, isUnderwater ?  (fogr * fogr) : fogr);
    #endif

        albedo.rgb = albedo.rgb * (Bayer64(gl_FragCoord.xy) * 0.5 + 0.5);
        albedo.rgb = unchartedmod(albedo.rgb * 6.0);
        albedo.rgb = saturation(albedo.rgb, 1.1);
        albedo.rgb = pow(albedo.rgb, vec3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));

    fragcolor = albedo;
#endif
}
