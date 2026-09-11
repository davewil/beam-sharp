use std::collections::HashMap;

enum CartResult {
    Numeric(HashMap<String, i64>),
    Text(HashMap<String, String>),
    Expired(u32),
}

fn cart(m: HashMap<String, String>) -> CartResult {
    m
}

fn opt(n: i64) -> Option<i64> {
    n
}

fn res(n: i64) -> Result<i64, String> {
    n
}

fn main() {}
