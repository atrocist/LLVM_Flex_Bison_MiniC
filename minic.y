/*
// Date: 09/28/2014
// Author: Ashish Sunil Alate
// NC State ID 200066561
// ECE566 Project 2
// Implementing a simple code generator for a subset of C Language
*/

%{
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "llvm-c/Core.h"
#include "llvm-c/BitReader.h"
#include "llvm-c/BitWriter.h"

#include "list.h"
#include "symbol.h"

int num_errors;

extern int yylex();   /* lexical analyzer generated from lex.l */

int yyerror();
int parser_error(const char*);

void minic_abort();
char *get_filename();
int get_lineno();

int loops_found=0;

extern LLVMModuleRef Module;
extern LLVMContextRef Context;
extern LLVMTypeRef int32bit;
extern LLVMTypeRef int32bitptr;
LLVMBuilderRef Builder;
LLVMTypeRef return_type;

LLVMValueRef Function=NULL;
LLVMValueRef BuildFunction(LLVMTypeRef RetType, const char *name, paramlist_t *params);

%}

/* Data structure for tree nodes*/

%union {
  int num;
  char * id;
  LLVMTypeRef  type;
  LLVMValueRef value;
  LLVMBasicBlockRef bb;
  paramlist_t *params;
}

/* these tokens are simply their corresponding int values, more terminals*/

%token SEMICOLON COMMA COLON
%token LBRACE RBRACE LPAREN RPAREN LBRACKET RBRACKET
%token ASSIGN PLUS MINUS STAR DIV MOD 
%token LT GT LTE GTE EQ NEQ NOT
%token LOGICAL_AND LOGICAL_OR
%token BITWISE_OR BITWISE_XOR LSHIFT RSHIFT BITWISE_INVERT
%token DOT ARROW AMPERSAND QUESTION_MARK
%token FOR WHILE IF ELSE DO STRUCT SIZEOF RETURN 
%token BREAK CONTINUE
%token INT VOID

/* no meaning, just placeholders */
%token STATIC AUTO EXTERN TYPEDEF CONST VOLATILE ENUM UNION REGISTER
/* NUMBER and ID have values associated with them returned from lex*/

%token <num> NUMBER /*data type of NUMBER is num union*/
%token <id>  ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

/* values created by parser*/

%type <id> declarator
%type <params> param_list param_list_opt
%type <value> expression
%type <value> assignment_expression
%type <value> conditional_expression
%type <value> constant_expression
%type <value> logical_OR_expression
%type <value> logical_AND_expression
%type <value> inclusive_OR_expression
%type <value> exclusive_OR_expression
%type <value> AND_expression
%type <value> equality_expression
%type <value> relational_expression
%type <value> shift_expression
%type <value> additive_expression
%type <value> multiplicative_expression
%type <value> cast_expression
%type <value> unary_expression
%type <value> lhs_expression
%type <value> postfix_expression
%type <value> primary_expression
%type <value> constant
%type <value> expr_opt
%type <type>  type_specifier
/* 
   The grammar used here is largely borrowed from Kernighan and Ritchie's "The C
   Programming Language," 2nd Edition, Prentice Hall, 1988. 

   But, some modifications have been made specifically for MiniC!
 */

%%

/* 
   Beginning of grammar: Rules
*/

translation_unit:	  external_declaration
			| translation_unit external_declaration
;

external_declaration:	  function_definition
{
  /* finish compiling function */
  if(num_errors>100)
  {
     minic_abort();
  }
  else if(num_errors==0)
  {
      
  }
}
                        | declaration 
{ 
  /* nothing to be done here */
}
;

function_definition:	  type_specifier ID LPAREN param_list_opt RPAREN 
{
  symbol_push_scope();
  return_type = int32bit;
  /* This is a mid-rule action */
  BuildFunction($1,$2,$4);  
} 
                          compound_stmt 
{ 
  /* This is the rule completion */
  LLVMBasicBlockRef BB = LLVMGetInsertBlock(Builder);
  if(!LLVMGetBasicBlockTerminator(BB))
  {
    LLVMBuildRet(Builder,LLVMConstInt(LLVMInt32TypeInContext(Context),0,(LLVMBool)1));
  }
  symbol_pop_scope();
  /* make sure basic block has a terminator (a return statement) */
}
                        | type_specifier STAR ID LPAREN param_list_opt RPAREN 
{
  symbol_push_scope();
  return_type = int32bitptr;
  BuildFunction(LLVMPointerType($1,0),$3,$5);
} 
                          compound_stmt 
{ 
  /* This is the rule completion */


  /* make sure basic block has a terminator (a return statement) */

  LLVMBasicBlockRef BB = LLVMGetInsertBlock(Builder);
  if(!LLVMGetBasicBlockTerminator(BB))
  {
    LLVMBuildRet(Builder,LLVMConstPointerNull(LLVMPointerType(LLVMInt32TypeInContext(Context),0)));
  }
  symbol_pop_scope();
}
;

