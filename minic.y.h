/* A Bison parser, made by GNU Bison 3.0.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2013 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

#ifndef YY_YY_MINIC_Y_H_INCLUDED
# define YY_YY_MINIC_Y_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token type.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    SEMICOLON = 258,
    COMMA = 259,
    COLON = 260,
    LBRACE = 261,
    RBRACE = 262,
    LPAREN = 263,
    RPAREN = 264,
    LBRACKET = 265,
    RBRACKET = 266,
    ASSIGN = 267,
    PLUS = 268,
    MINUS = 269,
    STAR = 270,
    DIV = 271,
    MOD = 272,
    LT = 273,
    GT = 274,
    LTE = 275,
    GTE = 276,
    EQ = 277,
    NEQ = 278,
    NOT = 279,
    LOGICAL_AND = 280,
    LOGICAL_OR = 281,
    BITWISE_OR = 282,
    BITWISE_XOR = 283,
    LSHIFT = 284,
    RSHIFT = 285,
    BITWISE_INVERT = 286,
    DOT = 287,
    ARROW = 288,
    AMPERSAND = 289,
    QUESTION_MARK = 290,
    FOR = 291,
    WHILE = 292,
    IF = 293,
    ELSE = 294,
    DO = 295,
    STRUCT = 296,
    SIZEOF = 297,
    RETURN = 298,
    BREAK = 299,
    CONTINUE = 300,
    INT = 301,
    VOID = 302,
    STATIC = 303,
    AUTO = 304,
    EXTERN = 305,
    TYPEDEF = 306,
    CONST = 307,
    VOLATILE = 308,
    ENUM = 309,
    UNION = 310,
    REGISTER = 311,
    NUMBER = 312,
    ID = 313,
    LOWER_THAN_ELSE = 314
  };
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE YYSTYPE;
union YYSTYPE
{
#line 48 "minic.y" /* yacc.c:1909  */

  int num;
  char * id;
  LLVMTypeRef  type;
  LLVMValueRef value;
  LLVMBasicBlockRef bb;
  paramlist_t *params;

#line 123 "minic.y.h" /* yacc.c:1909  */
};
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;

int yyparse (void);

#endif /* !YY_YY_MINIC_Y_H_INCLUDED  */
