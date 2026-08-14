module font;

import std::io;
import opengl::gl;
import stbtt;

const int ATLAS_W    = 512;
const int ATLAS_H    = 128;
const int FIRST_CHAR = 32;
const int NUM_CHARS  = 96;
const float WHITE_U  = ((float)ATLAS_W - 2.0f) / (float)ATLAS_W;
const float WHITE_V  = ((float)ATLAS_H - 2.0f) / (float)ATLAS_H;

BakedChar[NUM_CHARS] chardata;
uint atlas_tex;

float pixel_h;

fn bool bake(String ttf_path, float pixel_height) => @pool() {
	pixel_h = pixel_height;
	char[]? ttf = file::load_temp(ttf_path);
	if (catch ttf) {
		io::printfn("could not read %s", ttf_path);
		return false;
	}

	char[] bitmap = mem::new_array(char, ATLAS_W * ATLAS_H);
	defer mem::free(bitmap.ptr);

	CInt rows = stbtt::bake_font_bitmap(
		ttf.ptr,
		0,
		pixel_height,
		bitmap.ptr,
		ATLAS_W,
		ATLAS_H,
		FIRST_CHAR,
		NUM_CHARS,
		&chardata[0]
	);
	if (rows <= 0) {
		io::printfn("atlas too small at %f px (returned %d)", pixel_height, rows);
		return false;
	}
	// solid white block in the bottom-right corner
	for (int yy = ATLAS_H - 4; yy < ATLAS_H; yy++) {
		for (int xx = ATLAS_W - 4; xx < ATLAS_W; xx++) {
			bitmap[yy * ATLAS_W + xx] = 255;
		}
	}
	io::printfn("baked %d glyphs, used %d rows", NUM_CHARS, rows);

	gl::genTextures(1, &atlas_tex);
	gl::bindTexture(gl::GL_TEXTURE_2D, atlas_tex);

	gl::pixelStorei(gl::GL_UNPACK_ALIGNMENT, 1);

	gl::texImage2D(gl::GL_TEXTURE_2D, 0, gl::GL_RED, ATLAS_W, ATLAS_H, 0, gl::GL_RED, gl::GL_UNSIGNED_BYTE, bitmap.ptr);

	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_LINEAR);
	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, gl::GL_LINEAR);
	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, gl::GL_CLAMP_TO_EDGE);
	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, gl::GL_CLAMP_TO_EDGE);

	return true;
}
