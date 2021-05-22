#define hp highp
#define mp mediump
#define lp lowp

#define max0(x) max(0.,x)
#define saturate(x) clamp(x,0.,1.)
#define dside(x,y,z) mix(x,y,max0(abs(z)))
#define rain smoothstep(.6,.3,FOG_CONTROL.x)
#define nfog pow(saturate(1.-FOG_COLOR.r*1.5),1.2)
#define dfog saturate((FOG_COLOR.r-.15)*1.25)*(1.-FOG_COLOR.b)

float hash(hp float n){ return fract(sin(n)*43758.5453); }
float hash(hp vec2 p){ return fract(cos(p.x+p.y*332.)*335.552); }
float noise(hp vec2 x){
	hp vec2 p = floor(x);
	hp vec2 f = fract(x);
		f = f*f*(3.-2.*f);
	hp float n = p.x+p.y*57.;
	return mix(mix(hash(n),hash(n+1.),f.x),mix(hash(n+57.),hash(n+58.),f.x),f.y);
}
float vnt(hp vec2 p){
	hp vec2 fp = fract(p);
	hp vec2 ip = floor(p);
	hp float s = 1.;
	for(int i=0; i<2; i++){
		for(int j=0; j<2; j++){
			hp vec2 nb = vec2(float(j),float(i));
			hp vec2 po = .3*sin(600.*vec2(hash(ip+nb)));
			s = min(s,length(nb+po-fp));
		}
	}
	return s;
}
uniform hp float TOTAL_REAL_WORLD_TIME;
float fbm(hp vec2 p,float d){
	float t = 0.,s = 1.;
	p += TOTAL_REAL_WORLD_TIME*.001;
	for(int i=0; i<3; i++){
		t += vnt(p)*d/s; s *= 2.2;
		p *= 2.8;
		p += TOTAL_REAL_WORLD_TIME*.03;
	}
	return 1.-pow(.1,max0(1.-t));
}
vec3 tl(vec3 c){ return pow(c,vec3(2.2)); }
vec3 ccc(){
	vec3 c = mix(mix(mix(vec3(1),vec3(.15,.2,.29),nfog),vec3(1.,.3,.5),dfog),FOG_COLOR.rgb*1.5,rain);
		c = tl(c);
	return c;
}
vec3 csc(float sh){
	vec3 s = mix(mix(mix(vec3(0.,.35,.8),vec3(.06,.1,.2),nfog),vec3(.5,.4,.6),dfog),FOG_COLOR.rgb*2.,rain);
	vec3 h = mix(mix(mix(vec3(.8,.9,1.),vec3(1.,.4,.5),dfog),skyc+.15,nfog),FOG_COLOR.rgb*2.,rain);
		s = tl(s);
		h = tl(h);
		s = mix(s,h,sh);
	if(FOG_CONTROL.x==0.)s=tl(FOG_COLOR.rgb);
	return s;
}
vec3 sr(hp vec3 n, hp vec3 u){
	float z = max0(dot(n,u));
	float m = pow(1.-length(n.zy),3.)*15.;
	float h = pow(1.-z,2.5)+m*dfog;
	vec3 c = csc(h);
	return c;
}
vec3 tonemap(vec3 c){
	c *= 1.3;
 	c = c/(.9813*c+.1511);
	float l = dot(c,vec3(.2125,.7154,.0721));
	c = mix(vec3(l),c,1.1);
	return c;
}
