import liba
import liba/internal/secret
pub fn main() -> Int { liba.public_api() + secret.helper() + liba.attr_internal() }
