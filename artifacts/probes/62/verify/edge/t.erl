-module(t).
-export(['Length'/1, length/1, 'ModuleInfo'/0, module_info/0]).
'Length'(X) -> X.
length(X) -> 'Length'(X).
'ModuleInfo'() -> 1.
module_info() -> 'ModuleInfo'().
