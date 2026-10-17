module ts;

struct TSPoint {
	uint row;
	uint column;
}

struct TSNode {
	uint[4] context;
	void* id;
	void* tree;
}

struct TSQueryCapture {
	TSNode node;
	uint index;
}

struct TSQueryMatch {
	uint id;
	ushort pattern_index;
	ushort capture_count;
	TSQueryCapture* captures;
}

extern fn void* query_new(
	void* lang,
	char* source,
	uint len,
	uint* error_offset,
	int* error_type
) @cname("ts_query_new");
extern fn void query_delete(void* q) @cname("ts_query_delete");
extern fn char* query_capture_name_for_id(void* q, uint id, uint* len) @cname("ts_query_capture_name_for_id");
extern fn uint query_capture_count(void* q) @cname("ts_query_capture_count");

extern fn void* query_cursor_new() @cname("ts_query_cursor_new");
extern fn void query_cursor_delete(void* c) @cname("ts_query_cursor_delete");
extern fn void query_cursor_exec(void* c, void* q, TSNode node) @cname("ts_query_cursor_exec");
extern fn bool query_cursor_next_match(void* c, TSQueryMatch* match) @cname("ts_query_cursor_next_match");

extern fn void* parser_new() @cname("ts_parser_new");
extern fn void parser_delete(void* p) @cname("ts_parser_delete");
extern fn bool parser_set_language(void* p, void* lang) @cname("ts_parser_set_language");
extern fn void* parser_parse_string(void* p, void* old_tree, char* src, uint len) @cname("ts_parser_parse_string");

extern fn void tree_delete(void* tree) @cname("ts_tree_delete");
extern fn TSNode tree_root_node(void* tree) @cname("ts_tree_root_node");

extern fn char* node_type(TSNode n) @cname("ts_node_type");
extern fn uint node_child_count(TSNode n) @cname("ts_node_child_count");
extern fn TSNode node_child(TSNode n, uint i) @cname("ts_node_child");
extern fn bool node_is_null(TSNode n) @cname("ts_node_is_null");
extern fn TSPoint node_start_point(TSNode n) @cname("ts_node_start_point");
extern fn TSPoint node_end_point(TSNode n) @cname("ts_node_end_point");

extern fn void* tree_sitter_c3() @cname("tree_sitter_c3");
extern fn void* tree_sitter_c() @cname("tree_sitter_c");
extern fn void* tree_sitter_python() @cname("tree_sitter_python");
extern fn void* query_predicates_for_pattern(
	void* q,
	uint pattern_index,
	uint* step_count
) @cname("ts_query_predicates_for_pattern");
