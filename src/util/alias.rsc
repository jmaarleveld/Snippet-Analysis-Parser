module util::\alias

//import Grammar;
//import analysis::grammars::Dependency;
//import analysis::graphs::Graph;
import List;
import IO;


import Type;
import snippet::Java17ish;
import ParseTree;


value getType(value x) {
	return typeOf(x);
}

tuple[bool, Tree] parseJavaString(str source) {
	//Grammar g = grammar(#start[CompilationUnit]);
	//deps = symbolDependencies(g);
	//println(size(order(deps)));
	try {
		tree = parse(#start[CompilationUnit], source, allowAmbiguity=true);
		return <true, tree>;
	} catch ParseError: {
		return <false, char(-1)>;
	}
}

