module test;

import std::io;

struct Foo {
	String name;
	int age;
	bool foo;
}

fn void main() => @pool(){
	io::print("hello");
	Foo foo = {
		.name = "tadiwa",
		.age = 18,
		.foo = false 
	}
	io::printfn("name is %s",foo.name);
};

