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

varying highp vec3 spos;
#include "bsbe.cs.glsl"

void main(){

#if !defined(TEXEL_AA) || !defined(TEXEL_AA_FEATURE)
	vec4 diffuse = texture2D( TEXTURE_0, uv );
#else
	vec4 diffuse = texture2D_AA(TEXTURE_0, uv );
#endif

	vec3 color = mix(mix(vec3(1.0,0.6,0.0),vec3(0.6,0.8,1.0),nfog),FOG_COLOR.rgb,rain);
	float centerr = length(spos.xz);
		color += max0(0.01/pow(centerr*(18.0-nfog*12.0),8.0));
 		color *= exp(0.9-centerr)/(5.0+dfog*5.0);

	diffuse.rgb = color;
	gl_FragColor = diffuse * CURRENT_COLOR;
}
