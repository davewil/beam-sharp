// Q1: a union return type; what does the error name?
type CartResult =
  | { kind: "numeric"; items: Record<string, number> }
  | { kind: "expired"; reason: string };

function cartFromForm(formFields: Record<string, string>): CartResult {
  return formFields;
}

function cartTagged(formFields: Record<string, string>): CartResult {
  return { kind: "numeric", items: formFields };
}

function handle(method: string): "created" | "ok" | { error: string } {
  return 405;
}
