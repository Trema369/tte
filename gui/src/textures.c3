module textures;

import std::io;
import opengl::gl;

const int TEX_SIZE = 8;

fn uint make_checkerboard() {
	char[TEX_SIZE * TEX_SIZE * 3] pixels;
	for (int y = 0; y < TEX_SIZE; y++) {
		for (int x = 0; x < TEX_SIZE; x++) {
			char v = ((x + y) % 2 == 0) ? (char)255 : (char)40;
			int i  = (y * TEX_SIZE + x) * 3;
			pixels[i] = v;
			pixels[i + 1] = v;
			pixels[i + 2] = v;
		}
	}

	uint tex;
	gl::genTextures(1, &tex);
	gl::bindTexture(gl::GL_TEXTURE_2D, tex);

	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_S, gl::GL_REPEAT);
	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_WRAP_T, gl::GL_REPEAT);
	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MIN_FILTER, gl::GL_NEAREST);
	gl::texParameteri(gl::GL_TEXTURE_2D, gl::GL_TEXTURE_MAG_FILTER, gl::GL_NEAREST);

	gl::texImage2D(
		gl::GL_TEXTURE_2D, // target
		0, // mipmap level
		gl::GL_RGB, // internal format (how GL stores it)
		TEX_SIZE,
		TEX_SIZE,
		0, // border — always 0, legacy
		gl::GL_RGB, // format of the data you're supplying
		gl::GL_UNSIGNED_BYTE, // type of the data
		&pixels
	);
	return tex;
}
