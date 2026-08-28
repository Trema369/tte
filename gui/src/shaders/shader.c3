module shader;

import std::io, std::io::file;

fn String load(String filename) {
	String? content = (String)file::load_temp(filename);

	if (catch err = content) {
		io::printfn("Error opening file: %s", filename);
		return "";
	}

	return content;
}
