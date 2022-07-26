$input a_position
$output v_fog, cubePos, fogControl, frameTime
#include <bgfx_shader.sh>

uniform vec4 FogAndDistanceControl;
uniform vec4 ViewPositionAndTime;
uniform vec4 FogColor;

void main(){
    cubePos = a_position.xyz;
    v_fog = FogColor;
    fogControl = FogAndDistanceControl.xy;
    frameTime = ViewPositionAndTime.w;
    gl_Position = mul(u_modelViewProj, vec4(a_position.xyz, 1.0));
}
