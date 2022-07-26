$input v_color0, v_fog, smPos, fogControl
#include <bgfx_shader.sh>

vec3 unchartedModified(vec3 color){
	float A = 0.25;		
	float B = 0.29;
	float C = 0.10;			
	float D = 0.2;		
	float E = 0.03;
	float F = 0.35;
	return ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
}

void main(){
    float rain = smoothstep(0.6, 0.3, fogControl.x);
	float nightFog = pow(saturate(1.0 - v_fog.r * 1.5), 1.2);
	float duskFog = saturate((v_fog.r - 0.15) * 1.25) * (1.0 - v_fog.b);

    vec3 color = mix(mix(vec3(1.0, 0.7, 0.2), vec3(0.8, 1.0, 1.2), nightFog), v_fog.rgb, rain);
    color = pow(color, vec3(2.2, 2.2, 2.2));
    
    vec3 shape = color * smoothstep(0.8, 0.9, 1.0 - length(smPos.xz * 32.0));
    shape += exp(-length(smPos.xz * 60.0)) * color * 0.05;
    shape += exp(-length(smPos.xz * 15.0)) * color * duskFog * 0.05;

    vec3 curr = unchartedModified(shape * 4.0);
	shape = pow(curr / unchartedModified(vec3(15.0, 15.0, 15.0)), vec3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));
	float gray = length(shape.rgb);
    shape.rgb = mix(vec3(gray, gray, gray), shape.rgb, 1.1);
    gl_FragColor = vec4(shape, 1.0) * v_color0;
}
