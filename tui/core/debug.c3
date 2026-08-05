module core::debug;

import std::io;
import std::os;

fn void die(String message) {
	io::print("\x1b[2J");
	io::print("\x1b[H");
	io::eprintfn("%s", message);
	os::exit(1);
}
