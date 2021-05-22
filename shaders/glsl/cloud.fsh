// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionSimple.h"
#include "uniformPerFrameConstants.h"

varying highp vec3 pos;

#include "bsbe.cs.glsl"

#ifdef rendercloud
vec4 rc(hp vec2 p){
    vec3 t = vec3(1)-nfog*.5;
    vec3 s = mix(FOG_COLOR.rgb,FOG_COLOR.rgb*2.5,rain);
        s = tl(s);
    float d = 2.2-rain,o = 0.;
    for(int i=0; i<10; i++){
        float m = fbm(p,d);
        d *= .9345;
        p *= .966;
        if(m>0.){
            vec3 c = ccc();
                c = mix(c*3.,s*m,m);
            t = mix(t,c,m);
            o += mix(0.,(1.-m*.5)*(1.-o),m);
        }
        s *= .97;
    }
    return vec4(t,o);
}
#endif

void main(){

    hp vec3 a = vec3(pos.x,-pos.y+.128,-pos.z);
    hp vec3 u = normalize(vec3(0.,abs(a.y),0.)), n = normalize(a);
    hp float z = max0(dot(n,u));
    vec3 s = sr(n,u);
    vec4 c = vec4(s,pow(1.-z,5.));
#ifdef rendercloud
    hp vec3 d = n/n.y;
    vec4 cl = rc(d.xz*.8);
        c = mix(vec4(s,pow(1.-z,5.)),cl,cl.a*.6*smoothstep(1.,.95,length(n.xz))*float(z>0.));
#endif
        c.rgb = tonemap(c.rgb);

    gl_FragColor = c;
}
