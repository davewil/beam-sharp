use std::collections::HashMap;

enum CartResult {
    Session(HashMap<String, String>),
    Form(HashMap<String, String>),
    Expired(u32),
}

fn cart(m: HashMap<String, String>) -> CartResult {
    m
}

fn main() {}
