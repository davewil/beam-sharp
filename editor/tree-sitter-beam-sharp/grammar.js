/**
 * beam-sharp — a Tree-sitter grammar.
 *
 * Transcribed from `compiler/src/bs_parser.yrl` and `compiler/src/bs_lexer.xrl`,
 * which remain the source of truth. This is a second parser for the same
 * language and it will drift; `editor/bin/check-tokens.sh` gates the token half
 * of that, and the corpus test below gates the rest — every `.bs` file in the
 * repository must parse with no ERROR node.
 *
 * WHY A SECOND PARSER IS WORTH IT HERE, GIVEN THE REPO DESIGNS DUPLICATES AWAY
 * A regex grammar cannot tell `list<int>` from `a < b`, because they are the
 * same characters and the compiler distinguishes them POSITIONALLY — a bracket
 * in type position, a comparison in value position (ticket 28, pinned by F6.9).
 * Only something that actually parses can get that right, and getting it right
 * is the difference between highlighting that helps and highlighting that lies.
 *
 * The same argument applies to the other place a regex must guess: a type and a
 * function are the same token class (PascalCase, ticket 27 §4), so `Order` and
 * `Describe` are indistinguishable to a lexer. This grammar knows which
 * production it is in, so it can label them apart.
 *
 * PRECEDENCE mirrors the yecc table verbatim, including the two that are not
 * arithmetic: `with` binds tighter than any operator, and `switch` tighter
 * still — which is C#'s own reading, where a switch expression's subject is a
 * range expression, so `a + b switch { … }` is `a + (b switch { … })`.
 */

const PREC = {
  bind: 50,
  or: 100,
  and: 200,
  compare: 300,
  add: 400,
  multiply: 500,
  with: 600,
  switch: 700,
};

