pub type Ev { HTTPGet(url: String)  IPv4Addr  OAuthTok(a: Int)  Plain }
pub fn mk() { [HTTPGet("x"), IPv4Addr, OAuthTok(1), Plain] }
@external(erlang, "Shop", "New")
pub fn foreign_new(id: Int) -> a