declaration:    type_specifier STAR declarator SEMICOLON
{
  if (is_global_scope())
  {
    LLVMAddGlobal(Module,LLVMPointerType($1,0),$3);
  } 
  else
  {
    symbol_insert($3,  /* map name to alloca */
		  LLVMBuildAlloca(Builder,LLVMPointerType($1,0),$3), /* build alloca */
		  0);  /* not an arg */
  }

} 
              | type_specifier declarator SEMICOLON
{
  if (is_global_scope())
  {
    LLVMAddGlobal(Module,$1,$2);
  }
  else
  {
    symbol_insert($2,  /* map name to alloca */
		  LLVMBuildAlloca(Builder,$1,$2), /* build alloca */
		  0);  /* not an arg */
  }
} 
;

declaration_list:	   declaration
{

}
                         | declaration_list declaration  
{

}
;


type_specifier:		  INT 
{
  $$ = LLVMInt32TypeInContext(Context);
}
;


declarator:		  ID
{
  $$ = $1;
}
;

param_list_opt:           
{ 
  $$ = NULL;
}
                        | param_list
{ 
  $$ = $1;
}
;

param_list:		  param_list COMMA type_specifier declarator
{
  $$ = push_param($1,$4,$3);
}
			| param_list COMMA type_specifier STAR declarator
{
  $$ = push_param($1,$5,LLVMPointerType($3,0));
}
                        | param_list COMMA type_specifier
{
  $$ = push_param($1,NULL,$3);
}
			| type_specifier declarator
{
  /* create a parameter list with this as the first entry */
  $$ = push_param(NULL,$2,$1);
}
			| type_specifier STAR declarator
{
  /* create a parameter list with this as the first entry */
  $$ = push_param(NULL,$3,LLVMPointerType($1,0));
}
                        | type_specifier
{
  /* create a parameter list with this as the first entry */
  $$ = push_param(NULL,NULL,$1);
}
;


statement:		  expr_stmt            
			| compound_stmt        
			| selection_stmt       
			| iteration_stmt       
			| jump_stmt            
                        | break_stmt
                        | continue_stmt
;

expr_stmt:	          SEMICOLON            
{ 

}
			| expression SEMICOLON       
{ 

}
;

compound_stmt:		  LBRACE declaration_list_opt statement_list_opt RBRACE 
{

}
;

declaration_list_opt:	
{

}
			| declaration_list
{

}
;

statement_list_opt:	
{

}
			| statement_list
{

}
;

statement_list:		  statement
{

}
			| statement_list statement
{

}
;

break_stmt:               BREAK SEMICOLON
{
  /*Get The Loop Blocks*/
  loop_info_t info = get_loop();
  if(info.body == NULL || info.exit == NULL || info.expr == NULL){
	parser_error("Syntax error\n");
  }
  /*break exits the loop so branch to the exit loop*/
  LLVMBuildBr(Builder,info.exit);
  LLVMBasicBlockRef brkb = LLVMAppendBasicBlock(Function,"");
  LLVMPositionBuilderAtEnd(Builder,brkb);
};

continue_stmt:            CONTINUE SEMICOLON
{
  /*Get The Loop Blocks*/
  loop_info_t info = get_loop();
  if(info.body == NULL || info.exit == NULL || info.expr == NULL){
	parser_error("Syntax error\n");
  }
  if(info.reinit == NULL){
  /*if it is a while loop branch to the condition block*/
    LLVMBuildBr(Builder,info.expr);
  }else{
  /*if it is a for loop branch to the reinit block*/
    LLVMBuildBr(Builder,info.reinit);
  }
  LLVMBasicBlockRef cntb = LLVMAppendBasicBlock(Function,"");
  LLVMPositionBuilderAtEnd(Builder,cntb);
};

