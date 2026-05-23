## Application service: parses and evaluates the MVP-I `WIN_CONDITION`
## DSL expressions (separate from the imperative `compiled_logic` rule
## strings handled by RuleCompilerService).
##
## Grammar (plan thoughts/shared/plans/2026-05-19-mvp-game-mechanics.md §7):
##
##   expr       := or_expr
##   or_expr    := and_expr ("or" and_expr)*
##   and_expr   := not_expr ("and" not_expr)*
##   not_expr   := "not" not_expr | primary
##   primary    := "(" expr ")" | comparison | identifier
##   comparison := identifier op literal
##   op         := ">=" | "<=" | "==" | "!=" | ">" | "<"
##   identifier := IDENT ("." IDENT)?   -- e.g. score, inventory.carrot
##   literal    := INT | STRING
##
## Whitelisted identifiers: `score`, `time`, `blocks_placed`,
## `inventory.<name>`, `quest.<name>`, `in_zone.<name>`. Anything else
## fails parsing — keeps the kid-facing DSL strict and predictable.
##
## **No `Expression.parse()`. No `eval()`.** Strict recursive descent
## over a hand-tokenized stream. Fail-closed: malformed input never
## evaluates to `true`. Per plan risk register row "WIN_CONDITION DSL
## eval injection".
##
## Typical use:
##   var interp := WinConditionInterpreter.new()
##   var ok := interp.parse("inventory.carrot>=5 and not in_zone.danger")
##   if ok and interp.evaluate({"inventory": {"carrot": 6}, "in_zone": {"danger": false}}):
##       # fire SessionEndedEvent(win=true)
class_name WinConditionInterpreter
extends RefCounted

const _OPS := ["==", "!=", ">=", "<=", ">", "<"]
const _ALLOWED_IDENTS := {
	"score": true,
	"time": true,
	"blocks_placed": true,
	"inventory": true,    ## must be followed by .<name>
	"quest": true,        ## must be followed by .<name>
	"in_zone": true,      ## must be followed by .<name>
}
## Identifiers that REQUIRE a `.subname` qualifier.
const _REQUIRES_SUBNAME := {
	"inventory": true,
	"quest": true,
	"in_zone": true,
}

## Token shape: {"kind": String, "value": Variant}
## Kinds: "ident", "int", "str", "op", "and", "or", "not", "lparen", "rparen", "dot", "eof"
var _tokens: Array = []
var _pos: int = 0
var _ast: Variant = null
## Set if parse() returns false. Lets tests assert exact failure reasons.
var last_error: String = ""


## Parse a DSL string. Returns true on success, false on malformed input.
## On failure the AST is cleared and last_error is populated.
func parse(source: String) -> bool:
	_ast = null
	last_error = ""
	_pos = 0
	if not _tokenize(source):
		return false
	var ast: Variant = _parse_expr()
	if ast == null:
		return false
	if not _at_eof():
		last_error = "trailing tokens after expression"
		return false
	_ast = ast
	return true


## Evaluate the parsed expression against a context dictionary.
## ctx must mirror the identifier shape:
##   {"score": 100, "time": 30, "blocks_placed": 5,
##    "inventory": {"carrot": 3}, "quest": {"harvest": "complete"},
##    "in_zone": {"win": true}}
## Returns false when no AST is loaded or on any structural mismatch.
func evaluate(ctx: Dictionary) -> bool:
	if _ast == null:
		return false
	return _eval_node(_ast, ctx)


# ============================================================
# Tokenizer
# ============================================================

func _tokenize(source: String) -> bool:
	_tokens.clear()
	var s := source.strip_edges()
	var i := 0
	var n := s.length()
	while i < n:
		var c := s[i]
		# Whitespace
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			i += 1
			continue
		# Parens
		if c == "(":
			_tokens.append({"kind": "lparen", "value": null})
			i += 1
			continue
		if c == ")":
			_tokens.append({"kind": "rparen", "value": null})
			i += 1
			continue
		# Dot is a structural separator inside identifiers — but we
		# only consume it from within the identifier parser. Bare dots
		# are a parse error.
		# Two-char operators first to avoid > / >= ambiguity.
		var two := s.substr(i, 2)
		if two in _OPS:
			_tokens.append({"kind": "op", "value": two})
			i += 2
			continue
		# Single-char operators.
		if c == ">" or c == "<":
			_tokens.append({"kind": "op", "value": c})
			i += 1
			continue
		# Integer literal.
		if c >= "0" and c <= "9":
			var j := i
			while j < n and s[j] >= "0" and s[j] <= "9":
				j += 1
			_tokens.append({"kind": "int", "value": int(s.substr(i, j - i))})
			i = j
			continue
		# Single-quoted string literal: '...'. No escapes for MVP.
		if c == "'":
			var k := i + 1
			while k < n and s[k] != "'":
				k += 1
			if k >= n:
				last_error = "unterminated string literal"
				return false
			_tokens.append({"kind": "str", "value": s.substr(i + 1, k - i - 1)})
			i = k + 1
			continue
		# Identifier or keyword (and/or/not).
		if _is_ident_start(c):
			var p := i
			while p < n and _is_ident_part(s[p]):
				p += 1
			# Capture dotted segments like inventory.carrot — emit as one ident.
			var ident := s.substr(i, p - i)
			i = p
			if i < n and s[i] == ".":
				# Consume one `.subname` segment.
				var q := i + 1
				while q < n and _is_ident_part(s[q]):
					q += 1
				if q == i + 1:
					last_error = "dotted identifier requires a name after '.'"
					return false
				ident = ident + "." + s.substr(i + 1, q - i - 1)
				i = q
			# Reserve and/or/not as keywords; everything else is an ident.
			match ident:
				"and":
					_tokens.append({"kind": "and", "value": null})
				"or":
					_tokens.append({"kind": "or", "value": null})
				"not":
					_tokens.append({"kind": "not", "value": null})
				_:
					_tokens.append({"kind": "ident", "value": ident})
			continue
		# Unknown char — refuse the whole expression.
		last_error = "unexpected character at offset %d: '%s'" % [i, c]
		return false
	_tokens.append({"kind": "eof", "value": null})
	return true


