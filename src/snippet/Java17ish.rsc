module snippet::Java17ish


extend lang::java::\syntax::Java15;

syntax TypeParams 
  = inferredTypeParams: "\<" "\>" 
  ;

syntax TypeArgs =
   inferredTypeArgs: "\<" "\>" 
  ;
  
syntax Stm 
  =  \try: "try" "(" Type VarDec ")" Block CatchClause* "finally"  Block
  |  \try: "try" "(" Type VarDec ")" Block CatchClause+ 
  |  \try: "try" "(" Type VarDec ")" Block  
  ; 
  