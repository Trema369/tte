module tte;

import std::io, std::os;
import libc::termios;
import std::collections::list;
import std::time;

const String TTE_VERSION = "0.0.1";
const int TTE_TAB_STOP   = 8;
const int TTE_QUIT_TIMES = 3;
const CInt SIGWINCH      = 28;

bool resize_pending;

constdef EditorKey : inline int {
	BACKSPACE  = 127,
	ARROW_LEFT = 1000,
	ARROW_RIGHT,
	ARROW_UP,
	ARROW_DOWN,
	HOME_KEY,
	END_KEY,
	DEL_KEY,
	PAGE_UP,
	PAGE_DOWN
}

alias Ek = EditorKey;

struct Erow {
	String chars;
	String render;
}

struct Filetype {
	String name;
	bool use_spaces;
	int tab_width;
}

Filetype ft;

struct EditorConfig {
	int cx, cy;
	int rx;
	int rowoff;
	int coloff;
	int screenrows;
	int screencols;
	int numrows;
	List{Erow} rows;
	int dirty;
	String filename;
	String statusmsg;
	Time statusmsg_time;
	Termios orig_termios;
}

struct Winsize {
	ushort ws_row;
	ushort ws_col;
	ushort ws_xpixel;
	ushort ws_ypixel;
}

const ulong TIOCGWINSZ = 0x5413;

EditorConfig e;

const usz VMIN  = 6;
const usz VTIME = 5;

macro char ctrl_key(k) => k & 0x1f;

fn void die(String message) {
	io::print("\x1b[2J");
	io::print("\x1b[H");
	io::eprintfn("%s", message);
	os::exit(1);
}

fn void handleSigwinch(CInt sig) {
	resize_pending = true;
}


fn void editorSelectFiletype() {
	ft = (Filetype) { .name = "", .use_spaces = false, .tab_width = 8 };

	if (e.filename.ends_with(".py")) {
		ft = (Filetype) { .name = "python", .use_spaces = true, .tab_width = 4 };
	} else if (e.filename.ends_with(".c3") || e.filename.ends_with(".c3i")) {
		ft = (Filetype) { .name = "c3", .use_spaces = false, .tab_width = 4 };
	} else if (e.filename.ends_with(".c") || e.filename.ends_with(".h")) {
		ft = (Filetype) { .name = "c", .use_spaces = true, .tab_width = 4 };
	}
}

fn void editorUpdateWindowSize() {
	int rows, cols;
	if (getWindowSize(&rows, &cols) == -1) die("getWindowSize");
	e.screenrows = rows - 2;
	e.screencols = cols;
	if (e.cy >= e.numrows) e.cy = e.numrows;
}

fn void initEditor() {
	e.cx = 0;
	e.cy = 0;
	e.rx = 0;
	e.rowoff = 0;
	e.coloff = 0;
	e.numrows = 0;
	e.rows.init(mem);
	e.dirty = 0;
	e.statusmsg = "";
	e.statusmsg_time = (Time)0;
	e.filename = "";
	ft = (Filetype) { .name = "", .use_spaces = false, .tab_width = 8 };
	editorUpdateWindowSize();
	libc::signal(SIGWINCH, &handleSigwinch);
}

fn void enableRawMode() @init {
	e.orig_termios.get_attr(0);
	Termios raw = e.orig_termios;
	raw.c_lflag.echo = false;
	raw.c_lflag.icanon = false;
	raw.c_lflag.isig = false;
	raw.c_lflag.iexten = false;
	raw.c_iflag.ixon = false;
	raw.c_iflag.icrnl = false;
	raw.c_oflag.opost = false;
	raw.c_iflag.brkint = false;
	raw.c_iflag.istrip = false;
	raw.c_iflag.inpck = false;
	raw.c_cc[VMIN] = (Cc)0;
	raw.c_cc[VTIME] = (Cc)1;
	raw.set_attr(0, Tcactions.TCSAFLUSH);
	initEditor();
}

fn void disableRawMode() @finalizer {
	e.orig_termios.set_attr(0, Tcactions.TCSAFLUSH);
}

