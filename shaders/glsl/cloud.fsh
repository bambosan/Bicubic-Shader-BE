// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionSimple.h"
#include "uniformPerFrameConstants.h"

varying highp vec3 cpos;

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;

#include "gvarbsbe.cs.glsl"
#include "scbsbe.cs.glsl"

void main(){

	highp vec3 ajpos = vec3(cpos.x, -cpos.y+.128, -cpos.z);
	highp vec3 uppos = normalize(vec3(0.0,abs(ajpos.y),0.0));
	highp vec3 npos = normalize(ajpos);

	float zenith = max0(dot(npos,uppos));
	vec3 sky = rendersky(npos,uppos);
	vec4 color = vec4(sky,pow(1.0-zenith,5.0));

#ifdef rendercloud
	highp vec3 dpos = npos/npos.y;

	vec4 cloud = rcloud(dpos.xz*0.08);
	vec4 cirrus = rcirrus(dpos.xz*0.05);

	highp float cplace = smoothstep(1.0,0.95,length(npos.xz))*float(zenith > 0.0);

		color = mix(color,cirrus,cirrus.a*(1.0-cloud.a)*cplace*0.7);
		color = mix(color,cloud,cloud.a*cplace*0.65);
#endif

		color.rgb = colorcorrection(color.rgb);

	gl_FragColor = color;

}
