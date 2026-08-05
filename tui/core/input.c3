module core::input;

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

macro char ctrl_key(k) => k & 0x1f;

