module tte::gui;

import std::io, std::math;
import sdl;
import shader;
import textures;
import font;
import stbtt;
import tte::render;

int screenW;
int screenH;
uint frames;

fn int main(String[] args) {
	if (sdl::init(sdl::INIT_VIDEO) != 0) {
		io::printfn("SDL init failed: %s", (ZString)sdl::getError());
	}
	defer sdl::quit();

	sdl::glSetAttribute(GLattr.GL_CONTEXT_MAJOR_VERSION, 3);
	sdl::glSetAttribute(GLattr.GL_CONTEXT_MINOR_VERSION, 3);
	sdl::glSetAttribute(GLattr.GL_CONTEXT_PROFILE_MASK, 0x0001);
	sdl::glSetAttribute(GLattr.GL_DOUBLEBUFFER, 1);

	ZString title = "learn opengl";
	DisplayMode dm;
	sdl::getCurrentDisplayMode(0, &dm);
	screenW = (int)((float)dm.w * 0.85f);
	screenH = (int)((float)dm.h * 0.85f);

	Window* window = sdl::createWindow(
		(char*)title,
		sdl::WINDOWPOS_CENTERED_MASK,
		sdl::WINDOWPOS_CENTERED_MASK,
		screenW,
		screenH,
		0x00002022u
	);

	render::init(args, window);
	return 0;
}
