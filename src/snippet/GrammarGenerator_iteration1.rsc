module snippet::GrammarGenerator_iteration1

import Grammar;
import analysis::grammars::Dependency;
import analysis::graphs::Graph;
import IO;
import List;
//extend lang::java::\syntax::Java15;		// Start: CompilationUnit
import lang::rascal::format::Grammar;
import ParseTree;
import lang::sdf2::filters::CountPreferAvoid;

extend snippet::Java17ish;

/**************************************************************************************************
* Grammar Extensions*/

// Old projects may use assert as a function. 
// However, in current versions of Java, it is a statement.
syntax AssertAsFunction = "assert" "(" Expr "," Expr ")";
syntax Stm 
	= AssertAsFunction;



/**************************************************************************************************
* Lists of nonterminals, used for code generation */ 

/**
 * Nonterminals which should be attempted first when classifying 
 * a code snippet. They are tried in the order given in this list.
 */
list[str] getPrioritySorts() {
	return [];
}

/**
 * Nonterminals of the "syntax" type which have been added
 * or modified. This is needed to ensure that definitions 
 * are included during code generation.
 */
list[str] getCustomSorts() {
	return [
		"AssertAsFunction",
		"Stm"
	];
}

/**
 * Nonterminals of the "lexical" type which have been added
 * or modified. This is needed to ensure that definitions 
 * are included during code generation.
 */
list[str] getCustomLex() {
	return [];
}

/**
 * List of all modified nonterminals in the grammar
 */
list[str] getModifiedSymbols() {
	return [
		"Stm"
	];
}

/**
 * List of nonterminals which should not be attempted 
 * during the parsing process.
 */
list[str] getTrashSorts() {
	return [
		"CharContent",
		"FooStringChars",
	 	"StringPart",
	 	"SingleChar",
	 	"StringChars",
	 	"CommentPart",
	 	"EOLCommentChars",
	 	"BlockCommentChars",
	 	"Asterisk",
	 	"EscEscChar",
	 	"EscChar",
	 	"UnicodeEscape",
	 	"EndOfFile",
	 	"CarriageReturn",
	 	"LineTerminator"
	];
}

/** 
 * List of nonterminals and lexicals which should be excluded 
 * in the classification process.
 */
list[str] getExcluded() {
	return ["ID"] + getTrashSorts();
}

/**************************************************************************************************
* Generic Utility functions */ 


/**
 * Remove all duplicate occurences of each element from a list
 */
list[str] unique(list[str] initial) {
	result = [];
	for (x <- initial) {
		if (x notin result) {
			result += [x];
		}
	}
	return result;
}

/**************************************************************************************************
* Helper functions */ 

/**
 * Filter all excluded symbols from a list of symbol names
 */
list[str] filterExcluded(list[str] items) {
	list[str] excluded = getExcluded();
	return [x | x <- items, x notin excluded];
}

/**
 * Compute the "Meaningful Threshold", which is the greatest index n
 * such that whenever an index M satisfies M > n, then
 * items[M] is a member of getTrashSorts()
 */
int computeThreshold(list[str] items) {
	list[str] meaningless = getExcluded() + getTrashSorts();
	int thres = 0;
	for (i <- [0..size(items)]) {
		if (items[i] notin meaningless) {
			thres = i;
		}
	}
	return thres;
}

/**
 * Convert a string to its sort/lex object
 */
value getKey(str typ) {
	if (typ in getCustomLex()) {
		return lex(typ);
	}
	return sort(typ);
}

/**
 * Reorder a list of nonterminals such that 
 * 	1) all custom nonterminals are included
 * 	2) all priority nonterminals are inserted at the front 
 *	3) all trash nonterminal are moved to the end
 */
list[str] ReorderNonterminals(list[value] ord) {
	list[str] customSorts = getCustomSorts();
	list[str] stringSorts = getTrashSorts();
	list[str] prioritySorts = getPrioritySorts();
	list[str] items = getPrioritySorts();
	bool sawStart = false;
	for (str name <- [name | /str name := ord]) {
		if (name in prioritySorts) {
			continue;
		}
		if (name == "CompilationUnit") {
			sawStart = true;
			items += [name];
			for (str typ <- customSorts) {
				if (typ notin items) {
					items += [typ];
				}
			}
			items += stringSorts;
		} else if (sawStart || name notin stringSorts) {
			if (!(sawStart && name in customSorts)) {
				items += [name];
			}
		} 
	}
	return unique(items);
}

str grammarToRascal(Grammar g) {
	// First, find start symbol
	list[str] lines = [];
	if (\start(sort(str x)) := [z | z <- g.starts][0]) {
		for (Symbol key <- g.rules) {
			bool isStart = false;
			if (\start(sort(str y)) := key) {
				continue;
			}
			if (sort(str y) := key) {
				if (x == y) {
					isStart = true;
					lines += ["start " + topProd2rascal(g.rules[key])];
				}
			}
			if (!isStart) {
				lines += [topProd2rascal(g.rules[key])];
			}
		}
		return intercalate("\n", lines);
	}
	throw "No Start";
}


/**************************************************************************************************
* Code generation functions */

/**
 * Format a single nonterminal for use in the classification function
 */
