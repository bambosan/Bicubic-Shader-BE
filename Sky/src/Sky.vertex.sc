$input a_position
$output v_color0, v_fog, skyPos, fogControl, frameTime
#include <bgfx_shader.sh>

uniform vec4 FogColor;
uniform vec4 FogAndDistanceControl;
uniform vec4 ViewPositionAndTime;

void main(){
#if defined(FALLBACK) || defined(GEOMETRY_PREPASS)
    gl_Position = vec4(0.0, 0.0, 0.0, 0.0);
#else
    skyPos = a_position.xyz;
    v_fog = FogColor;
    fogControl = FogAndDistanceControl.xy;
    frameTime = ViewPositionAndTime.w;
    vec3 npos = a_position.xyz;
    npos.y -= length(a_position.xyz) * 0.2;
    gl_Position = mul(u_modelViewProj, vec4(npos, 1.0));
#endif
}
