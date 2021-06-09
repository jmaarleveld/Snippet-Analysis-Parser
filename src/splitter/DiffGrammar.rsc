module splitter::DiffGrammar

/*****************************************************************************
* Grammar for parsing headers in diff files
*/

layout Whitespace = [\t\r\ ]*;
start syntax GitHeader = ^"@@" "-" Range "+" Range "@@" String$;
syntax Range = Number "," Number | Number;
lexical Number = [0-9]+;
lexical String = Char (Char | WhitespaceChar)* | ();
lexical Char = [a-zA-Z0-9\-+=_()\<\>/!@#$%^&*.?,\[\]{}\"\':;\\];
lexical WhitespaceChar = [ \ \t];
