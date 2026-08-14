module stbtt;

struct BakedChar {
	ushort x0, y0, x1, y1;
	float xoff, yoff, xadvance;
}

struct AlignedQuad {
	float x0, y0, s0, t0;
	float x1, y1, s1, t1;
}

extern fn CInt bake_font_bitmap(
	char* data,
	CInt offset,
	float pixel_height,
	char* pixels,
	CInt pw,
	CInt ph,
	CInt first_char,
	CInt num_chars,
	BakedChar* chardata
) @cname("stbtt_BakeFontBitmap");

extern fn void get_baked_quad(
	BakedChar* chardata,
	CInt pw,
	CInt ph,
	CInt char_index,
	float* xpos,
	float* ypos,
	AlignedQuad* q,
	CInt opengl_fillrule
) @cname("stbtt_GetBakedQuad");
