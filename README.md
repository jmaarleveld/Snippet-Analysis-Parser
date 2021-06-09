# Snippet-Analysis-Parser

This repository contains the code for the snippet parser.

The `src/splitter` directory contains the code for a diff
parser and splitter. The code in said directory can be used to
parse diffs and obtain the separate snippets.

The `src/snippet` directory contains the code for the snippet
parser. There are six files `GrammarGenerator_iterationX`.
By importing one of these files and running the `makeGrammar` function,
a grammar for parsing snippets can be generated. Each grammar
generator generates a grammar for a different iteration
described in the thesis.

The `Parser.rsc` file is an interface for parsing diffs in bulk.
The `Benchmark.rsc` file can be used for bulk benchmarking.