fn void editorOpen(String filename) => @pool() {
	e.filename = filename.copy(mem);
	editorSelectFiletype();
	if (try fp = file::open(filename, "r")) {
		defer (void)fp.close();

		while (try line = io::treadline(&fp)) {
			String trimmed = line.trim_right("\r\n");
			editorInsertRow(e.numrows, trimmed);
		}
	}
	e.dirty = 0;
}

fn char editorCharAtCursor() {
	if (e.cy >= e.numrows) return 0;
	Erow* row = &e.rows[e.cy];
	if (e.cx >= row.chars.len) return 0;
	return row.chars[e.cx];
}

fn void editorInsertCharSmart(int c) {
	char next = editorCharAtCursor();

	if (next == (char)c && (c == ')' || c == ']' || c == '}' || c == '"' || c == '\'')) {
		e.cx++;
		return;
	}

	editorInsertChar(c);

	switch (c) {
		case '(': editorInsertChar(')'); e.cx--;
		case '[': editorInsertChar(']'); e.cx--;
		case '{': editorInsertChar('}'); e.cx--;
		case '"': editorInsertChar('"'); e.cx--;
		case '\'': editorInsertChar('\''); e.cx--;
		default: break;
	}
}

fn void editorInsertRow(int at, String value) {
	if (at < 0 || at > e.numrows) return;

	e.rows.insert_at(at, (Erow) { .chars = value.copy(mem) });
	editorUpdateRow(&e.rows[at]);
	e.numrows++;
	e.dirty++;
}
fn void editorInsertNewline() => @pool() {
	if (e.cx == 0 || e.cy == e.numrows) {
		editorInsertRow(e.cy, "");
		e.cy++;
		e.cx = 0;
		return;
	}

	String cur     = e.rows[e.cy].chars;
	String trimmed = cur.trim_right(" \t");
	bool deeper    = trimmed.len && (trimmed[trimmed.len - 1] == '{' || trimmed[trimmed.len - 1] == ':');

	DString s = dstring::temp_with_capacity(64);
	s.append(editorLeadingWhitespace(cur));
	if (deeper) {
		if (ft.use_spaces) {
			s.append_repeat(' ', ft.tab_width);
		} else {
			s.append("\t");
		}
	}
	int indent_len = (int)s.len();
	if (e.cx < cur.len) s.append(cur[e.cx..]);

	editorInsertRow(e.cy + 1, s.str_view());

	Erow* row   = &e.rows[e.cy];
	String head = row.chars[:e.cx].copy(mem);
	mem::free(row.chars.ptr);
	row.chars = head;
	editorUpdateRow(row);

	e.cy++;
	e.cx = indent_len;
}

fn void editorRowInsertChar(Erow* row, int at, int c) => @pool() {
	if (at < 0 || at > row.chars.len) at = (int)row.chars.len;

	DString s = dstring::temp_with_capacity(row.chars.len + 2);
	s.append(row.chars[:at]);
	s.append(c);
	if (at < row.chars.len) s.append(row.chars[at..]);

	mem::free(row.chars.ptr);
	row.chars = s.str_view().copy(mem);
	editorUpdateRow(row);
	e.dirty++;
}

fn void editorInsertChar(int c) {
	if (e.cy == e.numrows) {
		editorInsertRow(e.numrows, "");
	}
	editorRowInsertChar(&e.rows[e.cy], e.cx, c);
	e.cx++;
}

fn void editorRowDelChar(Erow* row, int at) => @pool() {
	if (at < 0 || at >= row.chars.len) return;

	DString s = dstring::temp_with_capacity(row.chars.len);
	s.append(row.chars[:at]);
	if (at + 1 < (int)row.chars.len) {
		s.append(row.chars[at + 1..]);
	}

	mem::free(row.chars.ptr);
	row.chars = s.str_view().copy(mem);
	editorUpdateRow(row);
}

fn void editorDelChar() {
	if (e.cy == e.numrows) return;
	if (e.cx == 0 && e.cy == 0) return;

	if (e.cx > 0) {
		editorRowDelChar(&e.rows[e.cy], e.cx - 1);
		e.cx--;
	} else {
		e.cx = (int)e.rows[(sz)e.cy - 1].chars.len;
		editorRowAppendString(&e.rows[(sz)e.cy - 1], e.rows[e.cy].chars);
		editorDelRow(e.cy);
		e.cy--;
	}
}

