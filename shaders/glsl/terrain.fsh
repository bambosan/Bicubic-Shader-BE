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
float cw(hp vec2 p){
	return noise(vec2(p.x+TOTAL_REAL_WORLD_TIME,p.y-TOTAL_REAL_WORLD_TIME))+noise(vec2(p.x-TOTAL_REAL_WORLD_TIME,p.y+TOTAL_REAL_WORLD_TIME));
}
vec3 cnw(vec3 n){
	hp float w1 = cw(cpos.xz);
	hp float w2 = cw(vec2(cpos.x-.02,cpos.z));
	hp float w3 = cw(vec2(cpos.x,cpos.z-.02));
	vec3 wn = normalize(vec3(w1-w2,w1-w3,1.))*.5+.5;
	mat3 tbn = mat3(abs(n.y)+n.z,0.,n.x,0.,0.,n.y,-n.x,n.y,n.z);
		wn = wn*2.-1.;
		wn = normalize(wn*tbn);
	return wn;
}
#endif
float fs(float f0,float ndv){
	return f0+(1.-f0)*pow(1.-ndv,5.);
}
vec4 wr(vec4 d,vec3 n,hp vec3 u,vec3 lc,float ndv,float ndh){
	hp vec3 rv = reflect(normalize(wpos),n);
	vec3 s = sr(rv,u);
	float f = fs(.2,ndv);
	d = vec4(0.,0.,0.,f);
	d = mix(d,vec4(s+lc*.3,1.),f);
#ifdef rendercloud
		rv = rv/rv.y;
	float m = fbm(rv.xz*.4,1.43)*max0(dot(rv,u));
	vec3 c = ccc();
	d = mix(d,vec4(c,1.),m*f);
#endif
	d += ndh*vec4(s,1.)*dfog;
	d.rgb *= max(uv1.x,uv1.y);
	return d;
}
vec3 ill(vec3 d,vec3 n,vec3 lc,float l,bool water){
	float du = min(smoothstep(.3,.5,l),smoothstep(1.,.8,l))*(1.-rain);
	float ni = smoothstep(1.,.2,l);
	float s = 1.;
	#if !USE_ALPHA_TEST
		s = dside(s,0.,n.x);
	#else
		if(color.a==0.)s = dside(s,.2,n.x);
	#endif
		s = mix(s,0.,smoothstep(.87,.845,uv1.y));
		s = mix(s,0.,rain);
	if(!water)s = mix(s,0.,smoothstep(.6,.3,color.g));
		s = mix(s,1.,smoothstep(l*uv1.y,1.,uv1.x));
	vec3 lm = vec3(.2,.3,.5)*(1.-saturate(rain*.25+ni*2.))*uv1.y;
	vec3 ac = mix(mix(vec3(1.,.9,.8),vec3(.6,.2,.3),du),vec3(0.,0.,.15),ni);
		lm += lc;
		lm += ac*s*uv1.y;
	d *= lm;
	return d;
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

	float l = texture2D(TEXTURE_1,vec2(0,1)).r;
	float ls = mix(mix(0.,uv1.x,smoothstep(l*uv1.y,1.,uv1.x)),uv1.x,rain*uv1.y);
	vec3 lc = vec3(1.,.35,0.)*ls+pow(ls,5.)*.6;
	vec3 n = normalize(cross(dFdx(cpos.xyz),dFdy(cpos.xyz)));
	bool water = wflag>.4&&wflag<.6;
#ifdef waterbump
	if(water)n = cnw(n);
#endif
	diffuse.rgb = tl(diffuse.rgb);
	diffuse.rgb = ill(diffuse.rgb,n,lc,l,water);
	hp vec3 u = normalize(vec3(0.,abs(wpos.y),0.));
	hp vec3 v = normalize(-wpos);
	hp vec3 lp = normalize(vec3(-0.9848078,.16477773,0.));
	hp float ndh = pow(max0(dot(n,normalize(v+lp))),256.);
	float ndv = max0(dot(n,v));
	if(water)diffuse = wr(diffuse,n,u,lc,ndv,ndh);
	vec3 nfc = sr(normalize(wpos),u);
#ifdef UNDERWATER
	#ifdef waterbump
		hp float c = cwav(cpos.xz);
		if(!water)diffuse.rgb = vec3(.3,.5,.8)*diffuse.rgb+saturate(c)*diffuse.rgb*uv1.y;
	#endif
	diffuse.rgb += pow(uv1.x,3.)*sqrt(diffuse.rgb)*(1.-uv1.y);
	diffuse.rgb = mix(diffuse.rgb,tl(FOG_COLOR.rgb),pow(fogr,5.));
#else
	float f = fs(.03,ndv);
	diffuse.rgb = mix(diffuse.rgb,nfc,(f*rain*n.y)*smoothstep(.845,.87,uv1.y));
#endif
	diffuse.rgb = mix(diffuse.rgb,nfc,saturate(length(wpos)*(.001+.003*rain)));
	diffuse.rgb = tonemap(diffuse.rgb);

	gl_FragColor = diffuse;

#endif
}
