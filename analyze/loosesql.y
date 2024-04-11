%{

#include <cstdio>
#include <iostream>
#include <stdio.h>
#include <string>
#include <getopt.h>
#include <sstream>
#include <vector>
#include <map>

#include "loosetree.cpp"

// stuff from flex that bison needs to know about:
extern int yylex();
extern int yyparse();
extern FILE *yyin;

void yyerror(const char *s);

struct option long_options[] = {
    {"input-file",     0, 0,  'i' },
    {"help",     0, 0,  'h' },
    { NULL, 0, NULL, 0 }
};

std::map<const char*, char> option_map;

struct Node *root;


void debug_print(const char *s) {
    std::stringstream ss;
    ss << s;
    std::cout << ss.str() << std::endl;
}

void debug_print(std::stringstream &ss) {
    std::cout << ss.str() << std::endl;
}

void debug_print(Node *n, const char* desc) {
    std::stringstream ss;
    ss << desc << " at: " << n << " STR: " << n->to_string();
    std::cout << ss.str() << std::endl;
}

%}

%union YYSTYPE {
    std::string*    str_val;
    struct Node*    node;
  };

%define parse.error verbose


%debug
%start start_symbol

%token UPDATE ORDER_BY UNION_ALL WHERE AS FROM SELECT BETWEEN IS NOT _NULL WITH CASE WHEN END ELSE THEN FULL OUTER INNER JOIN CROSS LEFT RIGHT ON
%token<str_val> _ID CONST_STR BOOL_LOGIC NA_OPERATOR L_OPERATOR

%type<node> a_expr select_stmnt expr_list b_expr whens joins join_expr cte_stmnt with_tabs cte_inner

%left BOOL_LOGIC
%nonassoc NA_OPERATOR

%left L_OPERATOR
%right NOT
%right '-'

%%
start_symbol:
                | select_stmnt ';' { root = $1; }
                | cte_stmnt ';' { root = $1; }

b_expr:         a_expr
                | a_expr AS _ID { $1->str_alias = std::string(*$3);  delete $3; $$ = $1; }
                | a_expr _ID { $1->str_alias = std::string(*$2); delete $2; $$ = $1; }


a_expr:         _ID { $$ = (Node *) new Expr(std::string(*$1)); delete $1; debug_print($$, "Create Expr"); }
                | _ID '(' expr_list ')' { $$ = (Node*) new Func(std::string(*$1), $3); delete $1; }
                | CONST_STR { $$ = (Node *) new Expr(std::string(*$1)); delete $1;  debug_print($$, "Create Expr"); }
                | _ID '.' _ID { $$ = (Node *) new QualExpr(std::string(*$1), std::string(*$3)); delete $1;  delete $3;  }
                | '(' a_expr ')' { $$ = $2; }
                | '(' select_stmnt ')' { $$ = $2;}
                | '(' cte_stmnt ')' {$$ = $2; }
                | a_expr NA_OPERATOR a_expr { $$ = new Op(std::string(*$2), $1, $3); delete $2; debug_print($$, "Created OP");}
                | a_expr BOOL_LOGIC a_expr { $$ = new Op(std::string(*$2), $1, $3); delete $2; debug_print($$, "Created BOOL");}
                | a_expr L_OPERATOR a_expr { $$ = new Op(std::string(*$2), $1, $3); delete $2; debug_print($$, "Created OP");}
                | a_expr '-' a_expr { $$ = new Op(std::string("-"), $1, $3); }
                | NOT a_expr { $$ = $2; $2->set_flags(NF_NOT);}
                | '-' a_expr { $$ = $2; $2->set_flags(NF_NEGATED);}
                | CASE whens END { $$ = new Case($2, NULL);  debug_print($$, "Created CASE (no else) ");}
                | CASE whens ELSE a_expr END { $$ = new Case($2, $4);  debug_print($$, "Created CASE w/ else");}

whens:          WHEN a_expr THEN a_expr { $$ = (Node*) new WhenList($2, $4); }
                | whens WHEN a_expr THEN a_expr {((WhenList*) $1)->add_when($3, $5);}