selection_stmt:	          IF LPAREN expression RPAREN 
{
  /*Create Then block and Else Block*/
  LLVMBasicBlockRef thenb = LLVMAppendBasicBlock(Function,"then.block");
  LLVMBasicBlockRef elseb = LLVMAppendBasicBlock(Function,"else.block");
  /*Implement condition using ICMP*/
  LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($3),0,1);
  LLVMValueRef cond = LLVMBuildICmp(Builder, LLVMIntNE, $3,zero,"cond");
  /*Branch to Then or Else block depending on the condition*/
  LLVMBuildCondBr(Builder,cond,thenb,elseb);
  /*Set the builder to the else block*/
  LLVMPositionBuilderAtEnd(Builder,thenb);
  /*remember the else block*/
  $<bb>$ = elseb;	
}
			  statement ELSE 
{
  /*Create the join block*/
  LLVMBasicBlockRef joinb = LLVMAppendBasicBlock(Function,"join.block");
  /*Branch to the join block*/
  LLVMBuildBr(Builder,joinb);
  /*set the builder to the else block*/ 
  LLVMPositionBuilderAtEnd(Builder,$<bb>5);
  /*remember the join block*/
  $<bb>$ = joinb;
}
			  statement 
{
  /*get the join block*/ 
  LLVMBasicBlockRef joinb = $<bb>8;
  /*branch to the join block*/
  LLVMBuildBr(Builder,joinb);
  /*set the builder to the join block*/ 
  LLVMPositionBuilderAtEnd(Builder,joinb);
}
;

iteration_stmt:		  WHILE LPAREN 
{
  /*Create Loop Condition Block, Loop Body Block and Loop Exit Block (Join Block)*/ 
  LLVMBasicBlockRef expr = LLVMAppendBasicBlock(Function,"while.cond");
  LLVMBasicBlockRef body = LLVMAppendBasicBlock(Function,"while.body");
  LLVMBasicBlockRef exit = LLVMAppendBasicBlock(Function,"while.exit");
  /*save loop on stack for supporting nested loops*/
  push_loop(expr,body,NULL,exit);
  /*branch to the loop condition block*/
  LLVMBuildBr(Builder,expr);
  /*set the builder to loop condition block*/
  LLVMPositionBuilderAtEnd(Builder, expr);
} 
			  expression RPAREN 
{ 
  /*Get The Loop Blocks*/
  loop_info_t info = get_loop();
  /*Implement the condition using ICMP*/
  LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($4),0,1); 
  LLVMValueRef cond = LLVMBuildICmp(Builder, LLVMIntNE, $4, zero,"cond");
  /*Branch to the loop body block or loop exit block depending on condition*/
  if(info.body == NULL || info.exit == NULL || info.exit == NULL){
	parser_error("Syntax error\n");
  }
  LLVMBuildCondBr(Builder,cond,info.body,info.exit);  
  /*set the builder to loop body block*/
  LLVMPositionBuilderAtEnd(Builder,info.body);
} 
			  statement
{
  /*Get The Loop Blocks*/
  loop_info_t info = get_loop();
  if(info.body == NULL || info.exit == NULL || info.exit == NULL){
	parser_error("Syntax error\n");
  }
  /*Branch to the Condition block*/
  LLVMBuildBr(Builder,info.expr);
  /*set the builder to loop exit block*/
  LLVMPositionBuilderAtEnd(Builder, info.exit);
  /*this is loop exit block so pop the loop blocks from stack*/
  pop_loop();
}
			| FOR LPAREN expr_opt 
{
  /*Create Loop Condition Block, Loop Body Block Loop Reinit Block (Increment/Decrement Block) and Loop Exit Block (Join Block)*/ 
  LLVMBasicBlockRef expr = LLVMAppendBasicBlock(Function,"for.cond"); 
  LLVMBasicBlockRef body = LLVMAppendBasicBlock(Function,"for.body"); 
  LLVMBasicBlockRef reinit = LLVMAppendBasicBlock(Function,"for.inc"); 
  LLVMBasicBlockRef exit = LLVMAppendBasicBlock(Function,"for.exit");
  /*save loop on stack for supporting nested loops*/
  push_loop(expr,body,reinit,exit); 
  /*branch to the loop condition block*/
  LLVMBuildBr(Builder,expr);
  /*set the builder to loop condition block*/
  LLVMPositionBuilderAtEnd(Builder,expr);
} 
			  SEMICOLON expr_opt 
{
  /*Get The Loop Blocks*/
  loop_info_t info = get_loop();
  if(info.body == NULL || info.exit == NULL || info.expr == NULL){
	parser_error("Syntax error\n");
  }
  /*Implement the condition using ICMP*/
  LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($6),0,1); 
  LLVMValueRef cond = LLVMBuildICmp(Builder, LLVMIntNE, $6, zero,"cond");
  /*Branch to the loop body block or loop exit block depending on condition*/
  LLVMBuildCondBr(Builder,cond,info.body,info.exit);
  /*set the builder to loop reinit block*/
  LLVMPositionBuilderAtEnd(Builder,info.reinit);
} 
			  SEMICOLON expr_opt 
{
  /*Get The Loop Blocks*/
  loop_info_t info = get_loop();
  if(info.body == NULL || info.exit == NULL || info.expr == NULL){
	parser_error("Syntax error\n");
  }
  /*Branch to the Condition block*/
  LLVMBuildBr(Builder,info.expr);
  /*set the builder to loop body block*/
  LLVMPositionBuilderAtEnd(Builder,info.body);
}
			  RPAREN statement
{
  /*Get The Loop Blocks*/
  loop_info_t info = get_loop();
  if(info.body == NULL || info.exit == NULL || info.expr == NULL){
	parser_error("Syntax error\n");
  }
  /*Branch to the reinit block*/
  LLVMBuildBr(Builder,info.reinit);
  /*set the builder to loop exit block*/
  LLVMPositionBuilderAtEnd(Builder,info.exit);
  /*this is loop exit block so pop the loop blocks from stack*/
  pop_loop();
}
;

