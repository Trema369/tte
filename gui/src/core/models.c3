module core::models;

import std::collections::list;
import std::time;

struct EditorCore {
	List{Erow} rows;
	int numrows;
	int cx, cy;
	int dirty;
	String filename;
	Filetype ft;
}

struct Erow {
	String chars;
	String render;
}

struct Filetype {
	String name;
	bool use_spaces;
	int tab_width;
}
