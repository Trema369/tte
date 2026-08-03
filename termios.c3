module tte;

alias Cc = char;

bitstruct Tc_iflags : CUInt {
	bool brkint : 1;
	bool inpck  : 4;
	bool istrip : 5;
	bool icrnl  : 8;
	bool ixon   : 10;
}
bitstruct Tc_oflags : CUInt {
	bool opost : 0;
}
bitstruct Tc_cflags : CUInt {
	uint csize : 4..5;
}
bitstruct Tc_lflags : CUInt {
	bool isig   : 0;
	bool icanon : 1;
	bool echo   : 3;
	bool iexten : 15;
}

struct Termios {
	Tc_iflags c_iflag;
	Tc_oflags c_oflag;
	Tc_cflags c_cflag;
	Tc_lflags c_lflag;
	Cc        c_line;
	Cc[64]    c_cc;      // deliberately oversized — see below
}

constdef Tcactions : inline CInt {
	TCSANOW   = 0,
	TCSADRAIN = 1,
	TCSAFLUSH = 2
}

extern fn CInt tcgetattr(CInt fd, Termios* p);
extern fn CInt tcsetattr(CInt fd, CInt optional_actions, Termios* p);

fn CInt Termios.get_attr(&self, CInt fd)              => tcgetattr(fd, self);
fn CInt Termios.set_attr(&self, CInt fd, CInt action) => tcsetattr(fd, action, self);
