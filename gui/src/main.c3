module tte::gui;

import std::io, std::math;
import sdl;
import opengl::gl;
import shader;
import textures;
import font;
import stbtt;
import core;
import camera;

EditorCore core;
Camera cam;

uint vbo, vao, ebo;
uint shaderProgram, texture;
Matrix4f proj;
int screenW = 800;
int screenH = 600;
int projLoc, modelLoc, uvRectLoc, textColorLoc;

float cam_y        = 0.0f;
float cam_target_y = 0.0f;
uint last_ticks;
bool cursor_moved;
uint last_input_ms;
const uint IDLE_MS = 500;

const String VSHADER      = "src/vertex.glsl";
const String FSHADER      = "src/fragment.glsl";
const float LINE_HEIGHT   = 38.0f;
const int MAX_QUADS       = 4096;
const int FLOATS_PER_VERT = 4;
const int VERTS_PER_QUAD  = 6;
const float PAD_X         = 16.0f;
const float PAD_Y         = 12.0f;
const int MEASURE_ROWS    = 20;

float[MAX_QUADS * VERTS_PER_QUAD * FLOATS_PER_VERT] batch;
int batch_verts;

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
	Window* window = sdl::createWindow(
		(char*)title,
		sdl::WINDOWPOS_CENTERED_MASK,
		sdl::WINDOWPOS_CENTERED_MASK,
		800,
		600,
		0x00000022u
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

	opengl::init(&sdl::glGetProcAddress)!!;
	gl::viewport(0, 0, 800, 600);

	gl::clearColor(0.067f, 0.067f, 0.067f, 1.0f);
	Event event;

	bool running = true;

	load();
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
				viewport_resize(newWidth, newHeight);
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
	String vertexShaderSource = shader::load(VSHADER);
	uint vertexShader         = gl::createShader(gl::GL_VERTEX_SHADER);
	gl::shaderSource(vertexShader, 1, (char**)&vertexShaderSource, null);
	gl::compileShader(vertexShader);
	int success;
	char[512] infolog;
	gl::getShaderiv(vertexShader, gl::GL_COMPILE_STATUS, &success);
	if (!success) {
		io::printn("Error shader compilation failed");
	}
	String fragmentShaderSource = shader::load(FSHADER);
	uint fragmentShader         = gl::createShader(gl::GL_FRAGMENT_SHADER);
	gl::shaderSource(fragmentShader, 1, (char**)&fragmentShaderSource, null);
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
	font::bake("/home/trema/.local/share/fonts/MapleMono/MapleMono-Regular.ttf", 32.0f);
	texture = font::atlas_tex;
	gl::enable(gl::GL_BLEND);
	gl::blendFunc(gl::GL_SRC_ALPHA, gl::GL_ONE_MINUS_SRC_ALPHA);
}

fn void render() {
	uint now = sdl::getTicks();
	float dt = (float)(now - last_ticks) / 1000.0f;
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

	float ct = cur_y - font::pixel_h * 0.78f;
	gl::uniform4f(textColorLoc, 0.85f, 0.85f, 0.95f, alpha);
	push_quad(
		cur_x,
		ct,
		cur_x + font::chardata[0].xadvance,
		ct + font::pixel_h,
		font::WHITE_U,
		font::WHITE_V,
		font::WHITE_U,
		font::WHITE_V
	);
	flush();

	cam.follow(cur_x, cur_y, cw, ch);
}

fn void viewport_resize(int width, int height) {
	gl::viewport(0, 0, width, height);
	screenW = width;
	screenH = height;
	cam.resize((float)width, (float)height);
}

fn float draw_text(String text, float x, float y) {
	float xpos  = x;
	float ypos  = y;
	float tab_w = font::chardata[0].xadvance * (float)core.ft.tab_width;

	foreach (c : text) {
		if (c == '\t') {
			float rel = xpos - x;
			xpos = x + (math::floor(rel / tab_w) + 1.0f) * tab_w;
			continue;
		}
		if (c < 32 || c >= 127) continue;

		AlignedQuad q;
		stbtt::get_baked_quad(&font::chardata[0], font::ATLAS_W, font::ATLAS_H, (CInt)c - 32, &xpos, &ypos, &q, 1);
		push_quad(q.x0, q.y0, q.x1, q.y1, q.s0, q.t0, q.s1, q.t1);
	}

	return xpos;
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
	float xpos  = 0.0f; // was PAD_X
	float ypos  = 0.0f;
	int tw      = core.ft.tab_width > 0 ? core.ft.tab_width : 8;
	float tab_w = font::chardata[0].xadvance * (float)tw;

	for (int i = 0; i < cx && i < chars.len; i++) {
		char c = chars[i];
		if (c == '\t') {
			xpos = (math::floor(xpos / tab_w) + 1.0f) * tab_w; // was xpos - PAD_X, then PAD_X + ...
			continue;
		}
		if (c < 32 || c >= 127) continue;
		AlignedQuad q;
		stbtt::get_baked_quad(&font::chardata[0], font::ATLAS_W, font::ATLAS_H, (CInt)c - 32, &xpos, &ypos, &q, 1);
	}
	return xpos;
}

fn float measure_width() {
	int lo = core.cy - MEASURE_ROWS;
	int hi = core.cy + MEASURE_ROWS;
	if (lo < 0) lo = 0;
	if (hi > core.numrows) hi = core.numrows;

	int tw       = core.ft.tab_width > 0 ? core.ft.tab_width : 8;
	float adv    = font::chardata[0].xadvance;
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