expr_opt:		
{ 
	$$ = LLVMConstInt(int32bit,1,1); 
}
			| expression
{ 
  $$ = $1;
}
;

jump_stmt:		  RETURN SEMICOLON
{ 
  LLVMBuildRetVoid(Builder);
  LLVMBasicBlockRef retb = LLVMAppendBasicBlock(Function,"");
  LLVMPositionBuilderAtEnd(Builder,retb);

}
			| RETURN expression SEMICOLON
{
  /*check returned type and convert the return value if there is a mismatch*/
  if(return_type != LLVMTypeOf($2)){
    if(return_type == int32bit){
      if(LLVMTypeOf($2)==int32bitptr){
    	printf("Warning -- incompatible pointer to integer conversion returning 'int *' from a function with return type 'int'\n");
        LLVMBuildRet(Builder,LLVMBuildPtrToInt(Builder,$2,int32bit,""));
      }else if(LLVMTypeOf($2)==LLVMInt1TypeInContext(Context)){
	LLVMBuildRet(Builder,LLVMBuildZExt(Builder,$2,int32bit,""));	
      }
    }else if(return_type == int32bitptr){
      printf("Warning -- incompatible integer to pointer conversion returning 'int' from a function with return type 'int*'\n");
      if(LLVMTypeOf($2) == int32bit){
        LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $2,LLVMInt64TypeInContext(Context) ,"");
	LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
	LLVMBuildRet(Builder,int32_int32ptr);
      }else if(LLVMTypeOf($2)==LLVMInt1TypeInContext(Context)){
        LLVMValueRef int1_int64 = LLVMBuildZExt(Builder, $2,LLVMInt64TypeInContext(Context) ,"");
	LLVMValueRef int1_int32ptr = LLVMBuildIntToPtr(Builder, int1_int64, int32bitptr,"");
	LLVMBuildRet(Builder,int1_int32ptr);	
      }
    }
  }else{
    LLVMBuildRet(Builder,$2);
  }
  LLVMBasicBlockRef retb = LLVMAppendBasicBlock(Function,"");
  LLVMPositionBuilderAtEnd(Builder,retb);
}
;

expression:               assignment_expression
{ 
  $$=$1;
}
;

assignment_expression:    constant_expression
{//was conditional_expression
  $$=$1;
}
                        | lhs_expression ASSIGN assignment_expression
{
  /* Implement Assignment*/
  if(LLVMIsAAllocaInst($1)){
    if(LLVMPointerType(int32bitptr,0) == LLVMTypeOf($1)) {
      if(int32bitptr == LLVMTypeOf($3)){
        $$ = LLVMBuildStore(Builder,$3,$1);
      }else{
    	printf("Warning -- incompatible integer to pointer conversion assigning from 'int' to 'int*'\n");
        LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $3,LLVMInt64TypeInContext(Context) ,"");
        LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
        $$ = LLVMBuildStore(Builder,int32_int32ptr,$1);
      }
    }else if(int32bitptr == LLVMTypeOf($1)){
      $$ = LLVMBuildStore(Builder,$3,$1);
    }
  }else{
    $$ = LLVMBuildStore(Builder,$3,$1);
  }
}
;


