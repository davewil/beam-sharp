import lib
import lib/internal/secret
pub fn main() { #(lib.open(), secret.helper(), secret.marked()) }