fn void editorFreeRow(Erow* row) {
	if (row.chars.ptr) mem::free(row.chars.ptr);
	if (row.render.ptr) mem::free(row.render.ptr);
}

fn void editorDelRow(int at) {
	if (at < 0 || at >= e.numrows) return;
	editorFreeRow(&e.rows[at]);
	e.rows.remove_at(at);
	e.numrows--;
	e.dirty++;
}

fn void editorRowAppendString(Erow* row, String s) => @pool() {
	DString buf = dstring::temp_with_capacity(row.chars.len + s.len);
	buf.append(row.chars);
	buf.append(s);

	mem::free(row.chars.ptr);
	row.chars = buf.str_view().copy(mem);
	editorUpdateRow(row);
	e.dirty++;
}

fn void editorDrawStatusBar(DString* buf) {
	buf.append("\x1b[7m");
	String name = e.filename.len ? e.filename : "[No Name]";
	if (name.len > 20) name = name[..19];

	String status  = string::tformat("%s - %d lines %s", name, e.numrows, e.dirty ? "(modified)" : "");
	String rstatus = string::tformat("%d/%d", e.cy + 1, e.numrows);
	if (status.len > e.screencols) status = status[..e.screencols - 1];
	buf.append(status);
	int len = (int)status.len;
	while (len < e.screencols) {
		if (e.screencols - (long)len == rstatus.len) {
			buf.append(rstatus);
			break;
		} else {
			buf.append(" ");
			len++;
		}
	}
	buf.append("\x1b[m");
	buf.append("\r\n");
}

fn void editorAppendRow(String value) {
	int at = e.numrows;
	e.rows.push((Erow) { .chars = value.copy(mem) });
	editorUpdateRow(&e.rows[at]);
	e.numrows++;
	e.dirty++;
}

fn void editorSetStatusMessage(String fmt, args...) {
	if (e.statusmsg.len) mem::free(e.statusmsg.ptr);
	e.statusmsg = string::format(mem, fmt, ...args);
	e.statusmsg_time = time::now();
}

fn void editorDrawMessageBar(DString* buf) {
	buf.append("\x1b[K");
	String msg = e.statusmsg;
	if (msg.len > e.screencols) msg = msg[..e.screencols - 1];
	if (msg.len && time::now().diff_sec(e.statusmsg_time) < 5) {
		buf.append(msg);
	}
}

fn void editorUpdateRow(Erow* row) => @pool() {
	if (row.render.ptr) mem::free(row.render.ptr);

	DString rendered = dstring::temp_with_capacity(row.chars.len + 16);
	foreach (c : row.chars) {
		if (c == '\t') {
			rendered.append(" ");
			while (rendered.len() % ft.tab_width != 0) rendered.append(" ");
		} else {
			rendered.append(c);
		}
	}
	row.render = rendered.str_view().copy(mem);
}

fn int editorReadKey() {
	sz nread;
	char c;
	while ((nread = libc::read(0, &c, 1)) != 1) {
		if (nread == -1) die("read");
		if (resize_pending) return '\x1b';
	}

	if (c == '\x1b') {
		char[3] seq;

		if (libc::read(0, &seq[0], 1) != 1) return '\x1b';
		if (libc::read(0, &seq[1], 1) != 1) return '\x1b';

		if (seq[0] == '[') {
			if (seq[1] >= '0' && seq[1] <= '9') {
				if (libc::read(0, &seq[2], 1) != 1) return '\x1b';
				if (seq[2] == '~') {
					switch (seq[1]) {
						case '1': return Ek.HOME_KEY;
						case '3': return Ek.DEL_KEY;
						case '4': return Ek.END_KEY;
						case '5': return Ek.PAGE_UP;
						case '6': return Ek.PAGE_DOWN;
						case '7': return Ek.HOME_KEY;
						case '8': return Ek.END_KEY;
					}
				}
			} else {
				switch (seq[1]) {
					case 'A': return Ek.ARROW_UP;
					case 'B': return Ek.ARROW_DOWN;
					case 'C': return Ek.ARROW_RIGHT;
					case 'D': return Ek.ARROW_LEFT;
					case 'H': return Ek.HOME_KEY;
					case 'F': return Ek.END_KEY;
				}
			}
		} else if (seq[0] == 'O') {
			switch (seq[1]) {
				case 'H': return Ek.HOME_KEY;
				case 'F': return Ek.END_KEY;
			}
		}
		return '\x1b';
	} else {
		return c;
	}
}