module.exports = grammar({
  name: 'beam_sharp',

  extras: $ => [/\s/, $.comment],

  word: $ => $.lident,

  // THE AMBIGUITIES ARE THE YECC GRAMMAR'S OWN, and this is where a GLR parser
  // earns its place. `bs_parser.yrl` records that `binding -> pattern '=' expr`
  // reports TWELVE reduce/reduce conflicts — measured, not feared — because
  // yecc has one token of lookahead and every pattern form shares its first
  // token with an expression form: after `(` nothing can tell `(a, b) = pair`
  // from the tuple `(a, b)`. The compiler's escape is to parse the wider
  // language and narrow afterwards, which is what Erlang itself does.
  //
  // Tree-sitter does not need the escape. It explores both interpretations and
  // keeps whichever survives, so the two node types stay distinct in the tree
  // and a highlighter can colour a pattern differently from an expression.
  // Exactly two, and the generator rejects any more as unnecessary — which is a
  // measurement worth keeping: the surface's pattern/expression overlap is
  // narrower than the twelve conflicts suggest, and it lives entirely in the
  // two forms that nest (a tuple's contents and a list's).
  conflicts: $ => [
    [$.pattern, $._expression],
    [$.list_pattern, $.list],
  ],

  rules: {
    source_file: $ => repeat($._declaration),

    comment: _ => token(seq('//', /[^\n]*/)),

    // --- declarations --------------------------------------------------------
    _declaration: $ => choice(
      $.module_declaration,
      $.type_alias,
      $.record_declaration,
      $.behaviour_declaration,
      $.foreign_declaration,
      $.import_declaration,
      $.signature,
      $.clause,
    ),

    // F11 — the module's atom is its full dotted path (ticket 40 §1).
    module_declaration: $ => seq('module', field('name', $.module_path)),

    // Shared by the module declaration, the native `using`, and the qualified
    // call site. Left-recursive for the same reason the compiler's rule is:
    // right recursion makes `List.Map(x)` unparseable, because the recursive arm
    // takes the whole path and leaves no function name behind.
    module_path: $ => prec.left(seq($.uident, repeat(seq('.', $.uident)))),

    // `using Shop.Orders` — ticket 41 §1. The same keyword as the foreign form
    // below, told apart by the token class of what follows: a uident path
    // declares a B# dependency, an atom attaches types to Erlang's own name.
    import_declaration: $ => seq('using', field('module', $.module_path)),

    behaviour_declaration: $ => seq(
      choice('behaviour', 'behavior'),
      field('name', $.uident),
    ),

    // Ticket 09: `type X = ...` is the single naming construct. The parametric
    // form binds a variable that is gone before the algebra sees it (27 §b).
    type_alias: $ => seq(
      'type',
      field('name', $.uident),
      optional(seq('<', commaSep1($.type_parameter), '>')),
      '=',
      field('body', $.type_expression),
      optional($.refinement),
    ),

    // F2 / ticket 20 §5 — `type Octet = int where value >= 0 and value <= 255`.
    // `where` was already a keyword, so `check-tokens.sh` was satisfied while no
    // rule in this file consumed it.
    refinement: $ => seq('where', $._refinement_test,
                         repeat(seq('and', $._refinement_test))),

    _refinement_test: $ => seq(
      'value',
      choice('>=', '<=', '>', '<', '==', '!='),
      $.integer,
    ),

    type_parameter: $ => $.uident,

    // Ticket 26 §1: a record erases to a map carrying a minted tag.
    record_declaration: $ => seq(
      'record',
      field('name', $.uident),
      '{', commaSep1($.field_declaration), '}',
    ),

    field_declaration: $ => seq(
      field('name', $.uident),
      ':',
      field('type', $.type_expression),
    ),

    // On the BEAM a module IS an atom, so the module is written as one.
    foreign_declaration: $ => seq(
      'using',
      field('module', $.atom),
      '{', repeat1($.foreign_signature), '}',
    ),

    foreign_signature: $ => seq(
      field('return', $.type_prim),
      field('name', $.lident),
      '(', optional(commaSep1($.parameter)), ')',
    ),

    // --- types ---------------------------------------------------------------
    type_expression: $ => prec.right(seq(
      $.type_prim,
      repeat(seq('|', $.type_prim)),
    )),

    // The generic bracket. In TYPE position nothing compares, so this is
    // unambiguous and costs no lookahead — which is the whole of ticket 28's
    // finding and the reason this grammar can colour it correctly where a
    // regex cannot.
    type_prim: $ => choice(
      $.atom,
      $.generic_type,
      $.builtin_type,
      $.type_identifier,
      seq('(', commaSep1($.type_expression), ')'),
      seq('{', commaSep1($.field_declaration), '}'),
    ),

    generic_type: $ => seq(
      field('name', choice($.builtin_type, $.type_identifier)),
      '<', commaSep1($.type_expression), '>',
    ),

    // Lowercase is the builtin/prelude namespace; PascalCase is a user type.
    builtin_type: $ => $.lident,
    type_identifier: $ => $.uident,

    // --- signatures ----------------------------------------------------------
    // Ticket 04's binding constraint: exhaustiveness is only well posed against
    // a declared input type, so a multi-clause function must carry a signature.
    signature: $ => seq(
      field('return', $.type_prim),
      field('name', $.function_name),
      '(', optional(commaSep1($.parameter)), ')',
    ),

    parameter: $ => seq(
      field('type', $.type_prim),
      optional(field('name', $.lident)),
    ),

    // --- clauses -------------------------------------------------------------
    // THE ONE STRUCTURAL MOVE: N clause heads in the parameter position.
    clause: $ => seq(
      field('name', $.function_name),
      '(', optional(commaSep1($.pattern)), ')',
      optional($.guard),
      '->',
      field('body', $.body),
    ),

    guard: $ => seq('when', $._expression),

    // A body is zero or more bindings followed by one expression (ticket 34).
    body: $ => prec.right(seq(repeat($.binding), $._expression)),

    // F8 made `var` the token that BINDS and left a bare `=` meaning match, and
    // this rule never gained it — so every `var x = …` and `var (lo, hi) = …` in
    // the corpus was an ERROR node.
    binding: $ => prec.right(PREC.bind, seq(
      optional('var'),
      field('left', $._bind_target),
      '=',
      field('right', $._expression),
    )),

    // The left of `=` is narrowed to a pattern in the compiler's parser action;
    // here the narrower set is written directly, which is what a grammar for
    // READING the language wants.
    _bind_target: $ => choice(
      $.variable,
      $.wildcard,
      $.tuple_pattern,
      $.list_pattern,
    ),

    // --- patterns ------------------------------------------------------------
    pattern: $ => choice(
      $.integer,
      $.atom,
      $.boolean,
      $.variable,
      $.wildcard,
      $.tuple_pattern,
      $.record_pattern,
      $.list_pattern,
      $.match_pattern,
      $.relational_pattern,
    ),

    // Ticket 45 — `== head` matches against the value a name already holds
    // rather than binding a new one. Elixir spends `^` on this capability.
    match_pattern: $ => seq('==', field('name', $.lident)),

    // Ticket 42 — a span in a clause head is a RELATIONAL pattern. `4..7` was
    // refused: C#'s `..` is a half-open index slice that already means "the
    // rest" in pattern position.
    relational_pattern: $ => prec.left(seq(
      choice('>=', '<=', '>', '<'),
      $.integer,
      repeat(seq('and', choice('>=', '<=', '>', '<'), $.integer)),
    )),

    tuple_pattern: $ => seq('(', commaSep1($.pattern), ')'),

    // A property pattern is OPEN: it constrains the fields it names and says
    // nothing about the rest, which is what lets one clause cover a record by
    // naming only its tag.
    record_pattern: $ => seq('{', commaSep1($.field_pattern), '}'),

    field_pattern: $ => seq(
      field('name', $.field_name),
      ':',
      field('pattern', $.pattern),
    ),

    // Ticket 08 settled prefix-plus-rest only.
    list_pattern: $ => seq(
      '[',
      optional(seq(
        commaSep1($.pattern),
        optional(seq(',', $.rest_pattern)),
      )),
      optional($.rest_pattern),
      ']',
    ),

    rest_pattern: $ => seq('..', $.pattern),

    // --- expressions ---------------------------------------------------------
    _expression: $ => choice(
      $.integer,
      $.atom,
      $.boolean,
      $.variable,
      $.wildcard,
      $.call,
      $.foreign_call,
      $.qualified_call,
      $.string,
      $.tuple,
      $.record_construction,
      $.record_update,
      $.projection,
      $.list,
      $.binary_expression,
      $.switch_expression,
    ),

    call: $ => seq(
      field('function', $.function_name),
      '(', optional(commaSep1($._expression)), ')',
    ),

    // `:ets.lookup(t, k)` — an atom literal on the left, so no variable and no
    // casing convention is involved in telling this from a projection.
    foreign_call: $ => seq(
      field('module', $.atom),
      '.',
      field('function', $.lident),
      '(', optional(commaSep1($._expression)), ')',
    ),

    // `List.Map(xs)` — a uident path on the left, which is the third and last of
    // the dot-forms. `lident` projects a field, `atom` calls Erlang, `uident`
    // calls a B# module.
    qualified_call: $ => prec(1, seq(
      field('module', $.module_path),
      '.',
      field('function', $.uident),
      '(', optional(commaSep1($._expression)), ')',
    )),

    tuple: $ => seq('(', commaSep1($._expression), ')'),

    record_construction: $ => seq(
      field('name', $.type_identifier),
      '{', commaSep1($.field_assignment), '}',
    ),

    // Width-preserving update (ticket 26 §2). Not spread — §2 refused it.
    record_update: $ => prec.left(PREC.with, seq(
      $._expression,
      'with',
      '{', commaSep1($.field_assignment), '}',
    )),

    field_assignment: $ => seq(
      field('name', $.field_name),
      '=',
      field('value', $._expression),
    ),

    // The dot PROJECTS and is never a call — ticket 17 narrowed it to this. The
    // disambiguation is lexical: a lowercase receiver is a value, a PascalCase
    // one is a module.
    projection: $ => seq(
      field('record', $.lident),
      '.',
      field('field', $.field_name),
    ),

    list: $ => seq(
      '[',
      optional(seq(
        commaSep1($._expression),
        optional(seq(',', $.rest_expression)),
      )),
      optional($.rest_expression),
      ']',
    ),

    rest_expression: $ => seq('..', $._expression),

    binary_expression: $ => {
      const table = [
        // TICKET 44 REMOVED `&&` and `||` — not aliased, removed — and this
        // table still had them. `check-tokens.sh` could not catch it: `and` and
        // `or` ARE keywords in the lexer, so its "every keyword appears in both
        // grammars" test passed while nothing in this file USED them. A rule can
        // be present and wrong, which that gate's own header says it does not
        // check.
        [PREC.or, 'or', 'left'],
        [PREC.and, 'and', 'left'],
        [PREC.compare, choice('==', '!=', '<', '>', '<=', '>='), 'left'],
        [PREC.add, choice('+', '-'), 'left'],
        [PREC.multiply, '*', 'left'],
      ];
      return choice(...table.map(([p, op, _assoc]) =>
        prec.left(p, seq(
          field('left', $._expression),
          field('operator', op),
          field('right', $._expression),
        )),
      ));
    },

    // --- switch (ticket 17 §6, F7) -------------------------------------------
    // The clause head's pattern grammar in expression position, so `pattern`
    // below is the same nonterminal a clause head uses rather than a copy.
    switch_expression: $ => prec.left(PREC.switch, seq(
      field('subject', $._expression),
      'switch',
      '{', commaSep1($.switch_arm), '}',
    )),

    // An arm's body is a single expression: arms are comma-separated and a body
    // is bindings-then-expression with no terminator, so the two cannot be told
    // apart. Deliberate, and recorded in F7's out-of-scope.
    switch_arm: $ => seq(
      field('pattern', $.pattern),
      optional($.guard),
      '=>',
      field('body', $._expression),
    ),

    // --- terminals -----------------------------------------------------------
    // A function and a type are the SAME token class. Splitting them into two
    // named nodes is the thing a Tree-sitter grammar can do and a regex cannot,
    // and it is decided here by which production we are in.
    function_name: $ => $.uident,
    field_name: $ => $.uident,

    variable: $ => $.lident,
    wildcard: _ => '_',

    // The two keyword atoms. Bare, and NOT variables — as identifiers they
    // would match everything in pattern position, which is precisely the defect
    // F7 found in the lexer.
    boolean: _ => choice('true', 'false'),

    atom: _ => token(choice(
      /:[a-z][a-zA-Z0-9_]*/,
      // Quoted, for what the bare sigil cannot spell — a record's minted tag
      // is `:'Shop.Order'`.
      /:'[^']*'/,
    )),

    integer: _ => /[0-9]+/,

    // F9 shipped strings on 2026-08-15 and this rule never followed, so
    // `check-corpus.sh` has rejected `label.bs` ever since — the grammar
    // refusing source the compiler accepts, which is the one thing that gate
    // exists to catch. The gate is not in CI, which is why it could rot.
    string: _ => token(seq('"', repeat(choice(/[^"\\]/, seq('\\', /./))), '"')),

    uident: _ => /[A-Z][a-zA-Z0-9_]*/,
    lident: _ => /[a-z][a-zA-Z0-9_]*/,
  },
});

function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}
