module splitter::Filter

import splitter::DiffParser;
import String;


DiffFile extractJavaDiffs(DiffFile df) {
	return diff(
		[fileDiff | fileDiff <- df.sections, isJavaFile(fileDiff.newFile)], 
		df.source);
}

bool isJavaFile(str name) {
	return endsWith(name, ".java");
}
