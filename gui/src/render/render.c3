module tte::render;

import std::io, std::math;
import sdl;
import opengl::gl;
import shader;
import textures;
//import font;
//import stbtt;
//import core;
import camera;

EditorCore core;
Camera cam;

uint vbo, vao, ebo;
uint shaderProgram, texture;
Matrix4f proj;
int screenW;
int screenH;
int projLoc, modelLoc, uvRectLoc, textColorLoc;
uint frames;
uint fps_ms;

float cam_y        = 0.0f;
float cam_target_y = 0.0f;
uint last_ticks;
bool cursor_moved;
uint last_input_ms;
const uint IDLE_MS = 500;

const char[*] FONT_TTF    = $embed("../assets/font.ttf");
const String VSHADER      = "src/vertex.glsl";
const String FSHADER      = "src/fragment.glsl";
const char[*] VERT_SRC    = $embed("vertex.glsl");
const char[*] FRAG_SRC    = $embed("fragment.glsl");
const float LINE_HEIGHT   = 38.0f;
const int MAX_QUADS       = 4096;
const int FLOATS_PER_VERT = 4;
const int VERTS_PER_QUAD  = 6;
const float PAD_X         = 16.0f;
const float PAD_Y         = 12.0f;
const int MEASURE_ROWS    = 20;

float[MAX_QUADS * VERTS_PER_QUAD * FLOATS_PER_VERT] batch;
int batch_verts;
ulong perf_last;
ulong perf_freq;

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

	if (!window) {
		io::printfn("createWindow failed: %s", (ZString)sdl::getError());
		return 1;
	}
	sdl::startTextInput();

	defer sdl::destroyWindow(window);
	GLContext ctx = sdl::glCreateContext(window);
	if (!ctx) {
		io::printfn("GL context failed: %s", (ZString)sdl::getError());
		return 1;
	}
	defer sdl::glDeleteContext(ctx);
	sdl::glSetSwapInterval(1);

	opengl::init(&sdl::glGetProcAddress)!!;

	int dw;
	int dh;

	sdl::glGetDrawableSize(window, &dw, &dh);
	gl::viewport(0, 0, dw, dh);

	screenW = dw;
	screenH = dh;

	gl::clearColor(0.067f, 0.067f, 0.067f, 1.0f);
	Event event;

	bool running = true;

	load();
	perf_freq = sdl::getPerformanceFrequency();
	perf_last = sdl::getPerformanceCounter();
	cam.init((float)screenW, (float)screenH);
	core.init();
	if (args.len >= 2) core.open(args[1]);

	float cw = measure_width();
	float ch = (float)(core.numrows + 1) * LINE_HEIGHT;
	cam.set_content(cw, ch);
	cam.follow(0.0f, LINE_HEIGHT, cw, ch);
	cam.snap();

	while (running) {
		while (sdl::pollEvent(&event) != 0) {
			if ((int)event.type == 256) running = false;
			if (event.type == EventType.WINDOWEVENT
				&& event.window.event == (char)WindowEventID.WINDOWEVENT_SIZE_CHANGED) {
				int newWidth  = event.window.data1;
				int newHeight = event.window.data2;
				viewport_resize(window, newWidth, newHeight);
			}
			if ((int)event.type == 1027) {
				cam.pan(0.0f, -(float)event.wheel.y * LINE_HEIGHT * 3.0f);
			}
			if ((int)event.type == 771) {
				// SDL_TEXTINPUT
				ZString txt = (ZString)&event.text.text[0];
				foreach (c : txt.str_view()) {
					core.insertChar(c);
				}
				cam.release();
				last_input_ms = sdl::getTicks();
			}

			if ((int)event.type == 768) {
				// SDL_KEYDOWN
				int sym   = (int)event.key.keysym.sym;
				bool ctrl = (event.key.keysym.mod & 0x00C0) != 0;

				switch (sym) {
					case 13: core.insertNewline();  // RETURN
					case 8: core.delChar();  // BACKSPACE
					case 1073741904: core.moveCursor(Direction.LEFT);
					case 1073741903: core.moveCursor(Direction.RIGHT);
					case 1073741906: core.moveCursor(Direction.UP);
					case 1073741905: core.moveCursor(Direction.DOWN);
					case 9: core.insertTab();  // TAB
					case 115: if (ctrl) { if (catch core.save()) { } }  // Ctrl-S
					default: break;
				}
				cam.release();
				last_input_ms = sdl::getTicks();
			}
		}
		gl::clear(gl::GL_COLOR_BUFFER_BIT);
		render();
		sdl::glSwapWindow(window);
	}

	return 0;
}

