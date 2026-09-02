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
  pipe: 350,
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
    // F20 — the rest MARKER may bind (`..t`) or be anonymous (`..` / `.._`),
    // and the expression side still spreads an arbitrary expression, so `[.._]`
    // is a pattern rest or an expression rest depending on where it sits. Same
    // pattern/expression overlap as the pair above, one level down.
    [$.rest_pattern, $._expression],
    // F15 — `Shop.Collections.List.Sum(…)`. Where the module path stops and the
    // function name starts is not decidable one token at a time; see the note on
    // `module_path`.
    [$.module_path],
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
    //
    // `prec.left` USED TO BE HERE AND IT WAS F11's BUG WEARING THE OTHER FACE.
    // At `Shop.Collections.List` with `.Sum(` ahead, `prec.left` says "extend",
    // so the path swallowed the function name and `Fully(n) ->
    // Shop.Collections.List.Sum([n], 0)` was an ERROR node. One dot worked,
    // which is why nothing caught it: `List.Map(x)` needs no decision. Deciding
    // it needs two tokens of lookahead — the uident AND whether a `(` follows —
    // and that is precisely what a GLR parser is for, so the conflict is
    // declared at the top of this file and both readings are explored.
    module_path: $ => seq($.uident, repeat(seq('.', $.uident))),

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
    // F12 / ticket 40 §3, amended 2026-08-17: optional here because it is
    // optional in the language — an unmarked signature is private. It was
    // already optional before the amendment, for a different reason, which is
    // why nothing in this file had to change.
    signature: $ => seq(
      optional(field('visibility', $.visibility)),
      field('return', $.type_prim),
      field('name', $.function_name),
      '(', optional(commaSep1($.parameter)), ')',
    ),

    visibility: $ => choice('public', 'private'),

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
      // F9 added the `string` TOKEN and never added it here, so a string
      // literal in a clause head — `Method("GET") -> :get`, which is F9's own
      // worked example — did not parse. It was invisible until the binary rule
      // above landed, because `frame.bs` failed thirty lines earlier and the
      // corpus gate reports the first error per file. A front wall hides every
      // wall behind it; that is the same reason `FRONTIER` says so out loud.
      $.string,
      $.atom,
      $.boolean,
      $.variable,
      $.wildcard,
      $.tuple_pattern,
      $.record_pattern,
      $.typed_binder_pattern,
      $.list_pattern,
      $.match_pattern,
      $.relational_pattern,
      $.binary_pattern,
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
    //
    // Ticket 55 / F22 — THE TYPE PREFIX AND THE TRAILING BINDER. `bs_parser.yrl`
    // has four productions beside the bare property pattern, mirrored here as
    // two optionals rather than written from the decision:
    //
    //   Order { Id: 1 }      the prefix mints the tag the bare form spells out
    //   Order { Id: 1 } o    ... with a binder over the whole value
    //   Order o              a type and a name, no fields — a parameter's shape
    //   { Id: 1 } o          the bare pattern with a binder
    //
    // The binder is a bare trailing name with no keyword: `as` is the checked
    // conversion and `=` introduces a body binding. It hangs off THESE forms
    // only, exactly as the yecc grammar has it, not off `pattern` at large.
    //
    // This rule lagged the compiler by fifteen days. F22 shipped 2026-08-19
    // and no example used the prefix until ENG-307 rewrote `shop.bs` to the
    // decided spelling on 2026-09-03, at which point `check-corpus.sh` went
    // red on the flagship record example — the corpus gate measuring what the
    // corpus teaches, and the grammar having never been asked.
    record_pattern: $ => seq(
      optional(field('type', $.type_identifier)),
      '{', commaSep1($.field_pattern), '}',
      optional(field('binder', $.variable)),
    ),

    // `Circle c` — a type and a name, no fields. An empty record pattern with
    // a binder in the compiler; a rule of its own here because the braces are
    // what the rule above keys on.
    typed_binder_pattern: $ => seq(
      field('type', $.type_identifier),
      field('binder', $.variable),
    ),

    field_pattern: $ => seq(
      field('name', $.field_name),
      ':',
      field('pattern', $.pattern),
    ),

    // Ticket 08 as amended by ticket 54 (F20): a prefix, and an OPTIONAL rest
    // marker. `[a, b]` is exactly two; `[a, b, ..]` and `[a, b, ..t]` are two
    // or more. The absent marker is meaningful here rather than an omission.
    list_pattern: $ => seq(
      '[',
      optional(seq(
        commaSep1($.pattern),
        optional(seq(',', $.rest_pattern)),
      )),
      optional($.rest_pattern),
      ']',
    ),

    // A MARKER, NOT A PATTERN. `..[]` and `..[b, ..t]` were legal by accident
    // of ticket 08's grammar and are retired — the compiler's parser refuses
    // them with a fix-it, and this must refuse them too or the editor will
    // highlight a form that will not build.
    rest_pattern: $ => seq('..', optional(choice($.variable, $.wildcard))),

    // Ticket 30 / F13 — binaries as a PARSING GRAMMAR. This rule mirrors the
    // yecc productions (`bs_parser.yrl`, `bin_segment` / `bin_size`) rather
    // than being written from the decision, because the two disagree in a way
    // no reading of ticket 30 would predict: see `binary_size` below.
    //
    // PATTERN POSITION ONLY, and that is the compiler's shape, not a shortcut.
    // `bs_parser.yrl` hangs `'<<' bin_segments '>' '>'` off `pattern` and off
    // nothing else — there is no construction form to parse yet.
    //
    // The close is TWO `>` tokens, exactly as the compiler spells it. A `>>`
    // token here would be greedy in the one place it must not be: `list<option<int>>`
    // ends with the same two characters, and the grammar has to read them as
    // two closing brackets (ticket 28).
    binary_pattern: $ => seq('<<', commaSep1($.binary_segment), '>', '>'),

    binary_segment: $ => choice(
      seq(field('value', $.variable), optional($.binary_size)),
      seq(field('value', $.wildcard), optional($.binary_size)),
      seq(field('value', $.integer), ':', field('size', $.integer)),
      field('value', $.string),
    ),

    // `payload:size` DOES NOT LEX AS THREE TOKENS. `:size` matches the atom
    // rule, so the compiler carries a `bin_size -> atom_lit` production to take
    // it back — the collision is real and is resolved in the parser rather than
    // by making the lexer context-sensitive, which `bs_lexer.xrl` argues for at
    // length. A grammar written from ticket 30 alone would put `':' lident`
    // here, and it would never match.
    binary_size: $ => choice(
      seq(':', $.integer),
      $.atom,
    ),

    // --- expressions ---------------------------------------------------------
    _expression: $ => choice(
      $.integer,
      $.atom,
      $.boolean,
      $.variable,
      $.wildcard,
      $.call,
      $.instantiation,
      $.foreign_call,
      $.qualified_call,
      $.string,
      $.tuple,
      $.record_construction,
      $.record_update,
      $.projection,
      $.list,
      $.binary_expression,
      $.pipe_expression,
      $.switch_expression,
    ),

    call: $ => seq(
      field('function', $.function_name),
      '(', optional(commaSep1($._expression)), ')',
    ),

    // F18 — the instantiation bracket in EXPRESSION position, which is the half
    // ticket 28's rule is actually about: in type position nothing compares, so
    // the bracket was never ambiguous there. Here it would be, except that a
    // bare `uident` is not an expression in this language — so `Name<T>(x)` has
    // exactly one reading and `Foo < 3` is still a syntax error.
    //
    // The grammar admits ANY `uident`, exactly as the compiler's parser does.
    // Which names are codegen obligations is a fact the checker holds, and a
    // grammar that hardcoded the three would go stale the day a fourth lands
    // while colouring the other two as if they were built.
    instantiation: $ => seq(
      field('obligation', $.type_identifier),
      '<', commaSep1($.type_expression), '>',
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
        // F26 / ticket 38. `/` and `%` sit at `*`'s level and associate left,
        // which matters more here than for `*`: regrouping a truncating
        // division changes the answer, and `7 / 2 * 2` is 6.
        [PREC.multiply, choice('*', '/', '%'), 'left'],
      ];
      return choice(...table.map(([p, op, _assoc]) =>
        prec.left(p, seq(
          field('left', $._expression),
          field('operator', op),
          field('right', $._expression),
        )),
      ));
    },

    // --- the pipe and the valve (ticket 17 §1 and §4, F14) -------------------
    // NOT a row in the table above, and the difference is the yecc grammar's own:
    // every operator up there takes an expression on both sides, and this one
    // takes a CALL on the right. `x |> F` is a syntax error rather than a type
    // error, because ticket 17 §1 refuses to spell *function as a value* — so a
    // table row would parse a form the compiler rejects, which is precisely the
    // "present and wrong" failure this file's header warns `check-tokens.sh`
    // cannot catch.
    //
    // `prec.left` and 350 mirror the yecc table verbatim: looser than
    // arithmetic, so `a + b |> F()` is `(a + b) |> F()`; tighter than comparison.
    pipe_expression: $ => prec.left(PREC.pipe, seq(
      field('left', $._expression),
      field('operator', choice('|>', '|?>')),
      field('right', choice($.call, $.instantiation, $.foreign_call,
                            $.qualified_call)),
    )),

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

    // Hex first, and not because of precedence — `/[0-9]+/` would match the
    // leading `0` of `0xCE` and leave `xCE` as a variable, which is the exact
    // failure `bs_lexer.xrl` documents as its reason for adding the rule.
    // F13 put hex EVERYWHERE rather than inside a binary segment; this follows
    // it there for the same reason, that a lexer bent for one construct is a
    // worse thing to own than the gap.
    integer: _ => token(choice(/0[xX][0-9a-fA-F]+/, /[0-9]+/)),

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