cte_stmnt:      WITH with_tabs select_stmnt  { ((CTE*)$2)->set_select($3); $$ = $2; }

cte_inner:       '(' cte_stmnt ')' {$$ = $2; }
                | '(' select_stmnt ')' { $$ = $2;}

with_tabs:      _ID AS cte_inner { $$ = (Node*) new CTE($3, std::string(*$1)); delete $1; }
                | with_tabs ',' _ID AS cte_inner { ((CTE*)$1)->add_tab($5, std::string(*$3)); delete $3; }


select_stmnt:     SELECT expr_list { $$ = (Node*) new Select($2, NULL, NULL); }
                | SELECT expr_list FROM expr_list { $$ = (Node*) new Select($2, $4, NULL); }
                | SELECT expr_list FROM expr_list WHERE a_expr { $$ = (Node*) new Select($2, $4, $6); }
                | SELECT expr_list FROM joins { $$ = (Node*) new Select($2, $4, NULL); }
                | SELECT expr_list FROM joins WHERE a_expr { $$ = (Node*) new Select($2, $4, NULL); }

joins:          b_expr join_expr b_expr ON a_expr { ((Join*)$2)->set_exprs($1, $3, $5); $$ = $2; }
join_expr:      JOIN { $$ = (Node*) new Join("INNER");}
                | LEFT JOIN { $$ = (Node*) new Join("LEFT OUTER");}
                | LEFT OUTER JOIN { $$ = (Node*) new Join("LEFT OUTER");}
                | RIGHT JOIN { $$ = (Node*) new Join("RIGHT OUTER");}
                | RIGHT OUTER JOIN { $$ = (Node*) new Join("RIGHT OUTER");}
                | FULL OUTER JOIN { $$ = (Node*) new Join("FULL OUTER");}
                | INNER JOIN { $$ = (Node*) new Join("INNER");}

expr_list:
                expr_list ',' b_expr
                {
                    // std::stringstream ss;
                    // ss << "Extending ExprList Node ("<<$1<<")..." << ((ExprList*)$1)->to_string() << " Passing in " << $3 << std::endl;
                    // debug_print(ss);
                    ((ExprList*) $1)->addExpr((Expr*)$3);
                    $$ = (Node*) $1;
                }
                | b_expr
                {
                    ExprList *el = (ExprList*) new ExprList();
                    // std::stringstream ss;
                    // ss << "Creating new ExprList Node ("<<el<<") for single expr ("<<$1<<") " << el->to_string() << std::endl;
                    // debug_print(ss);
                    el->addExpr((Expr*)$1);
                    $$ = (Node*)el;
                }

%%



int main(int argc, char** argv) {
    for (int i = 0; i < 2; i++) {
        option_map[long_options[i].name] = long_options[i].val;
    }
    int long_opt_index = 0;
    int c, opt;
    char *in_file = NULL;
    while ((c = getopt_long(argc, argv, "hi", long_options, &long_opt_index)) != -1) {
            opt = c;
            if (c == 0) {
                const char* lo = long_options[long_opt_index].name;
                opt = option_map[lo];
            }
            switch (opt) {
                case 'h':
                    printf("Usage: TBD \n");
                    exit(0);
                    break;
                case 'i':
                    in_file = argv[optind];
                    printf("Using input file: %s", in_file);
                default:
                    printf("%d\n", c);
                    break;
            }
    }

    if (in_file != NULL) {
      FILE *myfile = fopen(in_file, "r");
      if (!myfile) {
          std::cerr << "I can't open " << argv[optind] << std::endl;
          return -1;
      }
      yyin = myfile;
    }
    else {
      std::cout << "No file supplied - read stdin" << std::endl;
      yyin = stdin;
    }

  // parse through the input until there is no more:
  //do {
    yyparse();

    std::cout << "Parsed without errors!" << std::endl;
    print_loose(root, 0);
  //} while (!feof(yyin));
}

void yyerror(const char *s) {
  std::cout << "Parse error message: " << s << std::endl;
  exit(-1);
}
