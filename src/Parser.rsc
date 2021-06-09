module Parser

import splitter::DiffParser;
import splitter::Filter;
import splitter::DiffUtil;
import snippet::SnippetParser;
import snippet::OrderedGrammar;
import IO;
import String;
import List;
import lang::json::IO;



map[str, value] handleSnippet(list[DiffLine] sec, str oldFile, str newFile) {
	snippet = [extract(line) | line <- sec];
	<x, y> = parseSnippet(snippet);
	bool stripped = false;
	list[str] adjusted_source = [];
	if (x == -1) {
		<x, y, adjusted_source> = parseSnippetWithoutComments(snippet);
		stripped = true;
	}
	bool is_custom = false;
	bool uses_custom = false;
	if (x >= 0) {
		is_custom = isCustomNonterminal(y);
		uses_custom = usesCustomNonterminal(y);
	}
	return (
		"classification": x,
		"source": intercalate("\n", snippet),
		"stripped_comments": stripped,
		"is_custom": is_custom,
		"uses_custom": uses_custom,
		"old_file": oldFile,
		"new_file": newFile,
		"adjusted_source": intercalate("\n", adjusted_source)
	);
}


void main(str dir = "", int max = 10, str out = "", str links = "") {
	map[tuple[str, str, int], map[str, value]] results = ();
	list[tuple[str, str, int]] order = [];
	if (dir != "" && out != "" && links != "") {
		loc outputFile = toLocation(out);
		int n = 0;
		int errors = 0;
		for (loc file <- toLocation(dir).ls) {
			if (file.extension != "txt") {
				continue;
			}
			
			if (true) {
				try {
					tree = extractJavaDiffs(parseDiff(file));
					int total = countDiffs(tree);
					println("Diff: <n+1> / <max> (<total> hunks)");
					int m = 0;
					for (/file_diff(oldFile, newFile, sections, _) := tree) {
						for (/section(_, old, new) := sections) {
						
							if (true) {
								results[<file.file, "old", m>] = handleSnippet(old, oldFile, newFile);
								order += [<file.file, "old", m>];
								
								results[<file.file, "new", m>] = handleSnippet(new, oldFile, newFile);
								order += [<file.file, "new", m>];
							}
							
							m += 1;
							
							if (m % 1 == 0) {
								println("Diff: <n+1> / <max> --- Hunks parsed: <m> / <total>");
							}	
						}	
					}
				} catch IllegalArgument: {
					println("Error");
					errors += 1;
				}
			}
			n += 1;
			if (n == max) {
				break;
			}
		}
		println("");
		println("<errors> errors");
		// Dump the results
		//list[str] lines = ["<a>,<b>,<c>,<results[<a, b, c>]>" | <a, b, c> <- results];
		//str dump = "file,kind,index,result
		//'<intercalate("\n", sort(lines))>";
		//writeFile(outputFile, dump);
		map[str, value] jsonResult = (
			"nonterminals": (p: getNonterminalName(p) | int p <- [getMinIndex() .. getMaxIndex() + 1]),
			"results": results,
			"order": order,
			"meaningful_threshold": getMeaningfulThreshold(),
			"diff_info": links
		);
		writeJSON(toLocation(out), jsonResult, indent=4);
	}
}


str extract(addition(line)) = line;
str extract(deletion(line)) = line;
str extract(shared(line)) = line;