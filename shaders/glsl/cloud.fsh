// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionSimple.h"
#include "uniformPerFrameConstants.h"

varying highp vec3 pos;

#include "bsbe.cs.glsl"

#ifdef rendercloud
vec4 rclouds(hp vec2 pos){
    vec3 tot = vec3(1)-nfog*.5;
    vec3 sha = mix(FOG_COLOR.rgb,FOG_COLOR.rgb*2.5,rain);
        sha = tl(sha);
    float den = 2.2-rain,a = 0.;
    for(int i=0; i<10; i++){
        float cm = fbm(pos,den);
        den *= .9345;
        pos *= .966;
        if(cm>0.){
            vec3 cc = ccc();
                cc = mix(cc*3.,sha*cm,cm);
            tot = mix(tot,cc,cm);
            a += mix(0.,(1.-cm*.5)*(1.-a),cm);
        }
        sha *= .97;
    }
    return vec4(tot,a);
}
#endif

void main(){

    hp vec3 ajp = vec3(pos.x,-pos.y+.128,-pos.z);
    hp vec3 uppos = normalize(vec3(0.,abs(ajp.y),0.));
    hp vec3 npos = normalize(ajp);
    hp float zenith = max0(dot(npos,uppos));
    vec3 skyl = sr(npos,uppos);
    vec4 color = vec4(skyl,pow(1.-zenith,5.));
#ifdef rendercloud
    hp vec3 dpos = npos/npos.y;
    vec4 cloud = rclouds(dpos.xz*.8);
        color = mix(vec4(und,pow(1.-zenith,5.)),cloud,cloud.a*.6*smoothstep(1.,.95,length(npos.xz))*float(zenith>0.));
#endif


        color.rgb = tonemap(color.rgb);

    gl_FragColor = color;
}