fn void load() {
	proj = matrix::ortho{float}(0.0f, (float)screenW, (float)screenH, 0.0f, -1.0f, 1.0f);
	float[] vertices = {
		// pos              // uv
		1.0f, 0.0f, 0.0f, 1.0f, 0.0f, // 0 top right
		1.0f, 1.0f, 0.0f, 1.0f, 1.0f, // 1 bottom right
		0.0f, 1.0f, 0.0f, 0.0f, 1.0f, // 2 bottom left
		0.0f, 0.0f, 0.0f, 0.0f, 0.0f // 3 top left
		};
	uint[] indices = { 0, 1, 3, 1, 2, 3 };

	// generating vao

	gl::genVertexArrays(1, &vao);
	gl::bindVertexArray(vao);

	// generating the vbo
	gl::genBuffers(1, &vbo);
	gl::bindBuffer(gl::GL_ARRAY_BUFFER, vbo);
	gl::bufferData(target: gl::GL_ARRAY_BUFFER, size: batch.len * float::size, data: null, usage: gl::GL_DYNAMIC_DRAW);

	// generating ebo
	gl::genBuffers(1, &ebo);
	gl::bindBuffer(gl::GL_ELEMENT_ARRAY_BUFFER, ebo);
	gl::bufferData(
		target: gl::GL_ELEMENT_ARRAY_BUFFER,
		size: indices.len * float::size,
		data: indices,
		usage: gl::GL_STATIC_DRAW
	);
	char* vp          = &VERT_SRC[0];
	int vlen          = VERT_SRC.len;
	uint vertexShader = gl::createShader(gl::GL_VERTEX_SHADER);
	gl::shaderSource(vertexShader, 1, &vp, &vlen);
	gl::compileShader(vertexShader);
	int success;
	char[512] infolog;
	gl::getShaderiv(vertexShader, gl::GL_COMPILE_STATUS, &success);
	if (!success) {
		io::printn("Error shader compilation failed");
	}
	char* fp            = &FRAG_SRC[0];
	int flen            = FRAG_SRC.len;
	uint fragmentShader = gl::createShader(gl::GL_FRAGMENT_SHADER);
	gl::shaderSource(fragmentShader, 1, &fp, &flen);
	gl::compileShader(fragmentShader);

	defer {
		gl::deleteShader(vertexShader);
		gl::deleteShader(fragmentShader);
	}

	shaderProgram = gl::createProgram();
	gl::attachShader(shaderProgram, vertexShader);
	gl::attachShader(shaderProgram, fragmentShader);
	gl::linkProgram(shaderProgram);


	gl::vertexAttribPointer(
		index: 0,
		size: 2,
		type: gl::GL_FLOAT,
		normalized: gl::GL_FALSE,
		stride: 4 * float::size,
		pointer: (void*)0
	);
	gl::enableVertexAttribArray(0);

	gl::vertexAttribPointer(
		index: 1,
		size: 2,
		type: gl::GL_FLOAT,
		normalized: gl::GL_FALSE,
		stride: 4 * float::size,
		pointer: (void*)(2 * float::size)
	);
	gl::enableVertexAttribArray(1);

	projLoc = gl::getUniformLocation(shaderProgram, "projection");
	if (projLoc == -1) io::printn("warning: projection uniform not found");
	uvRectLoc = gl::getUniformLocation(shaderProgram, "uvRect");
	textColorLoc = gl::getUniformLocation(shaderProgram, "textColor");
	// gl::polygonMode(gl::GL_FRONT_AND_BACK, gl::GL_LINE);
	font::bake_bytes(FONT_TTF[..], 32.0f * font::OVERSAMPLE);
	texture = font::atlas_tex;
	gl::enable(gl::GL_BLEND);
	gl::blendFunc(gl::GL_SRC_ALPHA, gl::GL_ONE_MINUS_SRC_ALPHA);
}

fn void render() {
	ulong pnow = sdl::getPerformanceCounter();
	float dt   = (float)(pnow - perf_last) / (float)perf_freq;
	perf_last = pnow;
	uint now = sdl::getTicks(); // keep for blink + fps
	last_ticks = now;
	float cw = measure_width();
	float ch = (float)(core.numrows + 1) * LINE_HEIGHT;
	cam.set_content(cw, ch);


	cam.update(dt); // animate toward last frame's target
	proj = cam.projection();

	gl::useProgram(shaderProgram);
	gl::uniformMatrix4fv(projLoc, 1, gl::GL_FALSE, &proj.m[0]);
	gl::uniform4f(textColorLoc, 0.9f, 0.9f, 0.9f, 1.0f);
	gl::bindTexture(gl::GL_TEXTURE_2D, font::atlas_tex);

	float bx0, by0, bx1, by1;
	cam.bounds(&bx0, &by0, &bx1, &by1);
	int first = (int)(by0 / LINE_HEIGHT) - 1;
	int last  = (int)(by1 / LINE_HEIGHT) + 2;
	if (first < 0) first = 0;
	if (last > core.numrows) last = core.numrows;

	for (int i = first; i < last; i++) {
		float end = draw_text(core.rows[i].chars, 0.0f, (float)(i + 1) * LINE_HEIGHT);
	}
	flush();

	// cursor
	String line = core.cy < core.numrows ? core.rows[core.cy].chars : "";
	float cur_x = cursor_x(line, core.cx);
	float cur_y = (float)(core.cy + 1) * LINE_HEIGHT;

	float alpha = 1.0f;
	uint idle   = now - last_input_ms;
	if (idle > IDLE_MS) {
		float t = (float)(idle - IDLE_MS) / 1000.0f;
		alpha = 0.30f + 0.70f * (0.5f + 0.5f * math::cos(t * 3.2f));
	}

	float ct = cur_y - font::height() * 0.78f;
	gl::uniform4f(textColorLoc, 0.85f, 0.85f, 0.95f, alpha);
	push_quad(
		cur_x,
		ct,
		cur_x + font::advance(),
		ct + font::height(),
		font::WHITE_U,
		font::WHITE_V,
		font::WHITE_U,
		font::WHITE_V
	);
	flush();

	cam.follow(cur_x, cur_y, cw, ch);
	frames++;
	if (now - fps_ms > 1000) {
		io::printfn("fps %d  zoom %f  rows %d", frames, cam.zoom, core.numrows);
		frames = 0;
		fps_ms = now;
	}
}

