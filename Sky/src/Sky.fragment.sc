$input v_color0, v_fog, skyPos, fogControl, frameTime
#include <bgfx_shader.sh>

#if !defined(FALLBACK) || !defined(GEOMETRY_PREPASS)
vec3 unchartedModified(vec3 color){
	float A = 0.25;		
	float B = 0.29;
	float C = 0.10;			
	float D = 0.2;		
	float E = 0.03;
	float F = 0.35;
	return ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
}

vec3 skyRender(vec3 fogcolor, vec2 fogcontrol, float horizon, float rain, float duskFog, float nightFog){
	vec3 zenithColor = mix(mix(mix(vec3(0.0, 0.38, 0.9), vec3(0.065, 0.15, 0.25), nightFog), vec3(0.5, 0.4, 0.6), duskFog), fogcolor.rgb * 2.0, rain);
	vec3 horizonColor = mix(mix(mix(vec3(0.75, 0.98, 1.15), vec3(1.0, 0.4, 0.5), duskFog), zenithColor + 0.15, nightFog), fogcolor.rgb * 2.0, rain);

	zenithColor = pow(zenithColor, vec3(2.2, 2.2, 2.2));
    horizonColor = pow(horizonColor, vec3(2.2, 2.2, 2.2));

	zenithColor = mix(zenithColor, horizonColor, horizon + 0.1);
	if(fogcontrol.x == 0.0) zenithColor = pow(fogcolor.rgb, vec3(2.2, 2.2, 2.2));
	return zenithColor;
}
#endif

void main(){
#if defined(FALLBACK) || defined(GEOMETRY_PREPASS)
	gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
#else
	float rain = smoothstep(0.6, 0.3, fogControl.x);
	float nightFog = pow(saturate(1.0 - v_fog.r * 1.5), 1.2);
	float duskFog = saturate((v_fog.r - 0.15) * 1.25) * (1.0 - v_fog.b);
    float horizon = length(skyPos.xz);
	horizon = (horizon * horizon) * 2.0;
    vec3 color = skyRender(v_fog.rgb, fogControl, horizon, rain, duskFog, nightFog);
    vec3 curr = unchartedModified(color * 8.0);
	color = pow(curr / unchartedModified(vec3(15.0, 15.0, 15.0)), vec3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));
	float gray = length(color.rgb);
    color.rgb = mix(vec3(gray, gray, gray), color.rgb, 1.1);
    gl_FragColor = vec4(color, 1.0);
#endif
}
