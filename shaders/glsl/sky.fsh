// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionSimple.h"
#include "uniformPerFrameConstants.h"

varying highp float skyh;

#include "bsbe.cs.glsl"

void main(){
    vec3 skyplanecolor = calcskycolor(pow(skyh*2.0,2.0));
        skyplanecolor = colorcorrection(skyplanecolor);
    gl_FragColor = vec4(skyplanecolor,1.0);
}
