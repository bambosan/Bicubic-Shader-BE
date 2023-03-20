#version 310 es
precision highp float;

uniform mat4 WORLDVIEWPROJ;
uniform mat4 WORLD;
uniform mat4 WORLDVIEW;
uniform mat4 PROJ;
uniform vec4 CHUNK_ORIGIN_AND_SCALE;
uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform float RENDER_CHUNK_FOG_ALPHA;
uniform float RENDER_DISTANCE;
uniform float FAR_CHUNKS_DISTANCE;
uniform float TOTAL_REAL_WORLD_TIME;

in vec4 POSITION;
in vec4 COLOR;
in vec2 TEXCOORD_0;
in vec2 TEXCOORD_1;

#ifndef BYPASS_PIXEL_SHADER
    out vec4 color;
    out vec3 position;
    out vec3 worldpos;
    centroid out vec2 uv0;
    centroid out vec2 uv1;
#endif

#ifdef FOG
    out float fogr;
#endif

vec3 calcwave(vec3 pos, float fm, float mm, float ma, float f0, float f1, float f2, float f3, float f4, float f5){
    float PI48 = 150.796447372;
    float pi2wt = PI48 * TOTAL_REAL_WORLD_TIME;
    float mag = sin(dot(vec4(pi2wt * fm, pos.x, pos.z, pos.y), vec4(0.5, 0.5, 0.5, 0.5))) * mm + ma;
    vec3 d012 = sin(pi2wt * vec3(f0, f1, f2));
    vec3 ret = sin(pi2wt * vec3(f3, f4, f5) + vec3(d012.x + d012.y, d012.y + d012.z, d012.z + d012.x) - pos) * mag;
    return ret;
}

vec3 calcmove(vec3 pos, float f0, float f1, float f2, float f3, float f4, float f5, vec3 amp1, vec3 amp2){
    vec3 move1 = calcwave(pos, 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    vec3 move2 = calcwave(pos + move1, 0.07, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
    return move1 + move2;
}

void main(){
    vec4 worldPos;
    vec3 worldPos2;
#ifdef AS_ENTITY_RENDERER
    vec4 pos = WORLDVIEWPROJ * POSITION;
        worldPos = pos;
        worldPos2 = worldPos.xyz;
#else
        worldPos.xyz = (POSITION.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;
        worldPos.w = 1.0;
        worldPos2 = worldPos.xyz;

    // https://github.com/McbeEringi/esbe-2g
    vec3 ajp = vec3(POSITION.x == 16.0 ? 0.0 : POSITION.x, abs(POSITION.y - 8.0), POSITION.z == 16.0 ? 0.0 : POSITION.z);

    #ifdef ALPHA_TEST
        vec3 frp = fract(POSITION.xyz);
        if((COLOR.r != COLOR.g && COLOR.g != COLOR.b && frp.y != 0.015625) || (frp.y == 0.9375 && (frp.x == 0.0 || frp.z == 0.0))){
            worldPos.xyz += calcmove(ajp, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0, 0.2, 1.0), vec3(0.5, 0.1, 0.5)) * 1.4 * (1.0 - clamp(length(worldPos.xyz) / FAR_CHUNKS_DISTANCE, 0.0, 1.0)) * TEXCOORD_1.y;
        }
    #endif

    #if !defined(SEASONS) && !defined(ALPHA_TEST)
        if(COLOR.a > 0.6 && COLOR.a < 0.7){
            worldPos.y += sin(TOTAL_REAL_WORLD_TIME * 4.0 + ajp.x + ajp.z + ajp.y) * 0.06 * fract(POSITION.y);
        }
    #endif

    if(FOG_CONTROL.x <= 0.0){
        worldPos.xyz += sin(TOTAL_REAL_WORLD_TIME * 4.0 + ajp.x + ajp.z + ajp.y) * 0.03;
    }

    vec4 pos = WORLDVIEW * worldPos;
        pos = PROJ * pos;
#endif

#ifndef BYPASS_PIXEL_SHADER
    color = COLOR;
    position = POSITION.xyz;
    worldpos = worldPos2;
    uv0 = TEXCOORD_0;
    uv1 = TEXCOORD_1;
#endif

#ifdef FOG
    float len = length(-worldPos.xyz) / RENDER_DISTANCE;
    #ifdef ALLOW_FADE
        len += RENDER_CHUNK_FOG_ALPHA;
    #endif
    fogr = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);
#endif

    gl_Position = pos;
}
