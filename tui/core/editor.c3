module core::editor;

import std::io;
import core::models;

enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN
}


// ---------- helpers ----------

fn String leadingWhitespace(String s) {
	usz i = 0;
	while (i < s.len && (s[i] == ' ' || s[i] == '\t')) i++;
	return s[:i];
}

// ---------- row-level text ops (no cursor, no dirty) ----------

fn void Erow.free(&self) {
	if (self.chars.ptr) mem::free(self.chars.ptr);
}

fn void Erow.insertChar(&self, int at, char c) => @pool() {
	if (at < 0 || at > self.chars.len) at = (int)self.chars.len;

	DString s = dstring::temp_with_capacity(self.chars.len + 2);
	s.append(self.chars[:at]);
	s.append(c);
	if (at < self.chars.len) s.append(self.chars[at..]);

	mem::free(self.chars.ptr);
	self.chars = s.str_view().copy(mem);
}

fn void Erow.delChar(&self, int at) => @pool() {
	if (at < 0 || at >= self.chars.len) return;

	DString s = dstring::temp_with_capacity(self.chars.len);
	s.append(self.chars[:at]);
	if (at + 1 < (int)self.chars.len) s.append(self.chars[at + 1..]);

	mem::free(self.chars.ptr);
	self.chars = s.str_view().copy(mem);
}

fn void Erow.appendString(&self, String tail) => @pool() {
	DString s = dstring::temp_with_capacity(self.chars.len + tail.len);
	s.append(self.chars);
	s.append(tail);

	mem::free(self.chars.ptr);
	self.chars = s.str_view().copy(mem);
}

// ---------- row list ----------

fn void EditorCore.insertRow(&self, int at, String value) {
	if (at < 0 || at > self.numrows) return;
	self.rows.insert_at(at, (Erow) { .chars = value.copy(mem) });
	self.numrows++;
	self.dirty++;
}

fn void EditorCore.delRow(&self, int at) {
	if (at < 0 || at >= self.numrows) return;
	self.rows[at].free();
	self.rows.remove_at(at);
	self.numrows--;
	self.dirty++;
}

// ---------- editing ----------

fn char EditorCore.charAtCursor(&self) {
	if (self.cy >= self.numrows) return 0;
	Erow* row = &self.rows[self.cy];
	if (self.cx >= row.chars.len) return 0;
	return row.chars[self.cx];
}

fn void EditorCore.setFilename(&self, String name) {
	if (self.filename.len) mem::free(self.filename.ptr);
	self.filename = name.copy(mem);
	self.selectFiletype();
}

fn void EditorCore.insertChar(&self, char c) {
	if (self.cy == self.numrows) self.insertRow(self.numrows, "");
	self.rows[self.cy].insertChar(self.cx, c);
	self.cx++;
	self.dirty++;
}

fn void EditorCore.insertCharSmart(&self, char c) {
	char next = self.charAtCursor();

	if (next == c && (c == ')' || c == ']' || c == '}' || c == '"' || c == '\'')) {
		self.cx++;
		return;
	}

	self.insertChar(c);

	switch (c) {
		case '(': self.insertChar(')'); self.cx--;
		case '[': self.insertChar(']'); self.cx--;
		case '{': self.insertChar('}'); self.cx--;
		case '"': self.insertChar('"'); self.cx--;
		case '\'': self.insertChar('\''); self.cx--;
		default: break;
	}
}

fn void EditorCore.insertTab(&self) {
	if (self.ft.use_spaces) {
		for (int i = 0; i < self.ft.tab_width; i++) self.insertChar(' ');
	} else {
		self.insertChar('\t');
	}
}

fn void EditorCore.insertNewline(&self) => @pool() {
	if (self.cy == self.numrows || self.cx == 0) {
		self.insertRow(self.cy, "");
		self.cy++;
		self.cx = 0;
		return;
	}

	String cur     = self.rows[self.cy].chars;
	String trimmed = cur.trim_right(" \t");
	bool deeper    = trimmed.len && (trimmed[trimmed.len - 1] == '{' || trimmed[trimmed.len - 1] == ':');

	DString s = dstring::temp_with_capacity(64);
	s.append(leadingWhitespace(cur));
	if (deeper) {
		if (self.ft.use_spaces) {
			s.append_repeat(' ', self.ft.tab_width);
		} else {
			s.append("\t");
		}
	}
	int indent_len = (int)s.len();
	if (self.cx < cur.len) s.append(cur[self.cx..]);

	self.insertRow(self.cy + 1, s.str_view());

	Erow* row   = &self.rows[self.cy];
	String head = row.chars[:self.cx].copy(mem);
	mem::free(row.chars.ptr);
	row.chars = head;

	self.cy++;
	self.cx = indent_len;
}

