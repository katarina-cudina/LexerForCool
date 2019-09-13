%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno; 
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int COMMENT_COUNTER = 0;

%}

 /*
  * Define names for regular expressions here.
  */

NUMBERS                [0-9]+
WHITESPACES            [ \f\r\t\v]
SINGLELINE_COMMENTS    "--"(.)*
OBJECTS                [a-z][0-9a-zA-Z_]*
TYPES                  [A-Z][0-9a-zA-Z_]*
SINGLE_CHARS           "+"|"-"|"*"|"/"|"<"|"="|"("|")"|":"|"."|"@"|"~"|","|"{"|"}"|";"
INVALID_CHARS          "!"|"?"|"`"|"#"|"$"|"%"|"^"|"&"|"_"|"["|"]"|"|"|[\\]|">"

%x COMMENT_STATE
%x STRING_STATE
%x STRING_ERROR_STATE


%%



"<="    return LE;
"<-"    return ASSIGN;
"=>"    return DARROW;


(?i:class)    return CLASS;
(?i:else)     return ELSE;
(?i:fi)       return FI;
(?i:if)       return IF;
(?i:inherits) return INHERITS;
(?i:isvoid)   return ISVOID;
(?i:let)      return LET;
(?i:loop)     return LOOP;
(?i:pool)     return POOL;
(?i:then)     return THEN;
(?i:while)    return WHILE;
(?i:case)     return CASE;
(?i:esac)     return ESAC;
(?i:new)      return NEW;
(?i:of)       return OF;
(?i:not)      return NOT;
(?i:in)		return IN;
(t)(?i:rue)   {
                    cool_yylval.boolean = true;
                    return BOOL_CONST;
  }
(f)(?i:alse)  {   cool_yylval.boolean = false;
                    return BOOL_CONST;
                }

{NUMBERS}	{	
			cool_yylval.symbol = inttable.add_string(yytext);
			return INT_CONST;
		}
{OBJECTS}	{
			cool_yylval.symbol = idtable.add_string(yytext);
			return OBJECTID;
		}
{TYPES}	{
			cool_yylval.symbol = idtable.add_string(yytext);
			return TYPEID;
		}

{SINGLE_CHARS}	return int(yytext[0]);

{INVALID_CHARS}     {
                        cool_yylval.error_msg = yytext;
                        return ERROR;
}




{WHITESPACES}+      ;

"\n"                curr_lineno++;

{SINGLELINE_COMMENTS}   ;

{SINGLELINE_COMMENTS}\n curr_lineno++;

"*)"                {
                        cool_yylval.error_msg = "Unmatched *)";
                        return ERROR;

                    }
"(*"                {
                        COMMENT_COUNTER++;
                        BEGIN(COMMENT_STATE);
                    }
<COMMENT_STATE>"(*"	COMMENT_COUNTER++;
<COMMENT_STATE>"*)" {
			COMMENT_COUNTER--;
			if(COMMENT_COUNTER == 0)
				BEGIN(INITIAL);
			}
<COMMENT_STATE><<EOF>>    {
                            BEGIN(INITIAL);
                            cool_yylval.error_msg= "EOF in comment";
                            return ERROR;
				}
<COMMENT_STATE>\n	curr_lineno++;

<COMMENT_STATE>{WHITESPACES}	;
<COMMENT_STATE>.		;

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

"\""    {
                    BEGIN(STRING_STATE);
                    string_buf_ptr = string_buf;
                }

<STRING_STATE><<EOF>>   {
                    cool_yylval.error_msg = "EOF in string";
                    BEGIN(INITIAL);
                    return ERROR;

                }
<STRING_STATE>\n    {
                        curr_lineno++;
                        BEGIN(INITIAL);
                        cool_yylval.error_msg = "Unterminated string constant";
                        return ERROR;
}
<STRING_STATE>\0  {
                        cool_yylval.error_msg = "String contains null character";
                        BEGIN(STRING_ERROR_STATE);
                        return ERROR;
}
<STRING_STATE>\\\0				{
					 cool_yylval.error_msg = "Escaped null character found in string";
			  		 string_buf[0] = '\0';
			  		 BEGIN(STRING_ERROR_STATE);
			  		 return (ERROR);
					}
<STRING_STATE>"\""  {
                        if((string_buf_ptr - string_buf) >= MAX_STR_CONST)
                        {
                            *string_buf = '\0';
                            cool_yylval.error_msg = "String constant too long";
                            BEGIN(INITIAL);
                            return ERROR;
                        }
                        *string_buf_ptr = '\0';
                        cool_yylval.symbol = stringtable.add_string(string_buf);
                        BEGIN(INITIAL);
                        return STR_CONST;
                    }
<STRING_STATE>. *string_buf_ptr++ = *yytext;



<STRING_STATE>"\\n" 	*string_buf_ptr++ = '\n';

<STRING_STATE>"\\t" 	*string_buf_ptr++ = '\t';

<STRING_STATE>"\\b" 	*string_buf_ptr++ = '\b';

<STRING_STATE>"\\f" 	*string_buf_ptr++ = '\f';
<STRING_STATE>\\(.|\n) *string_buf_ptr++ = yytext[1];

<STRING_ERROR_STATE>[\n"]	BEGIN(INITIAL);

<STRING_ERROR_STATE>[^\n"]	;

.		{
			cool_yylval.error_msg = yytext;
			return ERROR;
		}





%%