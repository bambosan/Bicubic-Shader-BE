// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionSimple.h"
#include "uniformPerFrameConstants.h"

varying highp float skyh;

#include "bsbe.cs.glsl"

void main(){
    vec3 s = csc(pow(skyh*2.,2.));
        s = tonemap(s);
    gl_FragColor = vec4(s,1.);
}
