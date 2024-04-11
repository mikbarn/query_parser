#ifndef _LOOSE_TREE_CPP
#define _LOOSE_TREE_CPP
#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include <string>
#include <sstream>
#include <iostream>
#include <map>
#include <tuple>

enum NodeType {
    NT_NONE,
    NT_SELECT,
    NT_EXPR,
    NT_EXPR_LIST,
    NT_QUAL_EXPR,
    NT_OPERATOR,
    NT_CASE,
    NT_WHENLIST,
    NT_JOIN,
    NT_CTE,
    NT_FUNC
};

enum ExprType {
    ET_CONST,

};
enum NodeFlags {
    NF_NEGATED = 1,
    NF_NOT = 2,
    NF_END = 4
};


struct Node {
    const static std::map<NodeType, const char*> node_types;
    NodeType node_type = NT_NONE;
    std::string str_value = std::string("N/A");
    std::string str_alias = std::string("");
    Node *parent = NULL;
    int flags = 0;
    virtual std::string to_string() {
        std::stringstream ss;
        ss << "Node (type='" << get_type_str() << "') value='" << get_val() << "'";
        if (!str_alias.empty()) {
            ss << " Alias: " << str_alias;
        }
        return ss.str();
    }

    virtual std::string get_val() {
        return str_value;
    }

    virtual NodeType get_type() {
        return node_type;
    }

    virtual std::string get_type_str() {
        if (node_types.count(node_type) > 0) {
            return node_types.at(node_type);
        }
        return "N/A";
    }

    virtual void set_flags(int new_flags) {
        flags |= new_flags;
    }

    virtual void own(Node *n) {
        if (n!=NULL) {
            n->parent = this;
        }
    }

};
const std::map<NodeType, const char*> Node::node_types = {{NT_NONE, "N/A"}, {NT_SELECT, "SELECT"}, {NT_EXPR, "EXPR"},
{NT_EXPR_LIST, "EXPR_LIST"}, {NT_QUAL_EXPR, "QUAL_EXPR"}, {NT_OPERATOR, "OPERATOR"}, {NT_CASE, "CASE"}, {NT_WHENLIST, "WHEN_LIST"},
{NT_JOIN, "JOIN"}, {NT_CTE, "CTE"}, {NT_FUNC, "FUNCTION"}};


struct Op: Node {
    bool is_unary = false;
    Node *left, *right;
    Op(std::string operator_name, Node* lhs, Node *rhs) {
        str_value = operator_name;
        node_type = NT_OPERATOR;
        if (lhs == NULL){
            is_unary = true;
        }
        else {
            left = lhs;
        }
        right = rhs;
        own(left);
        own(right);
    }
};

struct Expr : Node {
    Expr() {
        node_type = NT_EXPR;
    }
    ExprType e_type;
    Expr(std::string val) {
        str_value = val;
        node_type = NT_EXPR;
    }
};

struct QualExpr: Node
{
    std::string qualifier;
    QualExpr() {
        node_type = NT_QUAL_EXPR;
    }
    QualExpr(std::string val) {
        int dot_loc = val.find(".");
        qualifier = val.substr(0, dot_loc);
        str_value = val.substr(dot_loc+1, val.size());
        node_type = NT_QUAL_EXPR;
    }
    QualExpr(std::string val1, std::string val2) {
        // std::cout << "v1 " << val1 << " v2 " << val2 << std::endl;
        qualifier = val1;
        str_value = val2;
        node_type = NT_QUAL_EXPR;
    }
    std::string get_val() {
        return "(qualifier='" + qualifier + "')." + str_value;
    }
};


struct ExprList: Node {
    std::vector<Expr*> exprs = std::vector <Expr*>();
    ExprList() {
        node_type = NT_EXPR_LIST;
    }
    void addExpr(Expr *ex) {
        exprs.push_back(ex);
        own(ex);
    }
};

struct Select : Node {
    ExprList *exprs;
    Node *from;
    Expr *where;
    bool implicit_join = false;
    Select(Node *expression_list, Node *from_clause, Node *where_clause) {
        exprs = (ExprList *) expression_list;
        from =  (Node *) from_clause;
        where = (Expr *) where_clause;
        node_type = NT_SELECT;

        if (from_clause != NULL) {
            NodeType nt = from_clause->node_type;
            if (nt == NT_EXPR_LIST) {
                implicit_join = true;
            }
        }
        own(exprs);
        own(from);
        own(where);
    }
};

struct WhenList: Node {
    std::vector<std::tuple<Expr*, Expr*>> when_list = std::vector<std::tuple<Expr*, Expr*>>();
    WhenList(Node *_if, Node *_then) {
        node_type = NT_WHENLIST;
        add_when(_if, _then);
    }
    void add_when(Node *_if, Node *_then) {
        std::tuple<Expr*, Expr*> another = {(Expr*)_if, (Expr*)_then};
        when_list.push_back(another);
        own(_if);
        own(_then);
    }
};

