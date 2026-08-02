module tte;

import std::io, std::os;
import libc::termios;

struct EditorConfig
{
	int screenrows;
	int screencols;
	Termios orig_termios;
}

struct Winsize
{
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

fn void die(String message)
{
	io::print("\x1b[2J");
	io::print("\x1b[H");
	io::eprintfn("%s", message);
	os::exit(1);
}

fn void initEditor()
{
	if (getWindowSize(&e.screenrows, &e.screencols) == -1) die("getWindowSize");
}

fn void enableRawMode() @init
{
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

fn void disableRawMode() @finalizer
{
	e.orig_termios.set_attr(0, Tcactions.TCSAFLUSH);
}

fn char editorReadKey()
{
	sz nread;
	char c;
	while ((nread = libc::read(0, &c, 1)) != 1)
	{
		if (nread == -1) die("read");
	}
	return c;
}

fn void editorProcessKeypress()
{
	char c = editorReadKey();
	switch (c)
	{
		case ctrl_key('q'):
			io::print("\x1b[2J");
			io::print("\x1b[H");
			os::exit(0);
	}
}

fn void editorRefreshScreen()
{
	io::print("\x1b[2J");
	io::print("\x1b[H");
	editorDrawRows();
	io::print("\x1b[H");
	io::stdout().flush()!!;
}

fn void editorDrawRows()
{
	int y;
	for (y = 0; y < e.screenrows; y++)
	{
		io::print("~");
		if (y < e.screenrows - 1)
		{
			io::print("\r\n");
		}
	}
}

fn int getWindowSize(int* rows, int* cols)
{
	Winsize ws;
	if (1 || libc::ioctl(1, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0)
	{
		if (libc::write(0, "\x1b[999C\x1b[999B", 12) != 12) return -1;
		return getCursorPosition(rows, cols);
	}
	else
	{
		*cols = ws.ws_col;
		*rows = ws.ws_row;
		return 0;
	}
}

fn int getCursorPosition(int* rows, int* cols)
{
	char[32] buf;
	uint i = 0;

	if (libc::write(0, "\x1b[6n", 4) != 4) return -1;

	while (i < buf.len - 1)
	{
		if (libc::read(0, &buf[i], 1) != 1) break;
		if (buf[i] == 'R') break;
		i++;
	}
	buf[i] = '\0';

	if (buf[0] != '\x1b' || buf[1] != '[') return -1;
	if (libc::sscanf(&buf[2], "%d;%d", rows, cols) != 2) return -1;
	return 0;
}

fn int main()
{
	while (1)
	{
		editorRefreshScreen();
		editorProcessKeypress();
	}
}