fn String editorRowsToString() => @pool() {
	DString buf = dstring::new_with_capacity(mem, 1024);
	defer buf.free();

	foreach (row : e.rows) {
		buf.append(row.chars);
		buf.append("\n");
	}
	return buf.str_view().copy(mem);
}

fn String editorLeadingWhitespace(String s) {
	usz i = 0;
	while (i < s.len && (s[i] == ' ' || s[i] == '\t')) i++;
	return s[:i];
}

fn void editorSave() {
	if (e.filename.len == 0) return;

	String rows = editorRowsToString();
	defer mem::free(rows.ptr);

	if (try fd = file::open(e.filename, "w")) {
		defer (void)fd.close();
		if (try n = fd.write(rows)) {
			e.dirty = 0;
			editorSetStatusMessage("%d bytes written to disk", n);
			return;
		}
	}
	editorSetStatusMessage("Can't save! I/O error");
}
fn void editorProcessKeypress() {
	static int quit_times = TTE_QUIT_TIMES;
	int c                 = editorReadKey();
	switch (c) {
		case '\r':
			editorInsertNewline();
			break;
		case ctrl_key('q'):
			if (e.dirty && quit_times > 0) {
				editorSetStatusMessage(
					"WARNING!!! File has unsaved changes. " "Press Ctrl-Q %d more times to quit.",
					quit_times
				);
				quit_times--;
				return;
			}
			io::print("\x1b[2J");
			io::print("\x1b[H");
			os::exit(0);
		case ctrl_key('s'):
			editorSave();
			break;
		case '\t':
			if (ft.use_spaces) {
				for (int i = 0; i < ft.tab_width; i++) editorInsertChar(' ');
			} else {
				editorInsertChar('\t');
			}
			break;
		case Ek.HOME_KEY:
			e.cx = 0;
			break;
		case Ek.END_KEY:
			if (e.cy < e.numrows) e.cx = e.rows[e.cy].render.len;
			break;
		case Ek.BACKSPACE:
		case ctrl_key('h'):
		case Ek.DEL_KEY:
			if (c == Ek.DEL_KEY) editorMoveCursor(Ek.ARROW_RIGHT);
			editorDelChar();
			break;
		case Ek.PAGE_UP:
		case Ek.PAGE_DOWN:

			{
				if (c == Ek.PAGE_UP) {
					e.cy = e.rowoff;
				} else if (c == Ek.PAGE_DOWN) {
					e.cy = e.rowoff + e.screenrows - 1;
					if (e.cy > e.numrows) e.cy = e.numrows;
				}
				int times = e.screenrows;
				while (times--) {
					editorMoveCursor(c == Ek.PAGE_UP ? Ek.ARROW_UP : Ek.ARROW_DOWN);
				}
			}
		case Ek.ARROW_LEFT:
			nextcase;
		case Ek.ARROW_RIGHT:
			nextcase;
		case Ek.ARROW_UP:
			nextcase;
		case Ek.ARROW_DOWN:
			editorMoveCursor(c);
			break;

		case ctrl_key('l'):
		case '\x1b':
			break;

		default:
			editorInsertCharSmart(c);
			break;
	}
	quit_times = TTE_QUIT_TIMES;
}

fn int editorRowCxToRx(Erow* row, int cx) {
	int rx = 0;
	int j;
	for (j = 0; j < cx; j++) {
		if (row.chars[j] == '\t') rx += (ft.tab_width - 1) - (rx % ft.tab_width);
		rx++;
	}
	return rx;
}

