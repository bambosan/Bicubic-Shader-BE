// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionSimple.h"
#include "uniformWorldConstants.h"
#include "uniformPerFrameConstants.h"
#include "uniformShaderConstants.h"

attribute mediump vec4 POSITION;

varying highp float skyh;

void main(){
    vec4 pos = POSITION;
        pos.y -= length(POSITION.xyz)*.2;
    gl_Position = WORLDVIEWPROJ*pos;

    skyh = length(POSITION.xz);
}