fn void viewport_resize(Window* window, int width, int height) {
	int dw;
	int dh;
	sdl::glGetDrawableSize(window, &dw, &dh);
	gl::viewport(0, 0, dw, dh);
	screenW = dw;
	screenH = dh;
	cam.resize((float)dw, (float)dh);
}

fn float draw_text(String text, float x, float y) {
	float xpos  = 0.0f;
	float ypos  = 0.0f;
	int tw      = core.ft.tab_width > 0 ? core.ft.tab_width : 8;
	float tab_w = font::chardata[0].xadvance * (float)tw; // atlas space

	foreach (c : text) {
		if (c == '\t') {
			xpos = (math::floor(xpos / tab_w) + 1.0f) * tab_w;
			continue;
		}
		if (c < 32 || c >= 127) continue;

		AlignedQuad q;
		stbtt::get_baked_quad(&font::chardata[0], font::ATLAS_W, font::ATLAS_H, (CInt)c - 32, &xpos, &ypos, &q, 1);

		push_quad(
			x + q.x0 / font::OVERSAMPLE,
			y + q.y0 / font::OVERSAMPLE,
			x + q.x1 / font::OVERSAMPLE,
			y + q.y1 / font::OVERSAMPLE,
			q.s0,
			q.t0,
			q.s1,
			q.t1
		);
	}
	return x + xpos / font::OVERSAMPLE;
}

fn void push_quad(float x0, float y0, float x1, float y1, float s0, float t0, float s1, float t1) {
	if (batch_verts + VERTS_PER_QUAD > MAX_QUADS * VERTS_PER_QUAD) flush();

	int i = batch_verts * FLOATS_PER_VERT;
	float[24] v = {
		x0, y0, s0, t0,
		x1, y0, s1, t0,
		x1, y1, s1, t1,
		x0, y0, s0, t0,
		x1, y1, s1, t1,
		x0, y1, s0, t1
		};
	foreach (j, f : v) batch[i + j] = f;
	batch_verts += VERTS_PER_QUAD;
}

fn void flush() {
	if (batch_verts == 0) return;
	gl::bindBuffer(gl::GL_ARRAY_BUFFER, vbo);
	gl::bufferSubData(gl::GL_ARRAY_BUFFER, 0, (long)(batch_verts * FLOATS_PER_VERT) * float::size, &batch[0]);
	gl::bindVertexArray(vao);
	gl::drawArrays(gl::GL_TRIANGLES, 0, batch_verts);
	batch_verts = 0;
}

fn float cursor_x(String chars, int cx) {
	float xpos  = 0.0f;
	float ypos  = 0.0f;
	int tw      = core.ft.tab_width > 0 ? core.ft.tab_width : 8;
	float tab_w = font::chardata[0].xadvance * (float)tw; // atlas space

	for (int i = 0; i < cx && i < chars.len; i++) {
		char c = chars[i];
		if (c == '\t') {
			xpos = (math::floor(xpos / tab_w) + 1.0f) * tab_w;
			continue;
		}
		if (c < 32 || c >= 127) continue;
		AlignedQuad q;
		stbtt::get_baked_quad(&font::chardata[0], font::ATLAS_W, font::ATLAS_H, (CInt)c - 32, &xpos, &ypos, &q, 1);
	}
	return xpos / font::OVERSAMPLE; // ← the only change
}

fn float measure_width() {
	int lo = core.cy - MEASURE_ROWS;
	int hi = core.cy + MEASURE_ROWS;
	if (lo < 0) lo = 0;
	if (hi > core.numrows) hi = core.numrows;

	int tw       = core.ft.tab_width > 0 ? core.ft.tab_width : 8;
	float adv    = font::advance();
	float widest = adv;

	for (int i = lo; i < hi; i++) {
		String s = core.rows[i].chars;
		int cols = 0;
		foreach (c : s) {
			if (c == '\t') {
				cols = (cols / tw + 1) * tw;
			} else {
				cols++;
			}
		}
		float w = (float)cols * adv;
		if (w > widest) widest = w;
	}
	return widest;
}
