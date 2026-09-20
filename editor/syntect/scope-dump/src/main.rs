//! Print what syntect makes of a Beam# file.
//!
//! WHY THIS IS A DUMP AND NOT A TEST.
//!
//! `editor/bin/check-syntect.sh` is the gate; this is the only part of it that
//! has to be Rust, because syntect is the highlighter Codex runs and no shell
//! can ask it a question. Everything this program knows is `--syntax`, the
//! files it was handed, and how to print a scope. It holds no list of Beam#
//! constructs and no expectation about any of them: the obligations are in the
//! gate, written against the scope names
//! `editor/vscode/syntaxes/beam-sharp.tmLanguage.json` already records.
//!
//! Split that way because a fixture that carried its own expected scopes would
//! pass against whatever grammar it was written beside — the failure
//! `bin/check-gates-wired.sh`'s header calls a gate agreeing only with itself.
//!
//! Usage:
//!     scope-dump --syntax <dir> --tokens <t,t,t> [--] <file.bs>...
//!
//! Output, one record per line, tab-separated:
//!     resolve <token>  <syntax name>          -- or NONE
//!     scope   <file>   <line>  <text>  <scope stack>
//!     files   <n>
//!
//! `text` has its tabs and newlines escaped, so a record is always one line.

use std::process::ExitCode;

use syntect::easy::ScopeRegionIterator;
use syntect::parsing::{ParseState, ScopeStack, SyntaxSet};
use syntect::util::LinesWithEndings;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();

    let mut syntax_dir: Option<String> = None;
    let mut tokens: Vec<String> = Vec::new();
    let mut files: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--syntax" => {
                i += 1;
                match args.get(i) {
                    Some(v) => syntax_dir = Some(v.clone()),
                    None => return usage("--syntax needs a directory"),
                }
            }
            "--tokens" => {
                i += 1;
                match args.get(i) {
                    Some(v) => tokens = v.split(',').map(|s| s.trim().to_string()).collect(),
                    None => return usage("--tokens needs a comma-separated list"),
                }
            }
            "--" => {
                files.extend(args[i + 1..].iter().cloned());
                break;
            }
            other if other.starts_with("--") => {
                return usage(&format!("unknown option: {other}"));
            }
            other => files.push(other.to_string()),
        }
        i += 1;
    }

    let syntax_dir = match syntax_dir {
        Some(d) => d,
        None => return usage("--syntax is required"),
    };

    // Syntect's own bundled set first, then ours on top. Loading ours alone
    // would answer "does `bs` resolve to Beam#" with a set in which nothing
    // else could claim it. This is not Codex's set — Codex loads two-face's,
    // which is bat's and is larger — so it is a lower bound on the question,
    // not the whole of it.
    let mut builder = SyntaxSet::load_defaults_newlines().into_builder();
    if let Err(e) = builder.add_from_folder(&syntax_dir, true) {
        eprintln!("scope-dump: cannot load syntaxes from {syntax_dir}: {e}");
        return ExitCode::from(2);
    }
    let syntax_set = builder.build();

    for token in &tokens {
        match syntax_set.find_syntax_by_token(token) {
            Some(s) => println!("resolve\t{token}\t{}", s.name),
            None => println!("resolve\t{token}\tNONE"),
        }
    }

    let mut seen = 0usize;
    for path in &files {
        let text = match std::fs::read_to_string(path) {
            Ok(t) => t,
            Err(e) => {
                eprintln!("scope-dump: cannot read {path}: {e}");
                return ExitCode::from(2);
            }
        };

        // By extension, exactly as an editor opening the file would — not by
        // name. A grammar that highlights correctly only when the language is
        // chosen by hand has not been installed.
        let syntax = match syntax_set.find_syntax_for_file(path) {
            Ok(Some(s)) => s,
            // NOT counted in `seen`. The gate prints that number as "across N
            // examples", so counting a file nothing could colour would let the
            // claim grow while the evidence shrank.
            Ok(None) | Err(_) => {
                println!("scope\t{path}\t0\t<no syntax>\tNONE");
                continue;
            }
        };

        let mut state = ParseState::new(syntax);
        let mut stack = ScopeStack::new();

        for (lineno, line) in LinesWithEndings::from(&text).enumerate() {
            let ops = match state.parse_line(line, &syntax_set) {
                Ok(ops) => ops,
                Err(e) => {
                    eprintln!("scope-dump: {path}:{}: {e}", lineno + 1);
                    return ExitCode::from(2);
                }
            };
            for (range, op) in ScopeRegionIterator::new(&ops, line) {
                if let Err(e) = stack.apply(op) {
                    eprintln!("scope-dump: {path}:{}: {e}", lineno + 1);
                    return ExitCode::from(2);
                }
                if range.trim().is_empty() {
                    continue;
                }
                let scopes: Vec<String> = stack.scopes.iter().map(|s| s.to_string()).collect();
                println!(
                    "scope\t{path}\t{}\t{}\t{}",
                    lineno + 1,
                    escape(range),
                    scopes.join(" ")
                );
            }
        }
        seen += 1;
    }

    println!("files\t{seen}");
    ExitCode::SUCCESS
}

/// A record is one line, so the text column cannot contain one.
fn escape(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('\t', "\\t")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
}

fn usage(why: &str) -> ExitCode {
    eprintln!("scope-dump: {why}");
    eprintln!("usage: scope-dump --syntax <dir> [--tokens a,b,c] [--] <file.bs>...");
    ExitCode::from(2)
}
