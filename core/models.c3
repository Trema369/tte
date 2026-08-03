module core::models;

struct Erow {
	String chars;
	String render;
}

struct Filetype {
	String name;
	bool use_spaces;
	int tab_width;
}

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


