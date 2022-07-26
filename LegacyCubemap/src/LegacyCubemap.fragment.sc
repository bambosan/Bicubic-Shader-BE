$input v_fog, cubePos, fogControl, frameTime
#include <bgfx_shader.sh>

float hash(float n){
    return fract(sin(n) * 43758.5453);
}

float noise2d(vec2 pos){
    vec2 ip = floor(pos);
    vec2 fp = fract(pos);
    fp = fp * fp * (3.0 - 2.0 * fp);
    float n = ip.x + ip.y * 57.0;
    return mix(mix(hash(n), hash(n + 1.0), fp.x), mix(hash(n + 57.0), hash(n + 58.0), fp.x), fp.y);
}

float hash(vec2 pos){
    return fract(cos(pos.x + pos.y * 332.0) * 335.552);
}

float voronoi(vec2 pos){
    vec2 fp = fract(pos);
	vec2 ip = floor(pos);
	float s = 1.0;
	for(float i = 0.0; i < 2.0; i += 1.0){
		for(float j = 0.0; j < 2.0; j += 1.0){
			vec2 nb = vec2(j, i);
            float rand = hash(ip + nb);
			vec2 po = 0.3 * sin(600.0 * vec2(rand, rand));
			s = min(s, length(nb + po - fp));
		}
	}
	return s;
}

float fbm(vec2 pos, float density, float rain, float ftime){
    float tot = 0.0;
    density -= rain;
    pos *= 1.6;
    pos += ftime * 0.001;
    for(int i = 0; i < 3; i++){
        tot += voronoi(pos) * density;
        density *= 0.5;
        pos *= 2.5;
        pos += ftime * 0.1;
    }
    return 1.0 - pow(0.1, saturate(1.0 - tot));
}

vec4 renderClouds(vec3 fogcolor, vec2 pos, float duskFog, float nightFog, float rain, float ftime){
    vec3 total = vec3(1.0, 1.0, 1.0) - nightFog * 0.7;
    vec3 shadowColor = mix(fogcolor, fogcolor * 2.5, rain);
    shadowColor = pow(shadowColor, vec3(2.2, 2.2, 2.2));

    float density = 2.2 - rain;
    float alpha = 0.0;

    for(int i = 0; i < 10; i++){
        float cloudMap = fbm(pos, density, rain, ftime);
        if(cloudMap > 0.0){
            vec3 cloudColor = mix(mix(mix(vec3(0.85, 1.0, 1.1), vec3(0.9, 0.6, 0.3), duskFog), vec3(0.15, 0.2, 0.29), nightFog), fogcolor * 2.0, rain);
            cloudColor = pow(cloudColor, vec3(2.2, 2.2, 2.2));
            cloudColor = mix(cloudColor * 3.0, shadowColor * cloudMap, cloudMap);

            total = mix(total, cloudColor, cloudMap);
            alpha += mix(0.0, (1.0 - cloudMap * 0.5) * (1.0 - alpha), cloudMap);
        }

        density *= 0.9345;
        pos *= 0.966;
        shadowColor *= 0.96;
    }
    return vec4(total, alpha);
}

vec3 unchartedModified(vec3 color){
	float A = 0.25;		
	float B = 0.29;
	float C = 0.10;			
	float D = 0.2;		
	float E = 0.03;
	float F = 0.35;
	return ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
}

vec3 renderSky(vec3 pos, vec3 fogcolor, vec2 fogcontrol, float rain, float nightFog, float duskFog){
	vec3 zenithColor = mix(mix(mix(vec3(0.0, 0.4, 0.9), vec3(0.065, 0.15, 0.25), nightFog), vec3(0.5, 0.4, 0.6), duskFog), fogcolor.rgb * 2.0, rain);
	vec3 horizonColor = mix(mix(mix(vec3(0.75, 0.98, 1.15), vec3(1.0, 0.4, 0.5), duskFog), zenithColor + 0.15, nightFog), fogcolor.rgb * 2.0, rain);

	zenithColor = pow(zenithColor, vec3(2.2, 2.2, 2.2));
    horizonColor = pow(horizonColor, vec3(2.2, 2.2, 2.2));

    float cosTheta = saturate(dot(pos, normalize(vec3(-0.98, 0.15, 0.0)))) * duskFog;
    float horizon = exp(-saturate(pos.y) * 4.5) + (pow(cosTheta, 5.0) * 10.0);
	zenithColor = mix(zenithColor, horizonColor, horizon);
	if(fogcontrol.x == 0.0) zenithColor = pow(fogcolor.rgb, vec3(2.2, 2.2, 2.2));
	return zenithColor;
}

void main(){
    float rain = smoothstep(0.6, 0.3, fogControl.x);
    float nightFog = pow(saturate(1.0 - v_fog.r * 1.5), 1.2);
    float duskFog = saturate((v_fog.r - 0.15) * 1.25) * (1.0 - v_fog.b);

    vec3 adjPos = normalize(vec3(cubePos.x, -cubePos.y + 0.23, -cubePos.z));
    vec3 coudPos = adjPos / adjPos.y;
   
    vec4 clouds = renderClouds(v_fog.rgb, coudPos.xz * 0.5, duskFog, nightFog, rain, frameTime);
    vec3 newSkyColor = renderSky(adjPos, v_fog.rgb, fogControl, rain, nightFog, duskFog);
	vec4 color = vec4(newSkyColor, exp(-saturate(adjPos.y) * 5.0));
	color = mix(color, clouds, clouds.a * 0.65 * smoothstep(1.0, 0.96, length(adjPos.xz)) * step(0.0, adjPos.y));

	vec3 curr = unchartedModified(color.rgb * 8.0);
	color.rgb = pow(curr / unchartedModified(vec3(15.0, 15.0, 15.0)), vec3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));
    float gray = length(color.rgb);
    color.rgb = mix(vec3(gray, gray, gray), color.rgb, 1.1);
	gl_FragColor = color;
}
