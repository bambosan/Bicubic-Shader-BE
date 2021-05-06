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

#ifdef UNDERWATER
varying float fogr;
#endif

#include "uniformShaderConstants.h"
#include "uniformPerFrameConstants.h"
#include "util.h"

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

#include "bsbe.cs.glsl"

float cwav(vec2 pos){
	vec2 mov = vec2(0.,TOTAL_REAL_WORLD_TIME);
	vec2 wp = (pos*1.5)-mov*1.5;
	vec2 wp1 = pos+mov;
	float wave = 1.-noise(wp);
		wave += noise(wp1);
	return wave;
}
vec3 gett(vec3 n){
	vec3 t = vec3(0,0,0);
	if(n.x>0.){ t = vec3(0,0,-1);
	} else if(-n.x>0.){ t = vec3(0,0,1);
	} else if(n.y>0.){ t = vec3(1,0,0);
	} else if(-n.y>0.){ t = vec3(1,0,0);
	} else if(n.z>0.){ t = vec3(1,0,0);
	} else if(-n.z>0.){ t = vec3(-1,0,0);
	}
	return normalize(t);
}
vec3 calcnw(vec3 n){
	float w1 = cwav(cpos.xz);
	float w2 = cwav(vec2(cpos.x-.02,cpos.z));
	float w3 = cwav(vec2(cpos.x,cpos.z-.02));
	float dx = w1-w2,dy=w1-w3;
	vec3 wn = normalize(vec3(dx,dy,1.))*.5+.5;
	vec3 t = gett(n);
	vec3 b = normalize(cross(t,n));
	mat3 tbn = mat3(t.x,b.x,n.x,t.y,b.y,n.y,t.z,b.z,n.z);
		wn = wn*2.-1.;
		wn = normalize(wn*tbn);
	return wn;
}
float fschlick(float f0,float ndv){
	return f0+(1.-f0)*pow(1.-ndv,5.);
}
vec4 reflection(vec4 diff,vec3 n,vec3 uppos,vec3 lsc,float ndv,float ndh){
	vec3 rv = reflect(normalize(wpos),n);
	vec3 skyc = sr(rv,uppos,4.);
	float fresnel = fschlick(.5,ndv);
	diff = vec4(diff.rgb*.3,.5);
	diff = mix(diff,vec4(skyc+lsc*.7,1.),fresnel);
#ifdef rendercloud
		rv = rv/rv.y;
	float cm = fbm(rv.xz*.4,1.43)*max0(dot(rv,uppos));
	vec3 cc = ccc();
	diff = mix(diff,vec4(cc,1.),cm*fresnel*.3);
#endif
	diff += pow(ndh,256.)*vec4(skyc,1.)*dfog;
	diff.rgb *= max(uv1.x,uv1.y);
	return diff;
}
vec3 illum(vec3 diff,vec3 n,vec3 lsc,float lmb){
	float dusk = min(smoothstep(.3,.5,lmb),smoothstep(1.,.8,lmb))*(1.-rain);
	float night = smoothstep(1.,.2,lmb);
	float smap = 1.;
	#if !USE_ALPHA_TEST
		smap = dside(smap,0.,n.x);
	#else
	if(color.a==0.)smap = dside(smap,.2,n.x);
	#endif
		smap = mix(smap,0.,smoothstep(.87,.845,uv1.y));
		smap = mix(smap,0.,rain);
	if(wflag!=.5)smap = mix(smap,0.,smoothstep(.6,.3,color.g));
		smap = mix(smap,1.,smoothstep(lmb*uv1.y,1.,uv1.x));
	vec3 almap = vec3(.3,.4,.6)*mix(1.,0.,saturate(rain*.25+night));
		almap *= uv1.y;
	vec3 ambc = mix(mix(vec3(1.,.9,.9),vec3(1.,.5,.3),dusk),vec3(0.,.03,.15),night);
		almap += lsc;
		almap += ambc*smap*uv1.y;
	diff *= almap;
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
	vec3 ncolor = normalize(inColor.rgb);
	if(ncolor.g>ncolor.b && color.a==1.){
		diffuse.rgb *= mix(ncolor,inColor.rgb,0.5);
	}else{
		diffuse.rgb *= (color.a==0.)?inColor.rgb:sqrt(inColor.rgb);
	}
#else
	vec2 uv = inColor.xy;
	diffuse.rgb *= mix(vec3(1.0,1.0,1.0), texture2D( TEXTURE_2, uv).rgb*2.0, inColor.b);
	diffuse.rgb *= inColor.aaa;
	diffuse.a = 1.0;
#endif




	vec3 rnv = normalize(cross(dFdx(cpos.xyz),dFdy(cpos.xyz)));
	vec3 n = (wflag>.4&&wflag<.6)?calcnw(rnv):rnv;
	float lmb = texture2D(TEXTURE_1,vec2(0,1)).r;
	float bls = mix(mix(0.,uv1.x,smoothstep(lmb*uv1.y,1.,uv1.x)),uv1.x,rain*uv1.y);
	vec3 lsc = vec3(1.,.35,0.)*bls+pow(bls,5.)*.8;
	diffuse.rgb = tl(diffuse.rgb);
	diffuse.rgb = illum(diffuse.rgb,n,lsc,lmb);
	vec3 vdir = normalize(-wpos);
	vec3 lpos = normalize(vec3(cos(2.96706),sin(2.96706),0.));
	float ndv = max(.001,dot(n,vdir));
	float ndh = max(.001,dot(n,normalize(vdir+lpos)));
	vec3 uppos = normalize(vec3(0.,abs(wpos.y),0.));
	if(wflag>.4&&wflag<.6)diffuse = reflection(diffuse,n,uppos,lsc,ndv,ndh);
	vec3 newfc = sr(normalize(wpos),uppos,2.5);
#ifdef UNDERWATER
	float caus = cwav(cpos.xz);
	if(!waterd)diffuse.rgb = vec3(.3,.5,.8)*diffuse.rgb+saturate(caus)*diffuse.rgb*uv1.y;
	diffuse.rgb += pow(uv1.x,3.)*sqrt(diffuse.rgb)*max0(1.-uv1.y);
	diffuse.rgb = mix(diffuse.rgb,tl(FOG_COLOR.rgb),pow(fogr,5.));
#else
	float fresnel = fschlick(.05,ndv);
	diffuse.rgb = mix(diffuse.rgb,newfc,(fresnel*rain*rnv.y)*.2*smoothstep(.845,.87,uv1.y));
#endif
	float fogf = max0(length(wpos)/200.);
		fogf *= saturate(.3+.6*rain);
	diffuse.rgb = mix(diffuse.rgb,newfc,fogf);

	diffuse.rgb = tonemap(diffuse.rgb);


	gl_FragColor = diffuse;

#endif
}
