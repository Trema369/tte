module highlight;

import std::io;
import std::collections::list;
import ts;
import core;

const char[*] C3_QUERY = $embed("../vendor/ts-c3/queries/highlights.scm");

struct Span {
	int row;
	int col0, col1;
	int colour;
}

const int MAX_ROWS = 4096;
const int MAX_COLS = 512;

char[MAX_COLS][MAX_ROWS] colours;   // palette index per cell
List{Span} spans;
int used_rows;
void* parser;
void* tree;
int last_dirty = -1;
void* query;
void* cursor;

fn void init() {
	parser = ts::parser_new();
	ts::parser_set_language(parser, ts::tree_sitter_c3());

	uint err_off;
	int  err_type;
	query = ts::query_new(ts::tree_sitter_c3(), &C3_QUERY[0], (uint)C3_QUERY.len,
		&err_off, &err_type);
	cursor = ts::query_cursor_new();
}

fn void refresh(EditorCore* ed) {
	if (ed.dirty == last_dirty) return;
	last_dirty = ed.dirty;

	String src = ed.toString();
	defer mem::free(src.ptr);

	if (tree) ts::tree_delete(tree);
	tree = ts::parser_parse_string(parser, null, src.ptr, (uint)src.len);

	used_rows = ed.numrows < MAX_ROWS ? ed.numrows : MAX_ROWS;
	for (int r = 0; r < used_rows; r++) {
		for (int c = 0; c < MAX_COLS; c++) colours[r][c] = 0;
	}

	ts::query_cursor_exec(cursor, query, ts::tree_root_node(tree));

	TSQueryMatch m;
	while (ts::query_cursor_next_match(cursor, &m)) {
		for (int i = 0; i < (int)m.capture_count; i++) {
			TSQueryCapture cap = m.captures[i];

			uint nlen;
			char* nptr = ts::query_capture_name_for_id(query, cap.index, &nlen);
			int pal = palette_for((String)((char*)nptr)[:nlen]);
			if (pal == 0) continue;

			TSPoint a = ts::node_start_point(cap.node);
			TSPoint b = ts::node_end_point(cap.node);

			for (uint r = a.row; r <= b.row && r < (uint)used_rows; r++) {
				int c0 = r == a.row ? (int)a.column : 0;
				int c1 = r == b.row ? (int)b.column : MAX_COLS;
				if (c1 > MAX_COLS) c1 = MAX_COLS;
				for (int c = c0; c < c1; c++) colours[r][c] = (char)pal;
			}
		}
	}
}

fn int at(int row, int col) {
	if (row < 0 || row >= used_rows || col < 0 || col >= MAX_COLS) return 0;
	return (int)colours[row][col];
}

fn int classify(String t) {
	switch (t) {
		case "alias": case "asm": case "attrdef": case "attrmacro":
		case "catch": case "defer": case "try": case "var":
		case "fn": case "macro": case "return":
		case "import": case "module": case "assert":
		case "bitstruct": case "enum": case "excuse": case "faultdef":
		case "faultset": case "interface": case "struct": case "typedef":
		case "distinct": case "union": case "constdef": case "constset":
		case "cenum":
		case "case": case "default": case "else": case "if":
		case "nextcase": case "switch":
		case "break": case "continue": case "do": case "for":
		case "foreach": case "foreach_r": case "while":
		case "const": case "extern": case "inline": case "static":
		case "tlocal":
			return 1;
		case "comment":
		case "doc_comment":
			return 2;
		case "string_literal":
		case "raw_string_literal":
		case "char_literal":
			return 3;
		case "integer_literal":
		case "real_literal":
		case "bytes_literal":
			return 4;
		case "base_type_name":
			return 5;
		case "const_ident":
		case "true": case "false": case "null":
			return 6;
		default:
			return 0;
	}
}

fn void walk(TSNode n) {
	int c = classify(((ZString)ts::node_type(n)).str_view());
	if (c != 0) {
		TSPoint a = ts::node_start_point(n);
		TSPoint b = ts::node_end_point(n);
		if (a.row == b.row) {
			spans.push((Span) { (int)a.row, (int)a.column, (int)b.column, c });
		} else {
			for (uint r = a.row; r <= b.row; r++) {
				int c0 = r == a.row ? (int)a.column : 0;
				int c1 = r == b.row ? (int)b.column : 1000000;
				spans.push((Span) { (int)r, c0, c1, c });
			}
		}
		return;
	}
	uint count = ts::node_child_count(n);
	for (uint i = 0; i < count; i++) walk(ts::node_child(n, i));
}

fn int palette_for(String name) {
	if (name.starts_with("keyword"))     return 1;
	if (name.starts_with("comment"))     return 2;
	if (name.starts_with("string"))      return 3;
	if (name.starts_with("character"))   return 3;
	if (name.starts_with("number"))      return 4;
	if (name.starts_with("boolean"))     return 6;
	if (name.starts_with("type"))        return 5;
	if (name.starts_with("function"))    return 7;
	if (name.starts_with("constant"))    return 6;
	if (name.starts_with("variable.member")) return 8;
	if (name.starts_with("variable.parameter")) return 9;
	if (name.starts_with("variable"))    return 0;
	if (name.starts_with("punctuation")) return 10;
	if (name.starts_with("operator"))    return 10;
	return 0;
}
fn void query_test() {
	uint err_off;
	int  err_type;
	void* q = ts::query_new(ts::tree_sitter_c3(),
		&C3_QUERY[0], (uint)C3_QUERY.len,
		&err_off, &err_type);

	if (!q) {
		io::printfn("query failed: type %d at byte %d", err_type, err_off);
		return;
	}
	io::printfn("query ok, %d captures", ts::query_capture_count(q));
}
