module Benchmark

import Datetime;
import String;
import List;
import IO;
import ParseTree;
import lang::json::IO;
import util::Benchmark;
import util::ShellExec;

import util::JSONConverter;
import util::Casting;
import util::\alias;
import snippet::OrderedGrammar;
import snippet::SnippetParser;


int countAmbiguities(Tree tree) {
	int count = 0;
	visit (tree) {
		case amb(_): count = count + 1;
	}
	return count;
}


list[map[str, value]] prepareData(map[str, value] parsed, map[str, map[str, str]] linking) {
	map[str, int] topIndices = ();
	map[value, map[tuple[str, str], int]] fileIndices = ();
	
	list[map[str, value]] result = [];
	map[list[value], map[str, value]] parsedResults = cast(#map[list[value], map[str, value]], parsed["results"]);
	for (key <- parsedResults) {
		if (key[0] notin topIndices) {
			// Create a new data bucket
			map[str, value] bucket = (
				"new_hash": linking[key[0]]["new"],
				"old_hash": linking[key[0]]["old"],
				"diffs": []
			);
			result += bucket;
			topIndices[cast(#str, key[0])] = size(result) - 1;
			fileIndices[key[0]] = ();
		}
			
			
		tuple[str, str] fileKey = cast(#tuple[str, str], <parsedResults[key]["old_file"], parsedResults[key]["new_file"]>);
		if (fileKey notin fileIndices[key[0]]) {
			// Create new diff bucket
			map[str, value] diffBucket = (
				"old_file": fileKey[0],
				"new_file": fileKey[1],
				"old_file_benchmark": (),
				"new_file_benchmark": (),
				"snippets": []
			);
			
			result[topIndices[key[0]]]["diffs"] = concat([result[topIndices[key[0]]]["diffs"], [diffBucket]]);
			fileIndices[key[0]][fileKey] = size(cast(#list[value], result[topIndices[key[0]]]["diffs"])) - 1;
		} 
		// Insert snippet
		map[str, value] snippetBucket = (
			"snippet_key": [key[0], key[1], key[2]],
			"benchmark": ()
		);
		list[map[str, value]] temp = cast(#list[map[str, value]], result[topIndices[key[0]]]["diffs"]);
		temp[fileIndices[key[0]][fileKey]]["snippets"] = concat([temp[fileIndices[key[0]][fileKey]]["snippets"], [snippetBucket]]);
		//temp[fileIndices[fileKey]]["snippets"] += [snippetBucket];
	 	result[topIndices[key[0]]]["diffs"] = cast(#value, temp);
		//result[topIndices[key[0]]]["diffs"][fileIndices[fileKey]] += [snippetBucket];
	}
	return result;
}

str getFile(str repo, str file, str hash) {
	if (file[0] == "/") {
		file = file[1..];
	}
	//println(toLocation(repo));
	//println(exists(toLocation(repo)));
	str output = exec("git", workingDir=toLocation(repo), args=["show", "<hash>:<file>"]);
	return output;
}

map[str, value] executeBenchmark(str source, int rounds, bool countAmbiguity, tuple[bool, Tree] (str) function) {
	bool result = false;
	list[int] times = [];
	ambiguities = -1;
	for (int i <- [0 .. rounds]) {
		int before = getNanoTime();
		<result, tree> = function(source);
		int after = getNanoTime();
		times += [after - before];
		if (result && ambiguities == -1 && countAmbiguity) {
			ambiguities = countAmbiguities(tree);
		}
	}
	return (
		"success": result,
		"times": times,
		"ambiguities": ambiguities
	);
}	

void prepareGrammar() {
	str snippet = "
	'package hello_world;
	'
	'class HelloWorld {
	'	public static void Main(String argv[]) {
	'		System.out.println(\"Hello World!\");
	'	}
	'}";
	for (int i <- [0..100]) {
		parseJavaString(snippet);
	}
	for (int i <- [0..getMaxIndex() + 1]) {
		tryParseAsNonterminal(i, snippet);
	}
}

void spinUp() {
	str snippet = "
	'package hello_world;
	'
	'class HelloWorld {
	'	public static void Main(String argv[]) {
	'		System.out.println(\"Hello World!\");
	'	}
	'}";
	for (int i <- [0..10]) {
		parseJavaString(snippet);
	}
}



list[map[str, value]] performBenchmark(map[str, value] parsed, map[str, map[str, str]] linking, str repo, int rounds, bool countAmbiguity, bool useToplevel) {
	println(countAmbiguity);
	println(useToplevel);
	list[map[str, value]] benchmarkData = prepareData(parsed, linking);
	map[list[value], value] snippetSources = cast(#map[list[value], value], parsed["results"]);
	prepareGrammar();
	int totalDiffs = size(benchmarkData);
	for (i <- [0 .. size(benchmarkData)]) {
		map[str, value] diff = benchmarkData[i];
		str oldHash = cast(#str, diff["old_hash"]);
		str newHash = cast(#str, diff["new_hash"]);
		list[map[str, value]] files = cast(#list[map[str, value]], diff["diffs"]);
		int totalFiles = size(files);
		for (j <- [0 .. size(files)]) {
			map[str, value] file = files[j];
			str oldFile = cast(#str, file["old_file"]);
			str newFile = cast(#str, file["new_file"]);
			
			// Benchmark full files
			str oldSource = "";
			if (oldFile != "/dev/null" && oldFile != "dev/null") {
				oldSource = getFile(repo, oldFile, oldHash);
			}
			str newSource = "";
			if (newFile != "/dev/null" && newFile != "dev/null") {
				newSource = getFile(repo, newFile, newHash);
			}
			
			map[str, num] times = benchmark((
				"old_file": void() { parseJavaString(oldSource); },
				"new_file": void() { parseJavaString(newSource); }
			));
			
			file["old_file_benchmark"] = executeBenchmark(oldSource, rounds, countAmbiguity, tuple[bool, Tree] (str prog) { return parseJavaString(prog); });
			file["new_file_benchmark"] = executeBenchmark(newSource, rounds, countAmbiguity, tuple[bool, Tree] (str prog) { return parseJavaString(prog); });
			
			// Benchmark snippets
			list[map[str, value]] snippets = cast(#list[map[str, value]], file["snippets"]);
			int totalSnippets = size(snippets);
			for (k <- [0 .. size(snippets)]) {
				println("Diff <i + 1> / <totalDiffs> --- File <j + 1> / <totalFiles> --- Snippet <k + 1> / <totalSnippets>");
				map[str, value] snippet = snippets[k];
				list[value] key = cast(#list[value], snippet["snippet_key"]);
				//tuple[str, str, int] key = <cast(#str, rawKey[0]), cast(#str, rawKey[1]), cast(#int, rawKey[2])>;
				map[str, value] snippetInfo = cast(#map[str, value], snippetSources[key]);
				str sourceCode = cast(#str, snippetInfo["source"]);
				bool strippedComments = cast(#bool, snippetInfo["stripped_comments"]);
				if (strippedComments) {
					sourceCode = cast(#str, snippetInfo["adjusted_source"]);
				}
				int classificationCode = cast(#int, snippetInfo["classification"]);
				if (classificationCode >= 0) {
					if (useToplevel) {
						snippet["benchmark"] = executeBenchmark(
								sourceCode, rounds, countAmbiguity,
								tuple[bool, Tree](str prog) {
									try { 
										tree = parse(#start[UltimateTopLevel], prog, allowAmbiguity=true); 
										return <true, cast(#Tree, tree)>; 
									} catch ParseError: { 
										return <false, char(-1)>; // No tree
									}}
								);
					} else {
						snippet["benchmark"] = executeBenchmark(
								sourceCode, rounds, countAmbiguity,
								tuple[bool, Tree](str prog) {
									try { 
										tree = parseIndex(classificationCode, prog);
										return <true, cast(#Tree, tree)>; 
									} catch ParseError: { 
										return <false, char(-1)>; // No tree
									}}
								);
					}
				}
				
				snippets[k] = snippet;
			}
			file["snippets"] = snippets;
			files[j] = cast(#value, file);
		}
		diff["diffs"] = cast(#value, files);
		benchmarkData[i] = cast(#value, diff);
	}
	
	return benchmarkData;
}


void main(str source = "", str target = "", str repo = "", int rounds = 5, bool countAmbiguity = true, bool useToplevel = false) {
	if (source == "" || target == "" || repo == "") {
		return;
	}
	loc srcFile = toLocation(source);
	loc tgtFile = toLocation(target);
	
	// What do we have to do?
	//	1) Determine what commits were used to compute diffs 
	//		--> External data file to link to
	//			- Can be mentioned in JSON file
	//			- Computed by Python script
	//			- Maps filenames to pairs of hashes
	//			- Can be used in parser to perform linking
	//	2) Find snippets corresponding to commits from data files
	//		--> Sort JSON file based on hashes 
	// 	3) Get orginal source code
	//		--> Git command trickery
	// 	4) Benchmark parsing
	//		--> Run the parser
	
	
	// Read classification data from JSON
	value raw = readJSON(#map[str, value], srcFile);
	
	// Convert the raw JSON output into a uniform structure.
	// Here, both objects and dictionaries are represented as 
	// simple maps.
	// Both tuples and arrays are represented using lists.
	map[str, value] file = convertJSON(
		raw,
		object((
			"diff_info": string(),
			"meaningful_threshold": integer(),
			"order": array(\tuple([string(), string(), integer()])),
			"nonterminals": dictionary(integer(), string()),
			"results": 
				dictionary(
					\tuple([string(), string(), integer()]), 
					object((
						"uses_custom": \bool(),
						"is_custom": \bool(),
						"stripped_comments": \bool(),
						"old_file": string(),
						"new_file": string(),
						"source": string(),
						"classification": integer(),
						"adjusted_source": string()
					))
				)
		))
	);
	
	str fileName = cast(#str, file["diff_info"]);
	loc infoFile = toLocation(fileName);
	map[str, map[str, str]] linking = readJSON(#map[str, map[str, str]], infoFile);
	
	list[map[str, value]] benchmarkData = performBenchmark(file, linking, repo, rounds, countAmbiguity, useToplevel);
	writeJSON(tgtFile, benchmarkData, indent=4);
}