str formatNonterminal(int i, str x) {
	if (x in ["CompilationUnit"]) {
		return "    case <i>: return parse(#start[<x>], snippet, allowAmbiguity=true);";
	}
	if (x in ["LAYOUT"] + getCustomLex()) {
		return "    case <i>: return parse(#<x>, snippet, allowAmbiguity=true);";
	}
	return "    case <i>: return parse(#start[Start<x>], snippet, allowAmbiguity=true);";
	//return "    case <i>: return parse(#<x>, snippet, allowAmbiguity=true);";
}

/**
 * Format a single nonterminal for use in the parsing function
 */
str formatParseFunction(int i, str x) {
	if (x in ["CompilationUnit"]) {
		return "value getParseTree(<i>, str src) = parse(#start[<x>], src, allowAmbiguity=true);";
	}
	if (x in ["LAYOUT"] + getCustomLex()) {
		return "value getParseTree(<i>, str src) = parse(#<x>, src, allowAmbiguity=true);";
	}
	return "value getParseTree(<i>, str src) = parse(#start[Start<x>], src, allowAmbiguity=true);";
	//return "value getParseTree(<i>, str src) = parse(#<x>, src, allowAmbiguity=true);";
}


/**
 * Define the top-level nonterminal
 */
str formatSuperNonterminal(list[str] symbols) {
	str def = "
	'start syntax UltimateTopLevel 	
	'	=
	'<intercalate("\n", ["	| <x>" | x <- symbols])>		 
	'	;
	'";
	return def;
}


void makeGrammar() {
	// Obtain an ordered list of nonterminals
	Grammar g = grammar(#start[CompilationUnit]);
	deps = symbolDependencies(g);
	list[value] ord = reverse(order(deps));
	list[str] allItems = ReorderNonterminals(ord);	// Apply some ordering constraints
	list[str] items = filterExcluded(allItems);		// Filter out excluded items
	list[str] customSymbols = getCustomSorts() + getCustomLex();	// Cache custom symbols
	
	// Compute some strings and data used for formatting.
	list[value] rules = [g.rules[getKey(typ)] | typ <- customSymbols];
	str listCode = intercalate("\n", [formatNonterminal(i, name) | <i, name> <- zip([0 .. size(items)], items)]);
	map[str, int] mapping = (name: i | <i, name> <- zip([0 .. size(items)], items));
	list[str] builtinSorts = [x | /sort(str x) := ord, x notin customSymbols || x in getModifiedSymbols()];
	list[str] builtinLex = [x | /lex(str x) := ord, x notin customSymbols || x in getModifiedSymbols()];
	list[str] isCustomChecks = 	
		["bool isCustomNonterminal_int(sort(\"<x>\")) = true;" | x <- getCustomSorts(), x notin builtinSorts] + 
		["bool isCustomNonterminal_int(\\start(sort(\"Start<x>\"))) = true;" | x <- getCustomSorts(), x notin builtinSorts] +
		["bool isCustomNonterminal_int(lex(\"<x>\")) = true;" | x <- getCustomLex(), x notin builtinLex];
	list[str] parseFunctions = [formatParseFunction(i, name) | <i, name> <- zip([0 .. size(items)], items)];
	//	'<intercalate("\n", [topProd2rascal(rule) | rule <- filterRules(rules)])>
	str code = "
	'module snippet::OrderedGrammar
	'
	'import ParseTree;
	'import Boolean;
	'import Type;
	'
	'<grammarToRascal(g)>
	'
	'<intercalate("\n", ["start syntax Start<x> = <x>;" | x <- items, x notin ["LAYOUT", "CompilationUnit"]])>
	'
	'<formatSuperNonterminal(items)>
	'
	'str getNonterminalName(int x) {
	'	if (x == -1) { 
	'		return \"ParseError\";
	'	}
	'	if (x == -2) {
	'		return \"CommentFragment\";
	'	}
	'	map[int, str] names = (
	'		<intercalate(",\n", ["    <mapping[key]>: \"<key>\"" | key <- mapping])>
	'	);
	'	return names[x];
	'}
	'
	'int getMinIndex() {
	'	return -2;
	'}
	'
	'int getMaxIndex() {
	'	return <size(items)> - 1;
	'}	
	'
	'int getMeaningfulThreshold() {
	'	return <computeThreshold(allItems)>;
	'}
	'
	'tuple[bool, value] tryParseAsNonterminal(int index, str snippet) {
	'	try {
	'		tree = parseIndex(index, snippet);
	'		return \<true, tree\>;
	'	} catch ParseError: {
	'		return \<false, []\>;
	'	} 
	'}
	'
	'value parseIndex(int index, str snippet) { 
	'	switch(index) {
	'<listCode>
	'		default: throw \"Invalid index\";
	'	}
	'}
	'
	'bool anyTrue(list[bool] xs) {
	'	for (x \<- xs) {
	'		if (x) { return true; }
	'	}
	'	return false;
	'}
	'
	'bool usesCustomNonterminal(value tree) {
	'	booleans = [];	
	'	visit(tree) {
	'		case lex(x): { if (isCustomNonterminal_int(lex(x))) { return true; } }
	'		case sort(x):  { if (isCustomNonterminal_int(sort(x))) { return true; } }
	'	};
	'	return false;
	'}
	'
	'bool isCustomNonterminal(value tree) {
	'	return isCustomNonterminal_int(typeOf(tree));
	'}
	'
	'<intercalate("\n", isCustomChecks)>
	'bool isCustomNonterminal_int(_) = false;
	'
	'<intercalate("\n", parseFunctions)>
	'
	'";
	
	writeFile(|project://diff-splitter/src/snippet/OrderedGrammar.rsc|, code);
}