conditional_expression:   logical_OR_expression
{
  $$=$1;
}
                        | logical_OR_expression QUESTION_MARK expression COLON conditional_expression
{
  /* Implement cond?expr1:expr2;*/
  LLVMValueRef zero1 = LLVMConstInt(LLVMTypeOf($1),0,1); 
  LLVMValueRef op1 = LLVMBuildICmp(Builder, LLVMIntNE, $1,zero1,"");
  $$ = LLVMBuildSelect(Builder,op1,$3,$5,"");
}
;

constant_expression:       conditional_expression
{ 
  $$ = $1; 
}
;

logical_OR_expression:    logical_AND_expression
{
  $$ = $1;
}
                        | logical_OR_expression LOGICAL_OR logical_AND_expression
{
  /* Implement Logical OR*/
  LLVMValueRef zero1 = LLVMConstInt(LLVMTypeOf($1),0,1); 
  LLVMValueRef zero2 = LLVMConstInt(LLVMTypeOf($3),0,1); 
  LLVMValueRef op1 = LLVMBuildICmp(Builder, LLVMIntNE, $1,zero1,"");
  LLVMValueRef op2 = LLVMBuildICmp(Builder, LLVMIntNE, $3,zero2,"");
  $$ = LLVMBuildOr(Builder,op1,op2,"");
};

logical_AND_expression:   inclusive_OR_expression
{
  $$ = $1;
}
                        | logical_AND_expression LOGICAL_AND inclusive_OR_expression
{
  /* Implement Logical AND*/
  LLVMValueRef zero1 = LLVMConstInt(LLVMTypeOf($1),0,1); 
  LLVMValueRef zero2 = LLVMConstInt(LLVMTypeOf($3),0,1); 
  LLVMValueRef op1 = LLVMBuildICmp(Builder, LLVMIntNE, $1,zero1,"");
  LLVMValueRef op2 = LLVMBuildICmp(Builder, LLVMIntNE, $3,zero2,"");
  $$ = LLVMBuildAnd(Builder,op1,op2,"");	
}
;

