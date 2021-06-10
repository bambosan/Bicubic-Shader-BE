
float fbm(highp vec2 pos,float amp){
	float tot = 0.0, lac = 1.0;
	pos += TOTAL_REAL_WORLD_TIME*.001;

	for(int i=0; i<3; i++){
		tot += texture2D(TEXTURE_0, pos).r * amp/lac;
		lac *= 2.2;
		pos *= 2.8;
		pos += TOTAL_REAL_WORLD_TIME*.008;
	}
	return 1.0-pow(0.1,max0(1.0-tot));
}

vec4 rcloud(highp vec2 pos){
	vec3 col = vec3(1)-nfog*0.5;
	vec3 shadow = mix(FOG_COLOR.rgb,FOG_COLOR.rgb*2.5,rain);
		shadow = toLinear(shadow);
	float amp = 2.3-rain*2.0;
	float opac = 0.0;

	for(int i = 0; i < 10; i++){
		float cmap = fbm(pos, amp);
		amp *= 0.933;
		pos *= 0.965;
		if(cmap > 0.0){
			vec3 ccloud = cloudcolor();
				ccloud = mix(ccloud*3.0,shadow*cmap,cmap);
			col = mix(col,ccloud,cmap);
    		opac += mix(0.0,(1.0-cmap*0.5)*(1.0-opac),cmap);
		}
		shadow *= 0.96;
	}
	return vec4(col,opac);
}

vec4 rcirrus(highp vec2 pos){
	float tot = 0.0, lac = 1.0;
	pos += TOTAL_REAL_WORLD_TIME * 0.001;

	for(int i = 0; i < 3; i++){
		tot += texture2D(TEXTURE_0, pos).a / lac;
		pos += tot * 0.05;
		lac *= 2.0;
		pos *= 3.0;
	}
		tot = 1.0-pow(0.15,max0(1.0-tot));
	vec3 ccolor = cloudcolor();
	return vec4(ccolor,tot);
}
