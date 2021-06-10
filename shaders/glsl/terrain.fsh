// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionCentroid.h"

#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		#if defined(TEXEL_AA) && defined(TEXEL_AA_FEATURE)
			_centroid in highp vec2 uv0;
			_centroid in highp vec2 uv1;
		#else
			_centroid in vec2 uv0;
			_centroid in vec2 uv1;
		#endif
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

varying vec4 color;
varying highp vec3 cpos;
varying highp vec3 wpos;
varying float wflag;

#ifdef UNDERWATER
varying float fogr;
#endif

#include "uniformShaderConstants.h"
#include "uniformPerFrameConstants.h"
#include "util.h"

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

#include "gvarbsbe.cs.glsl"

#define nplace vec2(0.25,0.5)+vec2(0.25806452,0.45454545)

#ifdef waterbump
vec3 getTangent(vec3 normal){
	vec3 tangent = vec3(0, 0, 0);
	if(normal.x>0.0){ tangent = vec3(0, 0, -1);
	} else if(normal.x<-0.5){ tangent = vec3(0, 0, 1);
	} else if(normal.y>0.0){ tangent = vec3(1, 0, 0);
	} else if(normal.y<-0.5){ tangent = vec3(1, 0, 0);
	} else if(normal.z>0.0){ tangent = vec3(1, 0, 0);
	} else if(normal.z<-0.5){ tangent = vec3(-1, 0, 0);
	}
	return tangent;
}

vec3 calcwnormal(vec3 normal,highp vec2 pos){
	vec3 rawnormal = texture2D(TEXTURE_0,fract(pos*0.1+TOTAL_REAL_WORLD_TIME*0.1)*nplace).rgb*0.7;
		rawnormal += texture2D(TEXTURE_0,fract(pos*0.4-TOTAL_REAL_WORLD_TIME*0.2)*nplace).rgb*0.3;
		rawnormal = rawnormal*2.0-1.0;
		rawnormal.xy *= 0.15;

	vec3 tangent = getTangent(normal);
	vec3 binormal = normalize(cross(tangent, normal));
	mat3 tbnmatrix = mat3(tangent.x, binormal.x, normal.x, tangent.y, binormal.y, normal.y, tangent.z, binormal.z, normal.z);

		rawnormal = normalize(rawnormal*tbnmatrix);
	return rawnormal;
}

#endif

float fbm(highp vec2 pos,float amp){
	float tot = 0.0, lac = 1.0;
	pos += TOTAL_REAL_WORLD_TIME*0.001;

	for(int i=0; i<3; i++){
		tot += texture2D(TEXTURE_0,mod(pos,1.0)*nplace).a*amp/lac;
		lac *= 2.2;
		pos *= 2.8;
		pos += TOTAL_REAL_WORLD_TIME*0.008;
	}
	return 1.0-pow(0.1,max0(1.0-tot));
}

vec4 reflection(vec4 diff,vec3 normal,highp vec3 uppos,vec3 lcolor,vec2 refval){
	highp vec3 vvector = normalize(-wpos);
	highp vec3 rvector = reflect(normalize(wpos),normal);
	vec3 skycolor = rendersky(rvector,uppos);

	highp float fresnel = refval.x+(1.0-refval.x)*pow(1.0-max0(dot(normal,vvector)),5.0);
		fresnel = saturate(fresnel)*refval.y;
	diff = mix(diff,vec4(skycolor,1.0),fresnel);

		rvector /= rvector.y;
	float cmap = fbm(rvector.xz*0.1,1.45-rain*0.5);
	float cplace = smoothstep(1.0,0.95,length(rvector.xz))*float(dot(rvector,uppos)>0.0);
	diff = mix(diff,vec4(cloudcolor(),1.0),cmap*fresnel*cplace*0.5);

	if(refval.y>0.9){
		highp vec3 lpos = vec3(-0.9848078,0.16477773,0.0);
		highp float ndh = pow(max0(dot(normal,normalize(vvector+lpos))),256.0);
		diff += vec4(lcolor,fresnel*length(lcolor));
		diff += ndh*vec4(skycolor,1.0)*dfog;
	}
	return diff;
}