inclusive_OR_expression:  exclusive_OR_expression
{
  $$=$1;
}
                        | inclusive_OR_expression BITWISE_OR exclusive_OR_expression
{
  /* Implement Bitwise OR*/
  if ((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){
    parser_error("Invalid operand 'int *' to binary operation '|'\n");
  }else{
    $$ = LLVMBuildOr (Builder, $1, $3,"");
  }
}
;

exclusive_OR_expression:  AND_expression
{
  $$ = $1;
}
                        | exclusive_OR_expression BITWISE_XOR AND_expression
{
  /* Implement Bitwise XOR*/
  if ((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){
    parser_error("Invalid operand 'int *' to binary operation '^'\n");
  }else{
    $$ = LLVMBuildXor (Builder, $1, $3, "");
  }
}
;

AND_expression:           equality_expression
{
  $$ = $1;
}
                        | AND_expression AMPERSAND equality_expression
{
  /* Implement Bitwise AND*/
  if((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){
    parser_error("Invalid operand 'int *' to binary operation '&'\n");
  }else{
    $$ = LLVMBuildAnd(Builder, $1, $3, "");
  }
}
;

equality_expression:      relational_expression
{
  $$ = $1;
}
                        | equality_expression EQ relational_expression
{
  /* Implement Equals: use icmp */
  if(LLVMTypeOf($1)==LLVMTypeOf($3)){
    $$ = LLVMBuildICmp(Builder, LLVMIntEQ, $1, $3, "");			
  }else if(int32bitptr == LLVMTypeOf($1)){
    printf("Warning -- Comparison between 'int*' and 'int'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $3,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntEQ, $1, int32_int32ptr, "");
  }else{
    printf("Warning -- Comparison between 'int' and 'int*'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $1,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntEQ, int32_int32ptr, $3, "");
  }
}
                        | equality_expression NEQ relational_expression
{
  /* Implement Not Equals: use icmp */
  if(LLVMTypeOf($1)==LLVMTypeOf($3)){
    $$ = LLVMBuildICmp(Builder, LLVMIntNE, $1, $3, "");
  }else if(int32bitptr == LLVMTypeOf($1)){
    printf("Warning -- Comparison between 'int*' and 'int'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $3,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntNE, $1, int32_int32ptr, "");
  }else{
    printf("Warning -- Comparison between 'int' and 'int*'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $1,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntNE, int32_int32ptr, $3, "");
  }
}
;

relational_expression:    shift_expression
{
  $$=$1;
}
                        | relational_expression LT shift_expression
{
  /* Implement Less Than: use icmp */
  if(LLVMTypeOf($1)==LLVMTypeOf($3)){
    if(int32bitptr == LLVMTypeOf($1))
      $$ = LLVMBuildICmp(Builder, LLVMIntULT, $1, $3, "");
    else
      $$ = LLVMBuildICmp(Builder, LLVMIntSLT, $1, $3, "");			
  }else if(int32bitptr == LLVMTypeOf($1)){
    printf("Warning -- Comparison between 'int*' and 'int'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $3,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntULT, $1, int32_int32ptr, "");
  }else{
    printf("Warning -- Comparison between 'int' and 'int*'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $1,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntULT, int32_int32ptr, $3, "");
  }
}
                        | relational_expression GT shift_expression
{
  /* Implement Greater Than: use icmp */
  if(LLVMTypeOf($1)==LLVMTypeOf($3)){
    if(int32bitptr == LLVMTypeOf($1))
      $$ = LLVMBuildICmp(Builder, LLVMIntUGT, $1, $3, "");
    else
      $$ = LLVMBuildICmp(Builder, LLVMIntSGT, $1, $3, "");			
  }else if(int32bitptr == LLVMTypeOf($1)){
    printf("Warning -- Comparison between 'int*' and 'int'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $3,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntUGT, $1, int32_int32ptr, "");
  }else{
    printf("Warning -- Comparison between 'int' and 'int*'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $1,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntUGT, int32_int32ptr, $3, "");
  }
}
                        | relational_expression LTE shift_expression
{
  /* Implement Less Than OR Equyal To: use icmp */
  if(LLVMTypeOf($1)==LLVMTypeOf($3)){
    if(int32bitptr == LLVMTypeOf($1))
      $$ = LLVMBuildICmp(Builder, LLVMIntULE, $1, $3, "");
    else
      $$ = LLVMBuildICmp(Builder, LLVMIntSLE, $1, $3, "");			
  }else if(int32bitptr == LLVMTypeOf($1)){
    printf("Warning -- Comparison between 'int*' and 'int'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $3,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntULE, $1, int32_int32ptr, "");
  }else{
    printf("Warning -- Comparison between 'int' and 'int*'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $1,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntULE, int32_int32ptr, $3, "");
  }
}
                        | relational_expression GTE shift_expression
{
  /* Implement Greater Than OR Equal To: use icmp */
  if(LLVMTypeOf($1)==LLVMTypeOf($3)){
    if(int32bitptr == LLVMTypeOf($1))
      $$ = LLVMBuildICmp(Builder, LLVMIntUGE, $1, $3, "");
    else
      $$ = LLVMBuildICmp(Builder, LLVMIntSGE, $1, $3, "");			
  }else if(int32bitptr == LLVMTypeOf($1)){
    printf("Warning -- Comparison between 'int*' and 'int'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $3,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntUGE, $1, int32_int32ptr, "");
  }else{
    printf("Warning -- Comparison between 'int' and 'int*'\n");
    LLVMValueRef int32_int64 = LLVMBuildSExt(Builder, $1,LLVMInt64TypeInContext(Context) ,"");
    LLVMValueRef int32_int32ptr = LLVMBuildIntToPtr(Builder, int32_int64, int32bitptr,"");
    $$ = LLVMBuildICmp(Builder, LLVMIntUGE, int32_int32ptr, $3, "");
  }
}
;

shift_expression:         additive_expression
{
  $$=$1;
}
                        | shift_expression LSHIFT additive_expression
{
  /* Implement Left Shift*/
  if((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){
    parser_error("Invalid operand 'int *' to binary operation '<<'\n");
  }else{
    $$ = LLVMBuildShl(Builder,$1,$3,"");
  }	
}
                        | shift_expression RSHIFT additive_expression
{
  /* Implement Right Shift*/
  if((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){   
    parser_error("Invalid operand 'int *' to binary operation '>>'\n");
  }else{
    $$ = LLVMBuildAShr(Builder,$1,$3,"");
  }
}
;

additive_expression:      multiplicative_expression
{
  $$ = $1;
}
                        | additive_expression PLUS multiplicative_expression
{
  /* Implement Addition*/
  LLVMValueRef indices[1];
  if((int32bitptr == (LLVMTypeOf($1))) && (int32bitptr == (LLVMTypeOf($3)))){
  /*Addition of two pointers*/
    parser_error("Invalid operands 'int *' and 'int *' to binary operation '+'\n");
  }else if (int32bitptr == (LLVMTypeOf($1))){
  /*Addition of pointer and integer*/
    LLVMValueRef sext = LLVMBuildSExt(Builder,$3,LLVMInt64TypeInContext(Context),"");
    indices[0] = sext;
    $$ = LLVMBuildInBoundsGEP(Builder,$1,indices,1,"");
  }else if (int32bitptr == (LLVMTypeOf($3))){
  /*Addition of two integer and pointer*/
    LLVMValueRef sext = LLVMBuildSExt(Builder,$1,LLVMInt64TypeInContext(Context),"");
    indices[0] = sext;
    $$ = LLVMBuildInBoundsGEP(Builder,$3,indices,1,"");
  }else{
  /*Addition of two integers*/
    $$ = LLVMBuildAdd(Builder,$1,$3,"");
  }	
}
                        | additive_expression MINUS multiplicative_expression
{
  /* Implement subtraction*/
  LLVMValueRef indices[1];
  if((int32bitptr == (LLVMTypeOf($1))) && (int32bitptr == (LLVMTypeOf($3)))){
  /*Subtraction of two pointers*/
    LLVMValueRef castlhs = LLVMBuildPtrToInt (Builder,$1,LLVMInt64TypeInContext(Context),"");
    LLVMValueRef castrhs = LLVMBuildPtrToInt (Builder,$3,LLVMInt64TypeInContext(Context),"");
    LLVMValueRef castsub = LLVMBuildSub(Builder,castlhs,castrhs,"");
    LLVMValueRef castdiv = LLVMBuildExactSDiv(Builder,castsub,LLVMConstInt(LLVMInt64TypeInContext(Context),4,0),"");
    $$ = LLVMBuildTrunc (Builder, castdiv, int32bit,"");
  }else if(int32bitptr == (LLVMTypeOf($1))){
  /*Subtraction of pointer and integer*/
    LLVMValueRef sext = LLVMBuildSExt(Builder,$3,LLVMInt64TypeInContext(Context),"");
    indices[0] = LLVMBuildNeg(Builder,sext,"");
    $$ = LLVMBuildInBoundsGEP(Builder,$1,indices,1,"");
  }else if (int32bitptr == (LLVMTypeOf($3))){
  /*Subtraction of integer and pointer*/
    parser_error("Invalid operands 'int' and 'int *' to binary operation '-'\n");
  }else{
  /*Subtraction of two integers*/
    $$ = LLVMBuildSub(Builder,$1,$3,"");
  }
}
;

multiplicative_expression:  cast_expression
{
  $$ = $1;
}
                        | multiplicative_expression STAR cast_expression
{
  /* Implement Multiplication*/
  if((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){
    parser_error("Invalid operand 'int *' to binary operation '*'\n");
  }else{
    $$ = LLVMBuildMul(Builder,$1,$3,"");
  }	
}
                        | multiplicative_expression DIV cast_expression
{
  /* Implement Division*/
  if ((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){
    parser_error("Invalid operand 'int *' to binary operation '/'\n");
  }else{
    $$ = LLVMBuildSDiv(Builder,$1,$3,"");
  }
}
                        | multiplicative_expression MOD cast_expression
{
  /* Implement Modulus*/
  if((int32bitptr == (LLVMTypeOf($1))) || (int32bitptr == (LLVMTypeOf($3)))){
    parser_error("Invalid operand 'int *' to binary operation '%'\n");
  }else{
    $$ =  LLVMBuildSRem(Builder,$1,$3,"");
  }
}
;

cast_expression:          unary_expression
{ $$ = $1; }
;

lhs_expression:           ID 
{
  int isArg=0;
  LLVMValueRef val = symbol_find($1,&isArg);
  if (isArg)
  {
    parser_error("Undefined Identifier\n");
  }
  else
    $$ = val;
}
                        | STAR ID
{
  int isArg=0;
  LLVMValueRef val = symbol_find($2,&isArg);
  if (isArg)
  {
    parser_error("Undefined Identifier\n");
  }
  else
    $$ = LLVMBuildLoad(Builder,val,"");
}
;

unary_expression:         postfix_expression
{
  $$ = $1;
}
                        | AMPERSAND primary_expression
{
  /* Implement address fetch */
  if(LLVMIsConstant($2)){
    parser_error("Cannot take address of RValue. RValue is a constant\n");
  }else if (LLVMIsALoadInst($2)){
    LLVMValueRef address = LLVMGetOperand($2,0);
    $$ = address;
  }
}
                        | STAR primary_expression
{
  /* Implement pointer dereference */
  $$ = LLVMBuildLoad(Builder,$2,"");
}
                        | MINUS unary_expression
{
  /* Implement negation */
  if(int32bitptr == LLVMTypeOf($2))
    parser_error("Invalid operand 'int *' to unary expression '-'\n");
  else
    $$ = LLVMBuildNeg(Builder,$2,"");
}
                        | PLUS unary_expression
{
  $$ = $2;
}
                        | BITWISE_INVERT unary_expression
{
  /* Implement Bitwise inversion */
  if(int32bitptr == LLVMTypeOf($2)){
    parser_error("Invalid operand 'int *' to unary expression '~'\n");
  }
  $$ = LLVMBuildNot(Builder,$2,"" );
}
                        | NOT unary_expression
{
  /* Implement Logical Not */	
  LLVMValueRef zero = LLVMConstInt(LLVMTypeOf($2),0,1); 
  LLVMValueRef lnot = LLVMBuildICmp(Builder, LLVMIntEQ, $2,zero,"");
  /* Zero Extend The Result */
  $$ = LLVMBuildZExt (Builder, lnot, int32bit,"");
}
;


postfix_expression:       primary_expression
{
  /*minic does not support postfix_expression. Nothing to be done here. Just return primary expression*/
  $$ = $1;
}
;

primary_expression:       ID 
{
  /*Search for the symbol in symbol table*/ 
  int isArg=0;
  LLVMValueRef val = symbol_find($1,&isArg);
  if (isArg)
    $$ = val;
  else
    $$ = LLVMBuildLoad(Builder,val,"");
}
                        | constant
{
  /*Nothing to be done here. Just return the espression*/
  $$ = $1;
}
                        | LPAREN expression RPAREN
{
  /*Nothing to be done here. Just return the espression*/
  $$ = $2;
}
;

constant:	          NUMBER  
{ 
  /* Implement a constant value*/
  $$ = LLVMConstInt( int32bit,(unsigned long long int)$1,(LLVMBool)1 );
} 
;

%%

LLVMValueRef BuildFunction(LLVMTypeRef RetType, const char *name, 
			   paramlist_t *params)
{
  int i;
  int size = paramlist_size(params);
  LLVMTypeRef *ParamArray = malloc(sizeof(LLVMTypeRef)*size);
  LLVMTypeRef FunType;
  LLVMBasicBlockRef BasicBlock;

  paramlist_t *tmp = params;
  /* Build type for function */
  for(i=size-1; i>=0; i--) 
  {
    ParamArray[i] = tmp->type;
    tmp = next_param(tmp);
  }
  
  FunType = LLVMFunctionType(RetType,ParamArray,size,0);

  Function = LLVMAddFunction(Module,name,FunType);
  
  /* Add a new entry basic block to the function */
  BasicBlock = LLVMAppendBasicBlock(Function,"entry");

  /* Create an instruction builder class */
  Builder = LLVMCreateBuilder();

  /* Insert new instruction at the end of entry block */
  LLVMPositionBuilderAtEnd(Builder,BasicBlock);

  tmp = params;
  for(i=size-1; i>=0; i--)
  {
    LLVMValueRef alloca = LLVMBuildAlloca(Builder,tmp->type,tmp->name);
    LLVMBuildStore(Builder,LLVMGetParam(Function,i),alloca);
    symbol_insert(tmp->name,alloca,0);
    tmp=next_param(tmp);
  }

  return Function;
}

extern int line_num;
extern char *infile[];
static int   infile_cnt=0;
extern FILE * yyin;

int parser_error(const char *msg)
{
  printf("%s (%d): Error -- %s\n",infile[infile_cnt-1],line_num,msg);
  return 1;
}

int internal_error(const char *msg)
{
  printf("%s (%d): Internal Error -- %s\n",infile[infile_cnt-1],line_num,msg);
  return 1;
}

int yywrap() {
  static FILE * currentFile = NULL;

  if ( (currentFile != 0) ) {
    fclose(yyin);
  }
  
  if(infile[infile_cnt]==NULL)
    return 1;

  currentFile = fopen(infile[infile_cnt],"r");
  if(currentFile!=NULL)
    yyin = currentFile;
  else
    printf("Could not open file: %s\n",infile[infile_cnt]);

  infile_cnt++;
  
  return (currentFile)?0:1;
}

int yyerror()
{
  parser_error("Un-resolved syntax error.\n");
  return 1;
}

char * get_filename()
{
  return infile[infile_cnt-1];
}

int get_lineno()
{
  return line_num;
}

void minic_abort()
{
  parser_error("Too many errors to continue.\n");
  exit(1);
}
