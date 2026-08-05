module tte::term @if(env::ANDROID);

bitstruct Tc_iflags : CUInt {
	bool brkint : 1;
	bool inpck : 4;
	bool istrip : 5;
	bool icrnl : 8;
	bool ixon : 10;
}
bitstruct Tc_oflags : CUInt {
	bool opost : 0;
}
bitstruct Tc_cflags : CUInt {
	uint csize : 4..5;
}
bitstruct Tc_lflags : CUInt {
	bool isig : 0;
	bool icanon : 1;
	bool echo : 3;
	bool iexten : 15;
}

struct TermAttrs {
	Tc_iflags c_iflag;
	Tc_oflags c_oflag;
	Tc_cflags c_cflag;
	Tc_lflags c_lflag;
	Cc c_line;
	Cc[64] c_cc;
}

const CInt TCSAFLUSH = 2;
const usz VMIN       = 6;
const usz VTIME      = 5;

extern fn CInt tcgetattr(CInt fd, TermAttrs* p);
extern fn CInt tcsetattr(CInt fd, CInt actions, TermAttrs* p);

fn CInt termGetAttrs(TermAttrs* t, CInt fd) => tcgetattr(fd, t);
fn CInt termSetAttrs(TermAttrs* t, CInt fd, CInt action) => tcsetattr(fd, action, t);


module tte::term @if(!env::ANDROID);

import libc::termios;

alias TermAttrs = libc::termios::Termios;

const CInt TCSAFLUSH = 2;
const usz VMIN       = 6;
const usz VTIME      = 5;

fn CInt termGetAttrs(TermAttrs* t, CInt fd) => t.get_attr((Fd)fd);
fn CInt termSetAttrs(TermAttrs* t, CInt fd, CInt action) => t.set_attr((Fd)fd, (Tcactions)action);
