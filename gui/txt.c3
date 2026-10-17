module main;

import std::io;

fn void main() => @pool(){
	String[5] names = {"ano","tadi","jerry","taida","mati"};
	@foreach(names;index,value){
		io::printfn("%s came in %s during exams",value,index);
	};
}

macro @foreach(a; @body(index, value)){
	for (int i = 0; i < a.len; i++){
	  	@body(i, a[i]);
	}
}

