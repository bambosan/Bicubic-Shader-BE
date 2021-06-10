// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionCentroid.h"
#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		_centroid out vec2 uv0;
		_centroid out vec2 uv1;
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		out vec2 uv0;
		out vec2 uv1;
	#endif
#endif

#include "uniformWorldConstants.h"
#include "uniformPerFrameConstants.h"
#include "uniformShaderConstants.h"
#include "uniformRenderChunkConstants.h"

#ifndef BYPASS_PIXEL_SHADER
varying vec4 color;
varying highp vec3 cpos;
varying	highp vec3 wpos;
#endif

varying float wflag;
#ifdef UNDERWATER
varying float fogr;
#endif

attribute POS4 POSITION;
attribute vec4 COLOR;
attribute vec2 TEXCOORD_0;
attribute vec2 TEXCOORD_1;

const float rA = 1.0;
const float rB = 1.0;
const vec3 UNIT_Y = vec3(0,1,0);
const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange

#include "gvarbsbe.cs.glsl"

void main()
{
	POS4 worldPos;
	wflag = 0.0;
#ifdef AS_ENTITY_RENDERER
		POS4 pos = WORLDVIEWPROJ * POSITION;
		worldPos = pos;
#else
	worldPos.xyz = (POSITION.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;
	worldPos.w = 1.0;

	highp vec3 ajp = vec3(POSITION.x==16.?0.:POSITION.x,abs(POSITION.y-8.),POSITION.z==16.?0.:POSITION.z);
	highp float gwave = sin(TOTAL_REAL_WORLD_TIME*4.+ajp.x+ajp.z+ajp.y);

	#if !defined(SEASONS) || !defined(ALPHA_TEST)
		if(COLOR.a<.95&&COLOR.a>.05){
			wflag = .5;
			#ifdef vertexwave
				worldPos.y += gwave*.06*fract(POSITION.y);
			#endif
		}
	#endif
	#if defined(ALPHA_TEST) && defined(vertexwave)
		// crop/plants detection from esbe-2g by @McbeEringi
		// see : https://github.com/McbeEringi/esbe-2g
		vec3 frp = fract(POSITION.xyz);
		if((COLOR.r!=COLOR.g&&COLOR.g!=COLOR.b&&frp.y!=.015625)||(frp.y==.9375&&(frp.x==0.||frp.z==0.))){
			worldPos.xyz += gwave*.06*(1.-saturate(length(worldPos.xyz)/FAR_CHUNKS_DISTANCE))*TEXCOORD_1.y;
		}
	#endif
	#if defined(UNDERWATER) && defined(vertexwave)
		worldPos.xyz += gwave*.05;
	#endif

	POS4 pos = WORLDVIEW*worldPos;
	pos = PROJ * pos;
#endif

	gl_Position = pos;

#ifndef BYPASS_PIXEL_SHADER
	uv0 = TEXCOORD_0;
	uv1 = TEXCOORD_1;
	color = COLOR;
	cpos = POSITION.xyz;
	wpos = worldPos.xyz;
#endif

#ifdef UNDERWATER
	float len = length(-worldPos.xyz) / RENDER_DISTANCE;
	#ifdef ALLOW_FADE
		len += RENDER_CHUNK_FOG_ALPHA;
	#endif
	fogr = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);
#endif
}