vec3 illumination(vec3 diff,vec3 normal,vec3 lcolor,float blmap,bool water){
	float dusk = min(smoothstep(0.3,0.5,blmap),smoothstep(1.0,0.8,blmap))*(1.0-rain);
	float night = smoothstep(1.0,0.2,blmap);

	float shadow = 1.0;
	#if !USE_ALPHA_TEST
		shadow = dside(shadow,0.0,normal.x);
	#else
		if(color.a == 0.0) shadow = dside(shadow,0.2,normal.x);
	#endif
 		shadow = mix(shadow,0.0,smoothstep(0.87,0.845,uv1.y));
		shadow = mix(shadow,0.0,rain);
	if(!water)shadow = mix(shadow,0.0,smoothstep(0.6,0.3,color.g));
		shadow = mix(shadow,1.0,smoothstep(blmap*pow(uv1.y,2.0),1.0,uv1.x));

	vec3 amblmap = vec3(0.2,0.3,0.5)*(1.0-saturate(rain*0.25+night*2.))*uv1.y;
	vec3 ambcolor = mix(mix(vec3(1.0,0.9,0.8),vec3(0.6,0.2,0.3),dusk),vec3(0.0,0.0,0.15),night);
		amblmap += lcolor;
		amblmap += ambcolor*shadow*uv1.y;

	diff *= amblmap;
	return diff;
}

void main()
{
#ifdef BYPASS_PIXEL_SHADER
	gl_FragColor = vec4(0, 0, 0, 0);
	return;
#else

#if USE_TEXEL_AA
	vec4 diffuse = texture2D_AA(TEXTURE_0, uv0);
#else
	vec4 diffuse = texture2D(TEXTURE_0, uv0);
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0;
#endif

#if USE_ALPHA_TEST
	#ifdef ALPHA_TO_COVERAGE
	#define ALPHA_THRESHOLD 0.05
	#else
	#define ALPHA_THRESHOLD 0.5
	#endif
	if(diffuse.a < ALPHA_THRESHOLD)
		discard;
#endif

vec4 inColor = color;

#if defined(BLEND)
	diffuse.a *= inColor.a;
#endif

#ifndef SEASONS
	#if !USE_ALPHA_TEST && !defined(BLEND)
		diffuse.a = inColor.a;
	#endif
	if(color.g > color.b && color.a != 0.0){
		diffuse.rgb *= mix(normalize(inColor.rgb),inColor.rgb,0.5);
	} else {
		diffuse.rgb *= (color.a == 0.0)?inColor.rgb:sqrt(inColor.rgb);
	}
#else
	vec2 uv = inColor.xy;
	diffuse.rgb *= mix(vec3(1.0,1.0,1.0), texture2D(TEXTURE_2, uv).rgb*2.0, inColor.b);
	diffuse.rgb *= inColor.aaa;
	diffuse.a = 1.0;
#endif

	vec3 normal = normalize(cross(dFdx(cpos.xyz),dFdy(cpos.xyz)));
	bool water = wflag > 0.4 && wflag < 0.6;
	vec2 refval = vec2(0.0,0.0);
		refval = mix(refval,vec2(0.04,0.5),rain*normal.y);

#ifdef waterbump
	if(water){
		diffuse = vec4(0.0,0.0,0.0,0.4);
		refval = vec2(0.1,1.0);
		vec3 wnormal = calcwnormal(normal,cpos.xz);
		highp vec2 pwpos = cpos.xz+max0(dot(wnormal,normalize(-wpos))*2.0)*normalize(wpos).xz;
		normal = calcwnormal(normal,pwpos);
	}
#endif

	float blmap = texture2D(TEXTURE_1,vec2(0,1)).r;
	float lsource = mix(mix(0.0,uv1.x,smoothstep(blmap*pow(uv1.y,2.0),1.0,uv1.x)),uv1.x,rain*uv1.y);
	vec3 lcolor = vec3(1.0,0.35,0.0)*lsource+pow(lsource,5.0)*0.6;

	diffuse.rgb = toLinear(diffuse.rgb);
	diffuse.rgb = illumination(diffuse.rgb,normal,lcolor,blmap,water);

	highp vec3 uppos = normalize(vec3(0.0,abs(wpos.y),0.0));
	vec3 newfc = rendersky(normalize(wpos),uppos);

#ifdef UNDERWATER
	diffuse.rgb += pow(uv1.x,3.0)*sqrt(diffuse.rgb)*(1.0-uv1.y);
	diffuse.rgb = mix(diffuse.rgb,toLinear(FOG_COLOR.rgb),pow(fogr,5.0));
#else
		refval *= max(uv1.x,smoothstep(0.845,0.87,uv1.y));
	diffuse = reflection(diffuse,normal,uppos,lcolor,refval);
#endif

	diffuse.rgb = mix(diffuse.rgb,newfc*vec3(0.8,0.9,1.0),saturate(length(wpos)*(0.001+0.003*rain)));

	diffuse.rgb = colorcorrection(diffuse.rgb);


	gl_FragColor = diffuse;

#endif
}
