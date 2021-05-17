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
float fbm(hp vec2 pos,float den){
	float tot = 0.,s = 1.;
	pos += TOTAL_REAL_WORLD_TIME*.001;
	for(int i=0; i<3; i++){
		tot += vnt(pos)*den/s; s *= 2.2;
		pos *= 2.8;
		pos += TOTAL_REAL_WORLD_TIME*.03;
	}
	return 1.-pow(.1,max0(1.-tot));
}
vec3 tl(vec3 col){ return pow(col,vec3(2.2)); }
vec3 ccc(){
	vec3 cloudc = mix(mix(mix(vec3(1),vec3(.15,.2,.29),nfog),vec3(1.,.3,.5),dfog),FOG_COLOR.rgb*1.5,rain);
		cloudc = tl(cloudc);
	return cloudc;
}
vec3 csc(float skyh){
	vec3 skyc = mix(mix(mix(vec3(0.,.35,.8),vec3(.06,.1,.2),nfog),vec3(.5,.4,.6),dfog),FOG_COLOR.rgb*2.,rain);
	vec3 scc = mix(mix(mix(vec3(.8,.9,1.),vec3(1.,.4,.5),dfog),skyc+.15,nfog),FOG_COLOR.rgb*2.,rain);
		skyc = tl(skyc);
		scc = tl(scc);
		skyc = mix(skyc,scc,skyh);
	if(FOG_CONTROL.x==0.)skyc=tl(FOG_COLOR.rgb);
	return skyc;
}
vec3 sr(hp vec3 npos, hp vec3 uppos){
	float zenith = max0(dot(npos,uppos));
	float mies = pow(1.-length(npos.zy),3.)*15.;
	float hor = pow(1.-zenith,2.5)+mies*dfog;
	vec3 tsc = csc(hor);
	return tsc;
}
vec3 tonemap(vec3 col){
	col *= 1.3;
 	col = col/(.9813*col+.1511);
	float lum = dot(col,vec3(.2125,.7154,.0721));
	col = mix(vec3(lum),col,1.1);
	return col;
}
