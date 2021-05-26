// __multiversion__

#include "vertexVersionCentroidUV.h"
#include "uniformWorldConstants.h"

attribute POS4 POSITION;
attribute vec2 TEXCOORD_0;

varying highp vec3 spos;

void main()
{
    spos = POSITION.xyz * vec3(15.0, 1.0, 15.0);
    gl_Position = WORLDVIEWPROJ * (POSITION * vec4(13.0, 1.0, 13.0, 1.0));
    uv = TEXCOORD_0;
}