func _is_ident_start(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


func _is_ident_part(c: String) -> bool:
	return _is_ident_start(c) or (c >= "0" and c <= "9")


# ============================================================
# Recursive-descent parser
# ============================================================

func _peek() -> Dictionary:
	return _tokens[_pos] as Dictionary


func _consume(kind: String) -> Variant:
	var tok: Dictionary = _peek()
	if tok.kind != kind:
		last_error = "expected %s, got %s" % [kind, tok.kind]
		return null
	_pos += 1
	return tok


func _at_eof() -> bool:
	return _peek().kind == "eof"


# expr := or_expr
func _parse_expr() -> Variant:
	return _parse_or()


# or_expr := and_expr ("or" and_expr)*
func _parse_or() -> Variant:
	var left: Variant = _parse_and()
	if left == null:
		return null
	while _peek().kind == "or":
		_pos += 1
		var right: Variant = _parse_and()
		if right == null:
			return null
		left = {"kind": "or", "left": left, "right": right}
	return left


# and_expr := not_expr ("and" not_expr)*
func _parse_and() -> Variant:
	var left: Variant = _parse_not()
	if left == null:
		return null
	while _peek().kind == "and":
		_pos += 1
		var right: Variant = _parse_not()
		if right == null:
			return null
		left = {"kind": "and", "left": left, "right": right}
	return left


# not_expr := "not" not_expr | primary
func _parse_not() -> Variant:
	if _peek().kind == "not":
		_pos += 1
		var inner: Variant = _parse_not()
		if inner == null:
			return null
		return {"kind": "not", "child": inner}
	return _parse_primary()


# primary := "(" expr ")" | comparison | bare_identifier
func _parse_primary() -> Variant:
	var tok: Dictionary = _peek()
	if tok.kind == "lparen":
		_pos += 1
		var inner: Variant = _parse_expr()
		if inner == null:
			return null
		if _consume("rparen") == null:
			return null
		return inner
	if tok.kind == "ident":
		var ident_tok: Variant = _consume("ident")
		var ident: String = String(ident_tok.value)
		if not _identifier_allowed(ident):
			last_error = "unknown identifier '%s'" % ident
			return null
		# If followed by an op → comparison; else bare boolean.
		if _peek().kind == "op":
			var op_tok: Variant = _consume("op")
			var op: String = String(op_tok.value)
			var lit_tok: Dictionary = _peek()
			if lit_tok.kind != "int" and lit_tok.kind != "str":
				last_error = "expected int or string literal after operator"
				return null
			_pos += 1
			return {
				"kind": "cmp",
				"ident": ident,
				"op": op,
				"value": lit_tok.value,
			}
		# Bare identifier — interpret as truthiness probe.
		return {"kind": "bare_ident", "ident": ident}
	last_error = "expected expression, got %s" % tok.kind
	return null


func _identifier_allowed(ident: String) -> bool:
	# Strip the dotted subname for the whitelist check.
	var head := ident
	var has_dot := ident.find(".") != -1
	if has_dot:
		head = ident.substr(0, ident.find("."))
	if not _ALLOWED_IDENTS.has(head):
		return false
	if _REQUIRES_SUBNAME.has(head) and not has_dot:
		# `inventory` alone is meaningless without a subname.
		return false
	return true


# ============================================================
# Evaluator
# ============================================================

func _eval_node(node: Dictionary, ctx: Dictionary) -> bool:
	match node.kind:
		"and":
			return _eval_node(node.left, ctx) and _eval_node(node.right, ctx)
		"or":
			return _eval_node(node.left, ctx) or _eval_node(node.right, ctx)
		"not":
			return not _eval_node(node.child, ctx)
		"cmp":
			return _eval_cmp(node, ctx)
		"bare_ident":
			var v: Variant = _lookup(node.ident, ctx)
			return bool(v)
	return false


func _eval_cmp(node: Dictionary, ctx: Dictionary) -> bool:
	var lhs: Variant = _lookup(String(node.ident), ctx)
	var rhs: Variant = node.value
	# Mixed types fail closed.
	if (rhs is int and not (lhs is int or lhs is float)) \
			or (rhs is String and not (lhs is String)):
		return false
	match String(node.op):
		"==":
			return lhs == rhs
		"!=":
			return lhs != rhs
		">":
			return lhs > rhs
		"<":
			return lhs < rhs
		">=":
			return lhs >= rhs
		"<=":
			return lhs <= rhs
	return false


func _lookup(ident: String, ctx: Dictionary) -> Variant:
	if ident.find(".") == -1:
		return ctx.get(ident, null)
	var parts := ident.split(".", true, 1)
	var bucket: Variant = ctx.get(parts[0], null)
	if bucket is Dictionary:
		return (bucket as Dictionary).get(parts[1], null)
	return null
