// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionSimple.h"
#include "uniformPerFrameConstants.h"

varying highp vec3 cpos;

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;

#include "gvarbsbe.cs.glsl"

float fbm(highp vec2 pos,float amp){
	float tot = 0.0, lac = 1.0;
	pos += TOTAL_REAL_WORLD_TIME*.001;
	for(int i=0; i<3; i++){
		tot += texture2D(TEXTURE_0, pos).r * amp/lac;
		lac *= 2.2;
		pos *= 2.8;
		pos += TOTAL_REAL_WORLD_TIME*.008;
	}
	return 1.0-pow(0.1,max0(1.0-tot));
}

vec4 rcloud(highp vec2 pos){
	vec3 col = vec3(1)-nfog*0.5;
	vec3 shadow = mix(FOG_COLOR.rgb,FOG_COLOR.rgb*2.5,rain);
		shadow = toLinear(shadow);
	float amp = 2.3-rain*2.0;
	float opac = 0.0;

	for(int i = 0; i < 10; i++){
		float cmap = fbm(pos, amp);
		amp *= 0.933;
		pos *= 0.965;
		if(cmap > 0.0){
			vec3 ccloud = cloudcolor();
				ccloud = mix(ccloud*3.0,shadow*cmap,cmap);
			col = mix(col,ccloud,cmap);
    		opac += mix(0.0,(1.0-cmap*0.5)*(1.0-opac),cmap);
		}
		shadow *= 0.96;
	}
	return vec4(col,opac);
}

vec4 rcirrus(highp vec2 pos){
	float tot = 0.0, lac = 1.0;
	pos += TOTAL_REAL_WORLD_TIME * 0.001;
	for(int i = 0; i < 3; i++){
		tot += texture2D(TEXTURE_0, pos).a / lac;
		pos += tot * 0.05;
		lac *= 2.0;
		pos *= 3.0;
	}
		tot = 1.0-pow(0.15,max0(1.0-tot));
	vec3 ccolor = cloudcolor();
	return vec4(ccolor,tot);
}

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
