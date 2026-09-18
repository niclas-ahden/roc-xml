## XML nodes, the data a tree is made of.
##
## Nothing here checks anything, and nothing here can fail. A tree becomes
## XML through [Element]: [Element.new] checks it and reports what XML cannot
## express, and [Element.new_lossy] repairs it instead.
##
## A node is plain data, so a tree can be taken apart with `match` as well as
## built.
import Chars

Node := [
	ElementNode({ tag : Str, attributes : Dict(Str, Str), children : List(Node) }),
	TextNode(Str),
].{

	## What to do with a character XML cannot express: the control characters
	## U+0000 to U+001F other than tab, newline and carriage return, and
	## U+FFFE and U+FFFF.
	##
	## A string can hold several of them, and each one is treated on its own:
	##
	## - `Drop`: leave each one out.
	## - `Replace(str)`: write `str` in place of each one, as
	##   `Str.replace_each` would. The rest of the string is kept.
	## - `ReplaceWith(fn)`: write in place of each one what `fn` returns
	##   for its code point.
	##
	## ```roc
	## Node.text_lossy("a\u(0)b\u(7)c", Drop) == Node.text("abc")
	## Node.text_lossy("a\u(0)b\u(7)c", Replace("?")) == Node.text("a?b?c")
	## Node.text_lossy("a\u(0)b\u(7)c", ReplaceWith(|code_point| "<${code_point.to_str()}>")) == Node.text("a<0>b<7>c")
	## ```
	##
	## Should a replacement itself hold such a character, that character
	## becomes U+FFFD.
	Replacement : [Drop, Replace(Str), ReplaceWith(U32 -> Str)]

	## An element with the given tag, attributes and children.
	##
	## The attributes are a `Dict` from name to value, so an element cannot
	## have the same attribute twice. They are rendered in the order they
	## were inserted.
	##
	## ```roc
	## Node.element("book", Dict.single("id", "1"), [Node.text("Roc")])
	## ```
	element : Str, Dict(Str, Str), List(Node) -> Node
	element = |tag, attributes, children| ElementNode({ tag, attributes, children })

	## A text node. Markup characters are fine, they are escaped when
	## rendered.
	text : Str -> Node
	text = |content| TextNode(content)

	## A text node with every character XML cannot express dropped or
	## replaced, so [Element.new] can find nothing in it. This is the way to
	## put text you do not control into a tree that is otherwise checked, or
	## to treat one piece of text differently from the rest of a tree given
	## to [Element.new_lossy].
	##
	## ```roc
	## Node.text_lossy("bell\u(7)", Drop) == Node.text("bell")
	## Node.text_lossy("bell\u(7)", ReplaceWith(|code_point| "<U+${code_point.to_str()}>")) == Node.text("bell<U+7>")
	## ```
	text_lossy : Str, Replacement -> Node
	text_lossy = |content, replacement| TextNode(Chars.replace_invalid(content, replacement))

	## A text node holding a number, written the way `to_str` writes it.
	num : a -> Node where [a.to_str : a -> Str]
	num = |n| TextNode(n.to_str())

	## A text node holding `true` or `false`.
	bool : Bool -> Node
	bool = |b| TextNode(
		if b {
			"true"
		} else {
			"false"
		},
	)

	## Structural equality: same kind of node, same tag and children in the
	## same order, and the same attributes in any order, or the same text.
	is_eq : Node, Node -> Bool
	is_eq = |a, b|
		match (a, b) {
			(TextNode(x), TextNode(y)) => x == y
			(ElementNode(x), ElementNode(y)) => x.tag == y.tag and x.attributes == y.attributes and x.children == y.children
			_ => Bool.False
		}
}

# Nodes compare structurally
expect Node.text("a") == Node.text("a")
expect Node.text("a") != Node.text("b")
expect Node.element("a", Dict.empty(), [Node.text("x")]) == Node.element("a", Dict.empty(), [Node.text("x")])
expect Node.element("a", Dict.empty(), [Node.text("x"), Node.text("y")]) != Node.element("a", Dict.empty(), [Node.text("xy")])
expect Node.element("a", Dict.empty(), []) != Node.text("a")
expect Node.element("a", Dict.single("id", "1"), []) != Node.element("a", Dict.single("id", "2"), [])
expect Node.element("a", Dict.single("id", "1"), []) != Node.element("a", Dict.empty(), [])

# The order of attributes does not matter to equality, as it does not to XML
expect
	Node.element("a", Dict.from_list([("x", "1"), ("y", "2")]), [])
		== Node.element("a", Dict.from_list([("y", "2"), ("x", "1")]), [])

# An element cannot have the same attribute twice: the last value is the one kept
expect
	Node.element("a", Dict.from_list([("id", "1"), ("id", "2")]), [])
		== Node.element("a", Dict.single("id", "2"), [])

# Numbers and booleans are text nodes
expect Node.num(42.I64) == Node.text("42")
expect Node.num(-10.I64) == Node.text("-10")
expect Node.num(19.99) == Node.text("19.99")
expect Node.bool(Bool.True) == Node.text("true")
expect Node.bool(Bool.False) == Node.text("false")

# Lossy text leaves a clean string alone
expect Node.text_lossy("fine", Drop) == Node.text("fine")
expect Node.text_lossy("Héllo 世界 🎉", Replace("?")) == Node.text("Héllo 世界 🎉")

# Every character XML cannot express is dropped or replaced
expect Node.text_lossy("bell\u(7)", Drop) == Node.text("bell")
expect Node.text_lossy("a\u(0)b\u(7)", Replace("_")) == Node.text("a_b_")
expect Node.text_lossy("bell\u(7)", ReplaceWith(|code_point| "<U+${code_point.to_str()}>")) == Node.text("bell<U+7>")

# Each one is treated on its own, and the rest of the string is kept
expect Node.text_lossy("a\u(0)b\u(7)c", Drop) == Node.text("abc")
expect Node.text_lossy("a\u(0)b\u(7)c", Replace("?")) == Node.text("a?b?c")
expect Node.text_lossy("a\u(0)b\u(7)c", ReplaceWith(|code_point| "<${code_point.to_str()}>")) == Node.text("a<0>b<7>c")

# A replacement holding such a character has it turned into U+FFFD
expect Node.text_lossy("\u(0)", Replace("\u(0)")) == Node.text("\u(FFFD)")

# A node is plain data, so a tree can be taken apart
tags_in : Node -> List(Str)
tags_in = |node|
	match node {
		TextNode(_) => []
		ElementNode({ tag, children, .. }) => children.fold([tag], |acc, child| acc.concat(tags_in(child)))
	}

expect {
	tree = Node.element("a", Dict.empty(), [Node.text("x"), Node.element("b", Dict.empty(), [Node.element("c", Dict.empty(), [])])])
	tags_in(tree) == ["a", "b", "c"]
}
