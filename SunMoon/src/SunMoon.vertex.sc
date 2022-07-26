$input a_position
$output v_color0, v_fog, smPos, fogControl
#include <bgfx_shader.sh>

uniform vec4 FogColor;
uniform vec4 FogAndDistanceControl;
uniform vec4 SunMoonColor;

void main(){
    smPos = a_position.xyz;
    v_color0 = SunMoonColor;
    v_fog = FogColor;
    fogControl = FogAndDistanceControl.xy;
    gl_Position = mul(u_modelViewProj, vec4(a_position.xyz * vec3(10.0, 0.0, 10.0), 1.0));
}