fn void EditorCore.delChar(&self) {
	if (self.cy == self.numrows) return;
	if (self.cx == 0 && self.cy == 0) return;

	if (self.cx > 0) {
		self.rows[self.cy].delChar(self.cx - 1);
		self.cx--;
	} else {
		self.cx = (int)self.rows[(sz)self.cy - 1].chars.len;
		self.rows[(sz)self.cy - 1].appendString(self.rows[self.cy].chars);
		self.delRow(self.cy);
		self.cy--;
	}
	self.dirty++;
}

// ---------- cursor ----------

fn void EditorCore.clampCursor(&self) {
	if (self.cy > self.numrows) self.cy = self.numrows;
	if (self.cy < 0) self.cy = 0;
	int rowlen = (self.cy >= self.numrows) ? 0 : (int)self.rows[self.cy].chars.len;
	if (self.cx > rowlen) self.cx = rowlen;
	if (self.cx < 0) self.cx = 0;
}

fn void EditorCore.moveCursor(&self, Direction dir) {
	Erow* row = (self.cy >= self.numrows) ? null : &self.rows[self.cy];
	switch (dir) {
		case LEFT:
			if (self.cx != 0) {
				self.cx--;
			} else if (self.cy > 0) {
				self.cy--;
				self.cx = (int)self.rows[self.cy].chars.len;
			}
		case RIGHT:
			if (row && self.cx < row.chars.len) {
				self.cx++;
			} else if (row && self.cx == row.chars.len) {
				self.cy++;
				self.cx = 0;
			}
		case UP: if (self.cy != 0) self.cy--;
		case DOWN: if (self.cy < self.numrows) self.cy++;
	}
	self.clampCursor();
}

fn void EditorCore.setCursorLine(&self, int line) {
	self.cy = line;
	self.clampCursor();
}

fn void EditorCore.cursorLineStart(&self) {
	self.cx = 0;
}

fn void EditorCore.cursorLineEnd(&self) {
	if (self.cy < self.numrows) self.cx = (int)self.rows[self.cy].chars.len;
}

// ---------- filetype ----------

fn void EditorCore.selectFiletype(&self) {
	self.ft = (Filetype) { .name = "", .use_spaces = false, .tab_width = 8 };

	if (self.filename.ends_with(".py")) {
		self.ft = (Filetype) { .name = "python", .use_spaces = true, .tab_width = 4 };
	} else if (self.filename.ends_with(".c3") || self.filename.ends_with(".c3i")) {
		self.ft = (Filetype) { .name = "c3", .use_spaces = false, .tab_width = 4 };
	} else if (self.filename.ends_with(".c") || self.filename.ends_with(".h")) {
		self.ft = (Filetype) { .name = "c", .use_spaces = true, .tab_width = 4 };
	}
}

// ---------- file i/o ----------

fn void EditorCore.init(&self) {
	self.rows.init(mem);
	self.numrows = 0;
	self.cx = 0;
	self.cy = 0;
	self.dirty = 0;
	self.filename = "";
	self.ft = (Filetype) { .name = "", .use_spaces = false, .tab_width = 8 };
}

fn void EditorCore.free(&self) {
	foreach (&row : self.rows) row.free();
	self.rows.free();
	if (self.filename.len) mem::free(self.filename.ptr);
}

fn void EditorCore.open(&self, String filename) => @pool() {
	self.filename = filename.copy(mem);
	self.selectFiletype();

	if (try fp = file::open(filename, "r")) {
		defer (void)fp.close();
		while (try line = io::treadline(&fp)) {
			self.insertRow(self.numrows, line.trim_right("\r\n"));
		}
	}
	self.dirty = 0;
}

fn String EditorCore.toString(&self) {
	DString buf = dstring::new_with_capacity(mem, 1024);
	defer buf.free();

	foreach (row : self.rows) {
		buf.append(row.chars);
		buf.append("\n");
	}
	return buf.str_view().copy(mem);
}

fn usz? EditorCore.save(&self) {
	String data = self.toString();
	defer mem::free(data.ptr);

	File fd = file::open(self.filename, "w")!;
	defer (void)fd.close();
	usz n = (usz)fd.write(data)!;
	self.dirty = 0;
	return n;
}
