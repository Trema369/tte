module tte::tui;

import std::io, std::os, std::time;
import libc;
import core::models, core::editor;
import tte::term;


const String VERSION = "0.0.1";
const int QUIT_TIMES = 3;
const CInt SIGWINCH  = 28;

constdef Key : inline int {
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

struct Winsize {
	ushort ws_row;
	ushort ws_col;
	ushort ws_xpixel;
	ushort ws_ypixel;
}

const ulong TIOCGWINSZ = 0x5413;
macro char ctrl_key(k) => k & 0x1f;


struct TuiState {
	EditorCore core;
	int rowoff, coloff;
	int screenrows, screencols;
	int rx;
	String statusmsg;
	Time statusmsg_time;
	TermAttrs orig_termios;
	bool raw_enabled;
}

TuiState tui;
bool resize_pending;


fn void die(String message) {
	io::print("\x1b[2J");
	io::print("\x1b[H");
	if (catch io::stdout().flush()) {
		/* ignore */
	}
	io::eprintfn("%s", message);
	os::exit(1);
}

fn void enableRawMode() {
	term::termGetAttrs(&tui.orig_termios, 0);
	TermAttrs raw = tui.orig_termios;

	raw.c_iflag.brkint = false;
	raw.c_iflag.icrnl = false;
	raw.c_iflag.inpck = false;
	raw.c_iflag.istrip = false;
	raw.c_iflag.ixon = false;
	raw.c_oflag.opost = false;
	raw.c_lflag.echo = false;
	raw.c_lflag.icanon = false;
	raw.c_lflag.iexten = false;
	raw.c_lflag.isig = false;

	raw.c_cc[term::VMIN] = (Cc)0;
	raw.c_cc[term::VTIME] = (Cc)1;

	term::termSetAttrs(&raw, 0, term::TCSAFLUSH);
	tui.raw_enabled = true;
}

fn void disableRawMode() @finalizer {
	if (!tui.raw_enabled) return;
	term::termSetAttrs(&tui.orig_termios, 0, term::TCSAFLUSH);
}

fn void handleSigwinch(CInt sig) {
	resize_pending = true;
}


fn int getWindowSize(int* rows, int* cols) {
	Winsize ws;
	if (libc::ioctl(1, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
		if (libc::write(1, "\x1b[999C\x1b[999B", 12) != 12) return -1;
		return getCursorPosition(rows, cols);
	}
	*cols = ws.ws_col;
	*rows = ws.ws_row;
	return 0;
}

fn int getCursorPosition(int* rows, int* cols) {
	char[32] buf;
	uint i = 0;

	if (libc::write(1, "\x1b[6n", 4) != 4) return -1;

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

fn void updateWindowSize() {
	int rows, cols;
	if (getWindowSize(&rows, &cols) == -1) die("getWindowSize");
	tui.screenrows = rows - 2; // status bar + message bar
	tui.screencols = cols;
	tui.core.clampCursor();
}

fn String renderLine(String chars) {
	int w     = tui.core.ft.tab_width;
	DString s = dstring::temp_with_capacity(chars.len + 16);
	foreach (c : chars) {
		if (c == '\t') {
			s.append(" ");
			while (s.len() % w != 0) s.append(" ");
		} else {
			s.append(c);
		}
	}
	return s.str_view();
}

fn int cxToRx(String chars, int cx) {
	int w  = tui.core.ft.tab_width;
	int rx = 0;
	for (int j = 0; j < cx; j++) {
		if (chars[j] == '\t') rx += (w - 1) - (rx % w);
		rx++;
	}
	return rx;
}


fn void scroll() {
	tui.rx = 0;
	if (tui.core.cy < tui.core.numrows) {
		tui.rx = cxToRx(tui.core.rows[tui.core.cy].chars, tui.core.cx);
	}

	if (tui.core.cy < tui.rowoff) {
		tui.rowoff = tui.core.cy;
	}
	if (tui.core.cy >= tui.rowoff + tui.screenrows) {
		tui.rowoff = tui.core.cy - tui.screenrows + 1;
	}
	if (tui.rx < tui.coloff) {
		tui.coloff = tui.rx;
	}
	if (tui.rx >= tui.coloff + tui.screencols) {
		tui.coloff = tui.rx - tui.screencols + 1;
	}
}


fn void drawRows(DString* buf) {
	for (int y = 0; y < tui.screenrows; y++) {
		buf.append("\x1b[K");
		int filerow = y + tui.rowoff;

		if (filerow >= tui.core.numrows) {
			if (tui.core.numrows == 0 && y == tui.screenrows / 3) {
				String welcome = string::tformat("tte editor -- version %s", VERSION);
				if (welcome.len > tui.screencols) welcome = welcome[..tui.screencols - 1];

				int padding = (int)(tui.screencols - welcome.len) / 2;
				if (padding > 0) {
					buf.append("~");
					padding--;
				}
				while (padding > 0) {
					buf.append(" ");
					padding--;
				}
				buf.append(welcome);
			} else {
				buf.append("~");
			}
		} else {
			String line = renderLine(tui.core.rows[filerow].chars);
			if (tui.coloff < line.len) {
				String visible = line[tui.coloff..];
				if (visible.len > tui.screencols) visible = visible[..tui.screencols - 1];
				buf.append(visible);
			}
		}
		buf.append("\r\n");
	}
}

fn String prompt(String fmt) {
	char[256] buf;
	usz len = 0;

	while (true) {
		setStatusMessage(fmt, (String)buf[:len]);
		refreshScreen();

		int c = readKey();

		if (c == Key.DEL_KEY || c == ctrl_key('h') || c == Key.BACKSPACE) {
			if (len > 0) len--;
		} else if (c == '\x1b') {
			setStatusMessage("");
			return "";
		} else if (c == '\r') {
			if (len > 0) {
				setStatusMessage("");
				return ((String)buf[:len]).copy(mem);
			}
		} else if (c < 128 && !((char)c).is_cntrl() && len < buf.len - 1) {
			buf[len] = (char)c;
			len++;
		}
	}
}

fn void drawStatusBar(DString* buf) {
	buf.append("\x1b[7m");

	String name = tui.core.filename.len ? tui.core.filename : "[No Name]";
	if (name.len > 20) name = name[..19];

	String status  = string::tformat("%s - %d lines %s", name, tui.core.numrows, tui.core.dirty ? "(modified)" : "");
	String rstatus = string::tformat("%d/%d", tui.core.cy + 1, tui.core.numrows);

	if (status.len > tui.screencols) status = status[..tui.screencols - 1];
	buf.append(status);

	int len = (int)status.len;
	while (len < tui.screencols) {
		if (tui.screencols - len == (int)rstatus.len) {
			buf.append(rstatus);
			break;
		}
		buf.append(" ");
		len++;
	}

	buf.append("\x1b[m");
	buf.append("\r\n");
}

fn void drawMessageBar(DString* buf) {
	buf.append("\x1b[K");
	String msg = tui.statusmsg;
	if (msg.len > tui.screencols) msg = msg[..tui.screencols - 1];
	if (msg.len && time::now().diff_sec(tui.statusmsg_time) < 5) {
		buf.append(msg);
	}
}

fn void refreshScreen() {
	scroll();
	@pool() {
		DString buf = dstring::temp_with_capacity(1024);

		buf.append("\x1b[?25l");
		buf.append("\x1b[H");

		drawRows(&buf);
		drawStatusBar(&buf);
		drawMessageBar(&buf);

		buf.appendf("\x1b[%d;%dH", (tui.core.cy - tui.rowoff) + 1, (tui.rx - tui.coloff) + 1);
		buf.append("\x1b[?25h");

		io::print(buf.str_view());
	};
	if (catch io::stdout().flush()) {
		/* ignore */
	}
}

fn void setStatusMessage(String fmt, args...) {
	if (tui.statusmsg.len) mem::free(tui.statusmsg.ptr);
	tui.statusmsg = string::format(mem, fmt, ...args);
	tui.statusmsg_time = time::now();
}


fn int readKey() {
	sz nread;
	char c;

	while ((nread = libc::read(0, &c, 1)) != 1) {
		if (nread == -1) die("read");
		if (resize_pending) return '\x1b';
	}

	if (c != '\x1b') return c;

	char[3] seq;
	if (libc::read(0, &seq[0], 1) != 1) return '\x1b';
	if (libc::read(0, &seq[1], 1) != 1) return '\x1b';

	if (seq[0] == '[') {
		if (seq[1] >= '0' && seq[1] <= '9') {
			if (libc::read(0, &seq[2], 1) != 1) return '\x1b';
			if (seq[2] == '~') {
				switch (seq[1]) {
					case '1': return Key.HOME_KEY;
					case '3': return Key.DEL_KEY;
					case '4': return Key.END_KEY;
					case '5': return Key.PAGE_UP;
					case '6': return Key.PAGE_DOWN;
					case '7': return Key.HOME_KEY;
					case '8': return Key.END_KEY;
				}
			}
		} else {
			switch (seq[1]) {
				case 'A': return Key.ARROW_UP;
				case 'B': return Key.ARROW_DOWN;
				case 'C': return Key.ARROW_RIGHT;
				case 'D': return Key.ARROW_LEFT;
				case 'H': return Key.HOME_KEY;
				case 'F': return Key.END_KEY;
			}
		}
	} else if (seq[0] == 'O') {
		switch (seq[1]) {
			case 'H': return Key.HOME_KEY;
			case 'F': return Key.END_KEY;
		}
	}
	return '\x1b';
}

fn bool processKeypress() {
	static int quit_times = QUIT_TIMES;

	int c = readKey();

	switch (c) {
		case '\r':
			tui.core.insertNewline();

		case '\t':
			tui.core.insertTab();

		case ctrl_key('q'):
			if (tui.core.dirty && quit_times > 0) {
				setStatusMessage(
					"WARNING!!! File has unsaved changes. Press Ctrl-Q %d more times to quit.",
					quit_times
				);
				quit_times--;
				return true;
			}
			io::print("\x1b[2J");
			io::print("\x1b[H");
			if (catch io::stdout().flush()) {
				/* ignore */
			}
			return false;

		case ctrl_key('s'):
			if (tui.core.filename.len == 0) {
				String name = prompt("Save as: %s (ESC to cancel)");
				if (name.len == 0) {
					setStatusMessage("Save aborted");
					return true;
				}
				tui.core.setFilename(name);
				mem::free(name.ptr);
			}
			if (try n = tui.core.save()) {
				setStatusMessage("%d bytes written to disk", n);
			} else {
				setStatusMessage("Can't save! I/O error");
			}

		case Key.HOME_KEY:
			tui.core.cursorLineStart();

		case Key.END_KEY:
			tui.core.cursorLineEnd();

		case Key.BACKSPACE:
		case ctrl_key('h'):
		case Key.DEL_KEY:
			if (c == Key.DEL_KEY) tui.core.moveCursor(Direction.RIGHT);
			tui.core.delChar();

		case Key.PAGE_UP:
			tui.core.setCursorLine(tui.rowoff);
			for (int i = 0; i < tui.screenrows; i++) tui.core.moveCursor(Direction.UP);

		case Key.PAGE_DOWN:
			tui.core.setCursorLine(tui.rowoff + tui.screenrows - 1);
			for (int i = 0; i < tui.screenrows; i++) tui.core.moveCursor(Direction.DOWN);

		case Key.ARROW_LEFT:
			tui.core.moveCursor(Direction.LEFT);

		case Key.ARROW_RIGHT:
			tui.core.moveCursor(Direction.RIGHT);

		case Key.ARROW_UP:
			tui.core.moveCursor(Direction.UP);

		case Key.ARROW_DOWN:
			tui.core.moveCursor(Direction.DOWN);

		case ctrl_key('l'):
		case '\x1b':
			break;

		default:
			tui.core.insertCharSmart((char)c);
	}

	quit_times = QUIT_TIMES;
	return true;
}


fn int run(String[] args) {
	tui.core.init();
	tui.statusmsg = "";
	defer tui.core.free();

	enableRawMode();
	updateWindowSize();
	libc::signal(SIGWINCH, &handleSigwinch);

	if (args.len >= 2) tui.core.open(args[1]);

	setStatusMessage("HELP: Ctrl-S = save | Ctrl-Q = quit");

	while (true) {
		if (resize_pending) {
			resize_pending = false;
			updateWindowSize();
		}
		refreshScreen();
		if (!processKeypress()) break;
	}
	return 0;
}
