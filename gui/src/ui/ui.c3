module tte::ui;

import std::math;


struct UiRect
{
	float x, y, w, h;
}

struct UiState
{
	float mouse_x, mouse_y;
	bool mouse_down, mouse_pressed, mouse_released;
	uint hot, active, focus;
	char[64] typed;
	int typed_len;
	int key; // non-printing key this frame, 0 if none
}

UiState ui;

fn void begin()
{
	ui.hot = 0;
}

fn void end()
{
	if (!ui.mouse_down) ui.active = 0;
	ui.mouse_pressed = false;
	ui.mouse_released = false;
	ui.typed_len = 0;
	ui.key = 0;
}

fn bool UiRect.contains(&self, float px, float py)
{
	return px >= self.x && px < self.x + self.w && py >= self.y && py < self.y + self.h;
}


struct Layout
{
	UiRect bounds;
	float cursor_y;
	float pad;
}

fn Layout centered(float w, float h, float sw, float sh)
{
	Layout l;
	l.bounds = { (sw - w) * 0.5f, (sh - h) * 0.5f, w, h };
	l.pad = 16.0f;
	l.cursor_y = l.bounds.y + l.pad;
	return l;
}

fn UiRect Layout.row(&self, float h)
{
	UiRect r = { self.bounds.x + self.pad, self.cursor_y, self.bounds.w - self.pad * 2.0f, h };
	self.cursor_y += h + self.pad * 0.5f;
	return r;
}

fn UiRect UiRect.split(&self, int index, int count, float gap)
{
	float cw = (self.w - gap * (float)(count - 1)) / (float)count;
	return { self.x + ((float)index * (cw + gap)), self.y, cw, self.h };
}
