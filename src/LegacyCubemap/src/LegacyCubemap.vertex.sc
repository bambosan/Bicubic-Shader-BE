$input a_position
$output v_position, v_fogColor, v_fogDistControl

#include <bgfx_shader.sh>

uniform vec4 FogAndDistanceControl;
uniform vec4 ViewPositionAndTime;
uniform vec4 FogColor;
uniform mat4 CubemapRotation;

void main() {
    gl_Position = mul(u_modelViewProj, vec4(a_position.x, a_position.y + 0.205, a_position.z, 1.0));
    v_position.xyz = a_position.xyz;
    v_position.w = ViewPositionAndTime.w;
    v_fogColor = FogColor;
    v_fogDistControl = FogAndDistanceControl;
}
