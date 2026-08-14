module camera;

import std::math;

const float MIN_ZOOM   = 1.0f; // furthest pan-out
const float ZOOM_STEP  = 0.05f; // quantise to avoid jitter
const float ZOOM_HYST  = 0.12f; // ignore changes under 12%
const float MOVE_SPEED = 2.0f;
const float ZOOM_SPEED = 2.0f; // same rate
const float MAX_ZOOM   = 3.0f;


struct Camera {
	float x, y; // top-left of view, document space
	float target_x, target_y;
	float zoom, target_zoom;
	float view_w, view_h; // window size in pixels
	bool free_scroll; // wheel overrides auto-follow
	float doc_w, doc_h;
}

fn void Camera.init(&self, float w, float h) {
	self.view_w = w;
	self.view_h = h;
	self.zoom = MAX_ZOOM;
	self.target_zoom = MAX_ZOOM;
	self.x = 0.0f;
	self.y = 0.0f;
	self.target_x = self.x;
	self.target_y = self.y;
	self.free_scroll = false;
}

fn void Camera.resize(&self, float w, float h) {
	self.view_w = w;
	self.view_h = h;
}

// Frame a document-space box: centre on it and zoom to fit, within limits.
fn void Camera.frame(&self, float x0, float y0, float x1, float y1) {
	if (self.free_scroll) return;

	float cw = math::max(x1 - x0, 1.0f);
	float ch = math::max(y1 - y0, 1.0f);

	float fit = math::min(self.view_w / cw, self.view_h / ch);
	fit = math::clamp(fit, MIN_ZOOM, MAX_ZOOM);
	fit = math::round(fit / ZOOM_STEP) * ZOOM_STEP;

	// hysteresis: only retarget on a meaningful change
	if (math::abs(fit - self.target_zoom) / self.target_zoom > ZOOM_HYST) {
		self.target_zoom = fit;
	}

	float vw = self.view_w / self.target_zoom;
	float vh = self.view_h / self.target_zoom;
	self.target_x = (x0 + x1) * 0.5f - vw * 0.5f;
	self.target_y = (y0 + y1) * 0.5f - vh * 0.5f;
}

fn void Camera.pan(&self, float dx, float dy) {
	self.free_scroll = true;
	self.target_x += dx;
	self.target_y += dy;
	self.clamp_target();
}

fn void Camera.release(&self) {
	self.free_scroll = false;
}

fn void Camera.update(&self, float dt) {
	if (dt > 0.1f) dt = 0.1f;
	float kp = 1.0f - math::exp(-MOVE_SPEED * dt);
	float kz = 1.0f - math::exp(-ZOOM_SPEED * dt);

	self.x += (self.target_x - self.x) * kp;
	self.y += (self.target_y - self.y) * kp;
	self.zoom += (self.target_zoom - self.zoom) * kz;
}

fn Matrix4f Camera.projection(&self) {
	float vw = self.view_w / self.zoom;
	float vh = self.view_h / self.zoom;
	return matrix::ortho{float}(
		self.x - vw * 0.5f,
		self.x + vw * 0.5f,
		self.y + vh * 0.5f,
		self.y - vh * 0.5f,
		-1.0f,
		1.0f
	);
}

fn void Camera.bounds(&self, float* x0, float* y0, float* x1, float* y1) {
	float vw = self.view_w / self.zoom;
	float vh = self.view_h / self.zoom;
	*x0 = self.x - vw * 0.5f;
	*y0 = self.y - vh * 0.5f;
	*x1 = self.x + vw * 0.5f;
	*y1 = self.y + vh * 0.5f;
}

fn void Camera.follow(&self, float cursor_x, float cursor_y, float content_w, float content_h) {
	if (self.free_scroll) return;

	if (content_w < 1.0f) content_w = 1.0f;
	if (content_h < 1.0f) content_h = 1.0f;
	if (content_w > 1000.0f) content_w = 1000.0f;

	// zoom to fit both axes; the tighter constraint wins
	float zw = self.view_w / 3.0f / (content_w * 0.75f);
	float zh = self.view_h / content_h;
	float ts = math::min(zw, zh);
	if (ts > MAX_ZOOM) ts = MAX_ZOOM;
	if (ts < MIN_ZOOM) ts = MIN_ZOOM;
	self.target_zoom = ts;

	float vw = self.view_w / ts;
	float vh = self.view_h / ts;

	// horizontal: centre the content while it fits, then dead-zone follow
	if (content_w < vw) {
		self.target_x = content_w * 0.5f;
	} else {
		float third  = vw / 3.0f;
		float offset = cursor_x - third;
		if (offset < 0.0f) offset = 0.0f;
		self.target_x = third + offset;
	}

	// vertical: centre the content while it fits, then follow the cursor
	if (content_h < vh) {
		self.target_y = content_h * 0.5f;
	} else {
		self.target_y = cursor_y;
	}

	self.clamp_target();
}

fn void Camera.set_content(&self, float w, float h) {
	self.doc_w = w;
	self.doc_h = h;
}
fn void Camera.clamp_target(&self) {
	float vh =  self.view_h / self.target_zoom;
	float lo = -vh * 0.25f;
	float hi =  self.doc_h + vh * 0.25f;
	if (self.target_y < lo) self.target_y = lo;
	if (self.target_y > hi) self.target_y = hi;

	float vw = self.view_w / self.target_zoom;
	if (self.target_x < 0.0f) self.target_x = 0.0f;
	if (self.target_x > self.doc_w + vw * 0.5f) self.target_x = self.doc_w + vw * 0.5f;
}
fn void Camera.snap(&self) {
	self.x = self.target_x;
	self.y = self.target_y;
	self.zoom = self.target_zoom;
}
