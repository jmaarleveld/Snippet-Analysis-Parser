module splitter::Printer

import List;
import String;
import IO;
import util::Math;

import splitter::DiffParser;


/**
 * Obtain all code snippets stored in a DiffFile object.
 * This loses original file name information.
 */
list[tuple[str, str]] getSnippets(diff(sections, _)) {
	list[list[tuple[str, str]]] secs = [getSnippets(sec) | FileDiff sec <- sections];
	return ([] | it + x | list[tuple[str, str]] x <- secs);
}
list[tuple[str, str]] getSnippets(file_diff(_, _, sections)) {
	return [getSnippets(sec) | sec <- sections];
}
tuple[str, str] getSnippets(section(_, old, new)) {
	return <getSnippets(old), getSnippets(new)>;
}
str getSnippets(list[DiffLine] lines) {
	return intercalate("\n", [getSnippets(line) | line <- lines]);
}
str getSnippets(addition(line)) = line;
str getSnippets(deletion(line)) = line;
str getSnippets(shared(line)) = line;


/** 
 * Store all snippets from a parsed diff file in 
 * a directory, in separate files.
 */
void dumpDiffsInDir(DiffFile df, loc directory) {
	str baseName = df.source.file + "_diff_";
	int diffNumber = 1;
	for (<str old, str new> <- getSnippets(df)) {
		str name = baseName + toString(diffNumber);
		writeFile(directory + (name + "_old.java"), old);
		writeFile(directory + (name + "_new.java"), new);
		diffNumber += 1;
	}
}