fn void editorRefreshScreen() {
	editorScroll();
	@pool() {
		DString buf = dstring::temp_with_capacity(1024);

		buf.append("\x1b[?25l");
		buf.append("\x1b[H");
		editorDrawRows(&buf);
		editorDrawStatusBar(&buf);
		editorDrawMessageBar(&buf);
		buf.appendf("\x1b[%d;%dH", (e.cy - e.rowoff) + 1, (e.rx - e.coloff) + 1);
		buf.append("\x1b[?25h");

		io::print(buf.str_view());
	};
	io::stdout().flush()!!;
}

fn void editorDrawRows(DString* buf) {
	int y;
	for (y = 0; y < e.screenrows; y++) {
		buf.append("\x1b[K");
		int filerow = y + e.rowoff;
		if (filerow >= e.numrows) {
			if (e.numrows == 0 && y == e.screenrows / 3) {
				String welcome = string::tformat("tte editor --version %s", TTE_VERSION);
				if (welcome.len > e.screencols) welcome = welcome[..e.screencols - 1];
				int padding = (e.screencols - welcome.len) / 2;
				if (padding) {
					buf.append("~");
					padding--;
				}
				while (padding--) buf.append(" ");
				buf.append(welcome);
			} else {
				buf.append("~");
			}
		} else {
			String row = e.rows[filerow].render;
			if (e.coloff < row.len) {
				String visible = row[e.coloff..];
				if (visible.len > e.screencols) visible = visible[..e.screencols - 1];
				buf.append(visible);
			}
		}
		buf.append("\r\n");
	}
}
fn void editorScroll() {
	e.rx = 0;
	if (e.cy < e.numrows) {
		e.rx = editorRowCxToRx(&e.rows[e.cy], e.cx);
	}
	if (e.cy < e.rowoff) {
		e.rowoff = e.cy;
	}
	if (e.cy >= e.rowoff + e.screenrows) {
		e.rowoff = e.cy - e.screenrows + 1;
	}
	if (e.rx < e.coloff) e.coloff = e.rx;
	if (e.rx >= e.coloff + e.screencols) e.coloff = e.rx - e.screencols + 1;
}
fn int getWindowSize(int* rows, int* cols) {
	Winsize ws;
	if (libc::ioctl(1, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
		if (libc::write(0, "\x1b[999C\x1b[999B", 12) != 12) return -1;
		return getCursorPosition(rows, cols);
	} else {
		*cols = ws.ws_col;
		*rows = ws.ws_row;
		return 0;
	}
}

fn int getCursorPosition(int* rows, int* cols) {
	char[32] buf;
	uint i = 0;

	if (libc::write(0, "\x1b[6n", 4) != 4) return -1;

	while (i < buf.len - 1) {
		if (libc::read(0, &buf[i], 1) != 1) break;
		if (buf[i] == 'R') break;
		i++;
	}
	buf[i] = '\0';

	if (buf[0] != '\x1b' || buf[1] != '[') return -1;
	if (libc::sscanf(&buf[2], "%d;%d", rows, cols) != 2) return -1;
	return 0;
}

fn void editorMoveCursor(int key) {
	Erow* row = (e.cy >= e.numrows) ? null : &e.rows[e.cy];
	switch (key) {
		case Ek.ARROW_LEFT:
			if (e.cx != 0) {
				e.cx--;
			} else if (e.cy > 0) {
				e.cy--;
				e.cx = e.rows[e.cy].chars.len;
			}
			break;

		case Ek.ARROW_RIGHT:
			if (row && e.cx < row.chars.len) {
				e.cx++;
			} else if (row && e.cx == row.chars.len) {
				e.cy++;
				e.cx = 0;
			}
			break;

		case Ek.ARROW_DOWN: if (e.cy < e.numrows) e.cy++; break;

		case Ek.ARROW_UP: if (e.cy != 0) e.cy--; break;
	}

	row = (e.cy >= e.numrows) ? null : &e.rows[e.cy];
	int rowlen = row ? (int)row.chars.len : 0;
	if (e.cx > rowlen) e.cx = rowlen;
}

fn int main(String[] args) {
	if (args.len >= 2) editorOpen(args[1]);
	defer e.rows.free();
	editorSetStatusMessage("HELP: Ctrl-Q = quit");
	while (1) {
		if (resize_pending) {
			resize_pending = false;
			editorUpdateWindowSize();
		}
		editorRefreshScreen();
		editorProcessKeypress();
	}
}
