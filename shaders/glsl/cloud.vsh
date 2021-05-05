// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionSimple.h"
#include "uniformWorldConstants.h"
#include "uniformPerFrameConstants.h"
#include "uniformShaderConstants.h"

attribute POS4 POSITION;

varying highp vec3 pos;

void main(){
    gl_Position = WORLDVIEWPROJ * POSITION;
    pos = POSITION.xyz;
}
