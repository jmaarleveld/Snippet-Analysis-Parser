module splitter::DiffParser

import IO;
import List;
import ParseTree;
import String;

import splitter::DiffGrammar;

/*****************************************************************************
* Abstract syntax for diff files
*/
data DiffFile = diff(list[FileDiff] sections, loc source);
data FileDiff = file_diff(str oldFile, str newFile, list[DiffSection] sections, list[ExtendedHeader] metadata);
data DiffSection = section(Header info, list[DiffLine] old, list[DiffLine] new);
data Header = header(str context, int a, int b, int c, int d);
data ExtendedHeader 
	= old_mode(str mode)
	| new_mode(str mode)
	| deleted_file_mode(str mode)
	| new_file_mode(str mode)
	| copy_from(str path)
	| copy_to(str path)
	| rename_from(str path)
	| rename_to(str path)
	| similarity_index(str index)
	| dissimilarity_index(str index)
	| index(str hash1, str hash2)
	| index_with_mode(str hash1, str hash2, str mode)
	| binary_file()
	| command(str cmd)
	| empty()
	;
data DiffLine 
	= addition(str line)
	| deletion(str line)
	| shared(str line)
	;


/*****************************************************************************
* Top-level parsing functionality.
*/
	
DiffFile parseDiff(loc source) {
	list[str] lines = readFileLines(source);
	return diff(parseFileDiffs(lines), source);
}

/*****************************************************************************
* Helper functions for parsing
*/

/**
 * Parse the diff sections for several files.
 *
 * A single diff file may contain information about multiple 
 * source files. This function splits the information in the 
 * given diff file into per-file information.
 */
list[FileDiff] parseFileDiffs(list[str] lines) {
	list[FileDiff] sections = [];
	while (size(lines) > 0) {
		// Check for trailing new line
		if (size(lines) == 1 && lines[0] != "") {
			// Unparsed left-over information.
			throw "Invalid parser state";
		}
		// Retrieve the diff information for a single file.
		tuple[FileDiff section, list[str] rest] result = parseFileDiff(lines);
		sections += [result.section];
		lines = result.rest;
	}
	return sections;
}

/**
 * Parse the diff information for a single file.
 *
 * A single diff file may contain information about multiple 
 * source files. This function extracts the information 
 * for a single file from the given diff.
 */
tuple[FileDiff, list[str]] parseFileDiff(list[str] lines) {
	// Parse the file header
	tuple[str oldFile, str newFile, list[ExtendedHeader] metadata, list[str] rest] result = parseFileSectionHeader(lines);
	lines = result.rest;
	// Retrieve all separate sections belonging to this file.
	list[DiffSection] sections = [];
	while (size(lines) > 0 && lines[0][0..2] == "@@") {	// while there is a next section header
		// Retrieve a single section corresponding to the current file.
		tuple[DiffSection sec, list[str] rest] result = parseSection(lines[0], lines[1..]);
		sections += [result.sec];
		lines = result.rest;
	} 
	return <file_diff(result.oldFile, result.newFile, sections, result.metadata), lines>;
}

/**
 * Parse the diff header information for a single file.
 *
 * A single diff file may contain information about multiple 
 * source files. This function extracts the file information 
 * for a single file from the given diff.
 */
tuple[str, str, list[ExtendedHeader], list[str]] parseFileSectionHeader(list[str] lines) {
	list[ExtendedHeader] info = [];
	int offset = 0;
	while (true) {
		ExtendedHeader h = parseExtendedHeaderLine(lines[offset]);
		if (h == empty()) {
			break;
		}
		offset += 1;
		info += [h];
		if (h == binary_file()) {
			return <"", "", info, lines[offset..]>;
		}
		if (offset == size(lines)) {
			return <"", "", info, []>;
		}
	}
	// Note: the offset of 5 is hardcoded to remove 
	// the first three +++/---, and the following space.
	str oldFile = lines[offset][5..];						// Old file
	str newFile = lines[offset + 1][5..];					// New file 
	lines = lines[offset + 2..];							// Remaining lines 
	return <oldFile, newFile, info, lines>;
}

ExtendedHeader parseExtendedHeaderLine(str line) {
	if (startsWith(line, "diff --git")) {
		return command(line);
	}
	if (/old mode <mode:\d+>/ := line) {
		return old_mode(mode);
	} 
	if (/new mode <mode:\d+>/ := line) {
		return new_mode(mode);
	}
	if (/deleted file mode <mode:\d+>/ := line) {
		return deleted_file_mode(mode);
	}
	if (/new file mode <mode:\d+>/ := line) {
		return new_file_mode(mode);
	}
	if (/copy from <path:.+>/ := line) {
		return copy_from(path);
	} 
	if (/copy to <path:.+>/ := line) {
		return copy_to(path);
	} 
	if (/rename from <path:.+>/ := line) {
		return rename_from(path);
	} 
	if (/rename to <path:.+>/ := line) {
		return rename_to(path);
	} 
	if (/similarity index <number:\d+>%/ := line) {
		return similarity_index(number);
	} 
	if (/dissimilarity index <number:\d+>%/ := line) {
		return dissimilarity_index(number);
	} 
	if (/index <h1:[a-zA-Z0-9]+>\.\.<h2:[a-zA-Z0-9]+>/ := line) {
		return index(h1, h2);
	}
	if (/index <h1:[a-zA-Z0-9]+>\.\.<h2:[a-zA-Z0-9]+> <mode:\d+>/ := line) {
		return index_with_mode(h1, h2, mode);
	} 
	if (startsWith(line, "Binary")) {
		return binary_file();
	}
	return empty();
}

/**
 * Parse a single section of changes corresponding to some file.
 */
tuple[DiffSection, list[str]] parseSection(str header, list[str] lines) {
	// Use a grammar because it is easier
	tree = parse(#start[GitHeader], header);
	Header info = cst2ast(tree);	// Extract information from parse tree.
	// Collect all the lines beloning to this section
	tuple[list[DiffLine] old, list[DiffLine] new, list[str] rest] result = parseLines(lines);
	return <section(info, result.old, result.new), result.rest>; 
}

// Helper functions for extracting information from the parse tree
Header cst2ast(start[GitHeader] h) = cst2ast(h.top);
Header cst2ast((GitHeader)`@@ - <Range old> + <Range new> @@ <String s>`) {
	<a, b> = cst2ast(old);
	<c, d> = cst2ast(new);
	return header("<s>", a, b, c, d);
}
tuple[int, int] cst2ast((Range)`<Number a> , <Number b>`) {
	return <toInt("<a>"), toInt("<b>")>;
}
tuple[int, int] cst2ast((Range)`<Number x>`) {
	return <toInt("<x>"), 1>;
}

tuple[list[DiffLine], list[DiffLine], list[str]] parseLines(list[str] lines) {
	list[DiffLine] new = [];
	list[DiffLine] old = [];
	int offset = 0;
	while (offset < size(lines)) {
		str next = lines[offset];
		if (startsWith(next, "+")) {
			new += [addition(next[1..])];
		} else if (startsWith(next, "-")) {	
			old += [deletion(next[1..])];
		} else if (startsWith(next, " ") || size(next) == 0) {
			new += [shared(next[1..])];
			old += [shared(next[1..])];
		} else if (startsWith(next, "\\")) {	// "No newline message"; ignore.
			; // Do nothing 
		} else {	// End of chunk of changes
			break;
		}
		offset += 1;
	}
	return <old, new, lines[offset..]>;
}

