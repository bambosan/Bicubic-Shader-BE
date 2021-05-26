// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionSimple.h"
#include "uniformPerFrameConstants.h"

varying highp vec3 cpos;

#include "bsbe.cs.glsl"

#ifdef rendercloud
vec4 rendercloud(highp vec2 pos){
    vec3 col = vec3(1)-nfog*0.5;
    vec3 shadow = mix(FOG_COLOR.rgb,FOG_COLOR.rgb*2.5,rain);
        shadow = toLinear(shadow);
    float amp = 2.2-rain;
    float opacity = 0.0;

    for(int i = 0; i < 10; i++){
        float cmap = fractalb(pos, amp);
        amp *= 0.9345;
        pos *= 0.966;
        if(cmap > 0.0){
            vec3 ccloud = cloudcolor();
                ccloud = mix(ccloud*3.0,shadow*cmap,cmap);
            col = mix(col,ccloud,cmap);
            opacity += mix(0.0,(1.0-cmap*0.5)*(1.0-opacity),cmap);
        }
        shadow *= 0.97;
    }

    return vec4(col,opacity);
}
#endif

void main(){

    highp vec3 ajpos = vec3(cpos.x, -cpos.y+.128, -cpos.z);
    highp vec3 uppos = normalize(vec3(0.0,abs(ajpos.y),0.0));
    highp vec3 npos = normalize(ajpos);

    float zenith = max0(dot(npos,uppos));
    vec3 sky = rendersky(npos,uppos);
    vec4 color = vec4(sky,pow(1.0-zenith,5.0));
#ifdef rendercloud

    highp vec3 dpos = npos/npos.y;
    vec4 cloud = rendercloud(dpos.xz*0.8);

        color = mix(vec4(sky,pow(1.0-zenith,5.0)),
        cloud,
        cloud.a*smoothstep(1.0,0.95,length(npos.xz))*0.6*float(zenith > 0.0));
#endif
        color.rgb = colorcorrection(color.rgb);

    gl_FragColor = color;
}
