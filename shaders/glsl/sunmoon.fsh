// __multiversion__

#include "fragmentVersionCentroid.h"

#if __VERSION__ >= 300
#if defined(TEXEL_AA) && defined(TEXEL_AA_FEATURE)
_centroid in highp vec2 uv;
#else
_centroid in vec2 uv;
#endif
#else
varying vec2 uv;
#endif

#include "uniformShaderConstants.h"
#include "util.h"
#include "uniformPerFrameConstants.h"

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;

varying highp vec3 pos;
#include "bsbe.cs.glsl"

void main(){

#if !defined(TEXEL_AA) || !defined(TEXEL_AA_FEATURE)
	vec4 diffuse = texture2D( TEXTURE_0, uv );
#else
	vec4 diffuse = texture2D_AA(TEXTURE_0, uv );
#endif

	vec3 c = mix(mix(vec3(1.,.6,0.),vec3(.6,.8,1.),nfog),FOG_COLOR.rgb,rain);
	hp float ce = length(pos.xz);
		c += max0(.01/pow(ce*(18.-nfog*12.),8.));
 		c *= exp(.9-ce)/5.;

	diffuse.rgb = c;
	gl_FragColor = diffuse * CURRENT_COLOR;
}