struct Case:Node {
    Expr *default_else;
    WhenList *whens;
    Case(Node *when_list, Node *def) {
        node_type = NT_CASE;
        default_else = (Expr*)def;
        whens = (WhenList*)when_list;
        own(when_list);
        own(def);
    }
};

struct Join: Node {
    std::string join_type = std::string("INNER");
    Expr *left, *right, *on_clause;
    Join(std::string actual_type) {
        node_type = NT_JOIN;
        join_type = actual_type;
        str_value = actual_type;
    }
    void set_exprs(Node *lhs, Node *rhs, Node *ons) {
        own(lhs);
        own(rhs);
        own(ons);
        if (lhs != NULL) {
            left = (Expr*)lhs;
        }
        if (rhs != NULL) {
            right = (Expr*)rhs;
        }
        if (ons != NULL) {
            on_clause = (Expr*)ons;
        }
    }
};

struct Func: Node {
    std::string name;
    ExprList* params;
    Func(std::string func_name, Node* func_params) {
        node_type = NT_FUNC;
        name = func_name;
        str_value = func_name;
        params = (ExprList*) func_params;
        own(func_params);
    }
};

struct CTE: Node {
    Select *select;
    std::vector<Node*> common_tabs = std::vector<Node*>();

    CTE(Node* first_cte, std::string alias) {
        node_type = NT_CTE;
        add_tab(first_cte, alias);
    }
    void set_select(Node *n) {
        select = (Select*)n;
        own(n);
    }
    void add_tab(Node* n, std::string alias) {
        own(n);
        n->str_alias = alias;
        common_tabs.push_back(n);
    }
};




void print_loose(Node* root, int level) {
    if (level > 10) {
        printf("Fatal error!\n");
        exit(-1);
    }
    std::stringstream ss;
    for (int i = 0; i < level; i++) {
        ss << "    ";
    }
    // std::cout << ss.str() << "Got a Node: " << root <<  std::endl;
    if (root == NULL) {
        return;
    }
    std::cout << ss.str() << root->to_string() << std::endl;
    int nt = root->node_type;

    if (nt == NT_EXPR_LIST) {
        ExprList *el = (ExprList *) root;
        for (int i = 0; i < el->exprs.size(); i++) {
            print_loose((Node*)el->exprs[i], level+1);
        }
    }
    else if (nt == NT_SELECT) {
        Select *r = (Select*)root;
        std::cout << ss.str() << "--- SELECT EXPR LIST ---" << std::endl;
        print_loose(r->exprs, level+1);
        std::cout << ss.str() << "--- SELECT FROM LIST --- " << std::endl;
        print_loose(r->from, level+1);
        if (r->where != NULL) {
            std::cout << ss.str() << "--- SELECT WHERE CLAUSE ---" << std::endl;
            print_loose(r->where, level+1);
        }
    }
    else if (nt == NT_CTE) {
        CTE* cte = (CTE*)root;
        for(int i = 0; i < cte->common_tabs.size(); i++) {
            std::cout << ss.str() << "--- CTE TAB ---" << std::endl;
            print_loose(cte->common_tabs.at(i), level+1);
        }
        std::cout << ss.str() << "--- CTE SELECT ---" << std::endl;
        print_loose(cte->select, level+1);
    }
    else if (nt == NT_OPERATOR) {
        Op* op = (Op*)root;
        if (!op->is_unary) {
            std::cout << ss.str() << "--- OP LHS ---" << std::endl;
            print_loose(op->left, level+1);
        }
        std::cout << ss.str() << "--- OP RHS ---" << std::endl;
        print_loose(op->right, level+1);
    }
    else if (nt == NT_JOIN) {
        Join* jn = (Join*)root;
        std::cout << ss.str() << "--- JOIN LHS ---" << std::endl;
        print_loose(jn->left, level+1);
        std::cout << ss.str() << "--- JOIN RHS ---" << std::endl;
        print_loose(jn->right, level+1);
        std::cout << ss.str() << "--- JOIN ON ---" << std::endl;
        print_loose(jn->on_clause, level+1);
    }
    else if (nt == NT_CASE) {
        Case* cs = (Case*)root;
        std::cout << ss.str() << "--- CASE WHEN LIST ---" << std::endl;
        for (int i = 0; i < cs->whens->when_list.size(); i++) {
            Expr* _if = std::get<0>(cs->whens->when_list[i]);
            Expr* _then = std::get<1>(cs->whens->when_list[i]);
            std::cout << ss.str() << "--- WHEN ---" << std::endl;
            print_loose((Node*)(_if), level+1);
            std::cout << ss.str() << "--- THEN ---" << std::endl;
            print_loose((Node*)(_then), level+1);
        }
        if (cs->default_else != NULL) {
            std::cout << ss.str() << "--- CASE DEFAULT ---" << std::endl;
            print_loose((Node*)cs->default_else, level+1);
        }
    }
    else if (nt == NT_FUNC) {
        Func* f = (Func*)root;
        std::cout << ss.str() << "--- FUNCTION EXPR LIST ---" << std::endl;
        print_loose(f->params, level+1);
    }
    else if (nt == NT_EXPR) {
        return;
    }
}

#endif