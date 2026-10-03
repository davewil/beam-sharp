import lib/hidden/vault

pub fn leaky() -> vault.Secret {
  vault.make()
}
