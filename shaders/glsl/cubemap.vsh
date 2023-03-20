#version 300 es
#pragma optimize(on)
precision highp float;

uniform mat4 WORLDVIEWPROJ;

in vec4 POSITION;
out vec3 position;

void main(){
    gl_Position = WORLDVIEWPROJ * POSITION;
    position = POSITION.xyz;
}
