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

#include "bsbe.cs.glsl"

#ifdef waterbump
float cwav(hp vec2 pos){
	return noise(vec2(pos.x+TOTAL_REAL_WORLD_TIME,pos.y-TOTAL_REAL_WORLD_TIME))+noise(vec2(pos.x-TOTAL_REAL_WORLD_TIME,pos.y+TOTAL_REAL_WORLD_TIME));
}
vec3 calcnw(vec3 n){
	hp float w1 = cwav(cpos.xz);
	hp float w2 = cwav(vec2(cpos.x-.02,cpos.z));
	hp float w3 = cwav(vec2(cpos.x,cpos.z-.02));
	vec3 wn = normalize(vec3(w1-w2,w1-w3,1.))*.5+.5;
	mat3 tbn = mat3(abs(n.y)+n.z,0.,n.x,0.,0.,n.y,-n.x,n.y,n.z);
		wn = wn*2.-1.;
		wn = normalize(wn*tbn);
	return wn;
}
#endif
float fschlick(float f0,float ndv){
	return f0+(1.-f0)*pow(1.-ndv,5.);
}
vec4 wreflection(vec4 diff,vec3 n,hp vec3 uppos,vec3 lsc,float ndv,float ndh){
	hp vec3 rv = reflect(normalize(wpos),n);
	vec3 skyc = sr(rv,uppos);
	float fresnel = fschlick(.2,ndv);
	diff = vec4(0.,0.,0.,fresnel);
	diff = mix(diff,vec4(skyc+lsc*.3,1.),fresnel);
#ifdef rendercloud
		rv = rv/rv.y;
	float cm = fbm(rv.xz*.4,1.43)*max0(dot(rv,uppos));
	vec3 cc = ccc();
	diff = mix(diff,vec4(cc,1.),cm*fresnel);
#endif
	diff += ndh*vec4(skyc,1.)*dfog;
	diff.rgb *= max(uv1.x,uv1.y);
	return diff;
}
vec3 illum(vec3 diff,vec3 n,vec3 lsc,float lmb,bool water){
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
	if(!water)smap = mix(smap,0.,smoothstep(.6,.3,color.g));
		smap = mix(smap,1.,smoothstep(lmb*uv1.y,1.,uv1.x));
	vec3 almap = vec3(.2,.3,.5)*(1.-saturate(rain*.25+night*2.))*uv1.y;
	vec3 ambc = mix(mix(vec3(1.,.9,.8),vec3(.6,.2,.3),dusk),vec3(0.,0.,.15),night);
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
	if(color.g>color.b && color.a!=0.){
		diffuse.rgb *= mix(normalize(inColor.rgb),inColor.rgb,.5);
	}else{
		diffuse.rgb *= (color.a==0.)?inColor.rgb:sqrt(inColor.rgb);
	}
#else
	vec2 uv = inColor.xy;
	diffuse.rgb *= mix(vec3(1.0,1.0,1.0), texture2D(TEXTURE_2, uv).rgb*2.0, inColor.b);
	diffuse.rgb *= inColor.aaa;
	diffuse.a = 1.0;
#endif


	vec3 n = normalize(cross(dFdx(cpos.xyz),dFdy(cpos.xyz)));
	bool water = wflag>.4&&wflag<.6;
#ifdef waterbump
	if(water)n = calcnw(n);
#endif
	float lmb = texture2D(TEXTURE_1,vec2(0,1)).r;
	float bls = mix(mix(0.,uv1.x,smoothstep(lmb*uv1.y,1.,uv1.x)),uv1.x,rain*uv1.y);
	vec3 lsc = vec3(1.,.35,0.)*bls+pow(bls,5.)*.8;
	diffuse.rgb = tl(diffuse.rgb);
	diffuse.rgb = illum(diffuse.rgb,n,lsc,lmb,water);
	hp vec3 uppos = normalize(vec3(0.,abs(wpos.y),0.));
	hp vec3 vdir = normalize(-wpos);
	hp vec3 lpos = normalize(vec3(-0.9848078,.16477773,0.));
	hp float ndh = pow(max0(dot(n,normalize(vdir+lpos))),256.);
	float ndv = max0(dot(n,vdir));
	if(water)diffuse = wreflection(diffuse,n,uppos,lsc,ndv,ndh);
	vec3 newfc = sr(normalize(wpos),uppos);
#ifdef UNDERWATER
	#ifdef waterbump
		hp float caus = cwav(cpos.xz);
		if(!water)diffuse.rgb = vec3(.3,.5,.8)*diffuse.rgb+saturate(caus)*diffuse.rgb*uv1.y;
	#endif
	diffuse.rgb += pow(uv1.x,3.)*sqrt(diffuse.rgb)*(1.-uv1.y);
	diffuse.rgb = mix(diffuse.rgb,tl(FOG_COLOR.rgb),pow(fogr,5.));
#else
	float fresnel = fschlick(.03,ndv);
	diffuse.rgb = mix(diffuse.rgb,newfc,(fresnel*rain*n.y)*smoothstep(.845,.87,uv1.y));
#endif
	diffuse.rgb = mix(diffuse.rgb,newfc,saturate(length(wpos)*(.001+.003*rain)));


	diffuse.rgb = tonemap(diffuse.rgb);


	gl_FragColor = diffuse;
#endif
}
