# Audit Trail Query Parser (Prototype)

A low-level log parser designed to extract unique SQL queries from system logs (such as Talend outputs) and compile them into visual ASTs (Abstract Syntax Trees). The long-term goal of this project is to automate column-level dependency tracking and build data compliance audit trails.

## Project Structure

├── rough_pass.py        # Log scanner that extracts and isolates unique SQL queries.
└── analyze/             # Lexer, parser, and tree generation core.
├── loosetree.l      # Flex lexical analyzer specification.
├── loosetree.y      # Yacc grammar rules for parsing query structure.
└── loosetree.cpp    # AST generation core and parser execution.

## How It Works
1. **Extraction:** `rough_pass.py` acts as a high-throughput pre-filter, sweeping large system logs to deduplicate and isolate the target queries.
2. **Lexing & Parsing:** The isolated queries are fed into the Flex (`.l`) and Yacc (`.y`) pipeline to tokenize the SQL dialect and enforce grammar rules.
3. **AST Generation:** The C++ backend compiles these tokens into a temporary parse tree (`loosetree.cpp`) for structural inspection.

## Current State & Next Steps
The front-end compiler mechanics (lexing, parsing, and base tree generation) are fully functional. The next phase of development will focus on traversing the generated syntax trees to map data lineages and detect column-level transformations automatically.
