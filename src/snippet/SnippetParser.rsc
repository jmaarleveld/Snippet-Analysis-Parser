module snippet::SnippetParser

import snippet::GrammarGenerator;
import snippet::OrderedGrammar;
import ParseTree;
import List;
import String;
import IO;


// Runtime is O(M * n^2 * P)
// M: |G|
// n: |snippet|
// P: complexity of parsing
tuple[int, value] parseSnippet(list[str] lines) {
	str snippet = intercalate("\n", lines);
	for (i <- [0 .. getMaxIndex() + 1]) {
		<success, tree> = tryParseAsNonterminal(i, snippet);
		if (success) {
			return <i, tree>;
		}
	}
	return <-1, []>;
}


bool isWhitespace(str line) {
	return findStart(line) == -1;
}

int findStart(str line) {
	int index = 0;
	while (index < size(line) && line[index] in [" ", "\t"]) {
		index += 1;
	}
	if (index == size(line)) {
		return -1;
	}
	return index;
}

bool isCommentHeuristic(str line) {
	int index = findStart(line);
	if (index == -1) {
		return false;
	}
	str remaining = line[index..];
	return startsWith(remaining, "/*") || startsWith(remaining, "*");
}

tuple[list[str], bool] stripComments(list[str] lines) {
	int startIndex = 0;
	bool removedComment = false;
	while (startIndex < size(lines)) {
		bool isComment = isCommentHeuristic(lines[startIndex]);
		if (!(isComment || isWhitespace(lines[startIndex]))) {
			break;
		} 
		removedComment = removedComment || isComment;
		startIndex += 1;
	}
	int stopIndex = size(lines) - 1;
	while (stopIndex >= 0) {
		bool isComment = isCommentHeuristic(lines[stopIndex]);
		if (!(isComment ||  isWhitespace(lines[stopIndex]))) {
			break;
		} 
		removedComment = removedComment || isComment;
		stopIndex -= 1;
	}
	if (startIndex == size(lines) || stopIndex == -1) {
		if (removedComment) {
			return <[], false>;
		}
		return <[""], true>;
	}
	return <lines[startIndex..stopIndex + 1], true>;
}

tuple[int, value, list[str]] parseSnippetWithoutComments(list[str] lines) {
	<strippedLines, parseable> = stripComments(lines);
	if (!parseable) {
		return <-2, [], strippedLines>;
	}
	<x, y> = parseSnippet(strippedLines);
	return <x, y, strippedLines>;
}