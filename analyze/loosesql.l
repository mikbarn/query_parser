%{

    #include <string>
    #include <iostream>
    #include "loosesql.tab.h"

  bool debug = true;

  void debuglex_tokens(const char* txt, const char* val) {
    if (debug == true) {
      std::cout << txt << " " << val << std::endl;
    }
  }

%}
id_a [a-zA-Z_][a-zA-Z0-9_]*
id {id_a}|\"{id_a}\"
ints [0-9]+
dec {ints}\.{ints}
num {ints}|{dec}
ws [ \t\n]+
na_opr \<|\>|=|!=|\<\>
l_opr \+|\/

%%
{ws}            ;
(?i:select)             {return SELECT;}
(?i:from)               {return FROM;}
(?i:as)                 {return AS;}
(?i:and)|(?i:or)        {yylval.str_val = new std::string(yytext); return BOOL_LOGIC;}
(?i:null)               {return _NULL;}
(?i:between)            {return BETWEEN;}
(?i:is)                 {return IS;}
(?i:not)                {return NOT;}
(?i:with)               {return WITH;}
(?i:update)             {return UPDATE;}
(?i:where)              {return WHERE;}
(?i:case)               {return CASE;}
(?i:when)               {return WHEN;}
(?i:end)                {return END;}
(?i:else)               {return ELSE;}
(?i:then)               {return THEN;}
(?i:full)               {return FULL;}
(?i:outer)              {return OUTER;}
(?i:inner)              {return INNER;}
(?i:cross)              {return CROSS;}
(?i:JOIN)               {return JOIN;}
(?i:on)                 {return ON;}
(?i:left)               {return LEFT;}
(?i:right)              {return RIGHT;}
\-                      {return '-';}
{na_opr}                {yylval.str_val = new std::string(yytext); debuglex_tokens("Got an operator!", yytext); return NA_OPERATOR;}
{l_opr}                 {yylval.str_val = new std::string(yytext); debuglex_tokens("Got an operator!", yytext); return L_OPERATOR;}
;*                      {return ';';}
,                       {return ',';}
\.                      {return '.';}
\(                      {return '(';}
\)                      {return ')';}
{id}                    {yylval.str_val = new std::string(yytext); return _ID;}
\'[^\']*\'              {yylval.str_val = new std::string(yytext); return CONST_STR;}
{num}                   {yylval.str_val = new std::string(yytext); return CONST_STR;}


%%
