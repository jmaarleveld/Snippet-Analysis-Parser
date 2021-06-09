module splitter::DiffUtil

import splitter::DiffParser;


int countDiffs(DiffFile df) {
	int cnt = 0;
	visit (df) {
		case section(_, _, _): cnt = cnt + 1;
	};
	return cnt;
}

int countFiles(DiffFile df) {
	int cnt = 0;
	visit (df) {
		case file_diff(_, _, _, _): cnt = cnt + 1;
	};
	return cnt;
}


