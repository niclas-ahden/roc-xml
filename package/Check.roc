## Finding what XML cannot express in a tree. Internal to the package.
import Chars
import Node exposing [Node]

Check := [].{

	## Something in a tree that XML cannot express, and where it is. The same
	## type as `Element.Problem`, which is where it is documented.
	Problem : {
		path : List({ tag : Str, index : U64 }),
		kind : [
			InvalidChar({ code_point : U32, byte_index : U64, found_in : [Content(U64), TagName, AttributeName(Str), AttributeValue(Str)] }),
			EmptyName([TagName, AttributeName]),
		],
	}

	## Whether the tree holds no problem at all. This is the quick way to the
	## common answer: it builds no paths and no lists. [problems] stays the
	## authority on what the problems are.
	is_clean : Node -> Bool
	is_clean = |node| is_clean_node(node)

	## Every problem in the tree, in document order. An element's own
	## problems come before those of its children.
	problems : Node -> List(Problem)
	problems = |node| problems_in(node, [], 0)
}

is_clean_node : Node -> Bool
is_clean_node = |node|
	match node {
		TextNode(content) => Chars.is_valid(content)
		ElementNode({ tag, attributes, children }) => {
			is_clean_attribute = |clean, name, value| clean and Chars.is_name(name) and Chars.is_valid(value)
			Chars.is_name(tag) and attributes.fold(Bool.True, is_clean_attribute) and children.all(is_clean_node)
		}
	}

# Every problem in `node` and the tree below it. `path_above` is the path to
# the parent and `index` the node's position among the parent's children. A
# text node's problems carry the parent's path, since text has no name to
# point at, and say which child it is.
problems_in : Node, List({ tag : Str, index : U64 }), U64 -> List(Check.Problem)
problems_in = |node, path_above, index|
	match node {
		TextNode(content) => check_value(content, path_above, Content(index))
		ElementNode({ tag, attributes, children }) => {
			path = path_above.append({ tag, index })
			attribute_problems = attributes.to_list().join_map(
				|(name, value)| check_name(name, path, AttributeName).concat(check_value(value, path, AttributeValue(name))),
			)
			child_problems = children.map_with_index(|child, i| (child, i)).join_map(
				|(child, i)| problems_in(child, path, i),
			)
			check_name(tag, path, TagName)
				.concat(attribute_problems)
				.concat(child_problems)
		}
	}

# The problem with `value`, if it holds a character XML cannot express.
check_value : Str, List({ tag : Str, index : U64 }), [Content(U64), TagName, AttributeName(Str), AttributeValue(Str)] -> List(Check.Problem)
check_value = |value, path, found_in|
	match Chars.find_invalid_char(value) {
		Ok({ code_point, byte_index }) => [{ path, kind: InvalidChar({ code_point, byte_index, found_in }) }]
		Err(NoInvalidChar) => []
	}

# The problem with `name`, if it is empty or is not an XML name.
check_name : Str, List({ tag : Str, index : U64 }), [TagName, AttributeName] -> List(Check.Problem)
check_name = |name, path, found_in|
	if name.is_empty() {
		[{ path, kind: EmptyName(found_in) }]
	} else {
		match Chars.find_invalid_name_char(name) {
			Ok({ code_point, byte_index }) => {
				where_ = match found_in {
					TagName => TagName
					AttributeName => AttributeName(name)
				}
				[{ path, kind: InvalidChar({ code_point, byte_index, found_in: where_ }) }]
			}
			Err(NoInvalidChar) => []
		}
	}

# A path step, to keep the expected paths in tests short
at : Str, U64 -> { tag : Str, index : U64 }
at = |tag, index| { tag, index }

# An element without attributes, to keep the trees in tests short
el : Str, List(Node) -> Node
el = |tag, children| Node.element(tag, Dict.empty(), children)

# A clean tree has no problems
expect Check.problems(el("root", [Node.text("Hello")])) == []
expect Check.problems(Node.element("root", Dict.single("id", "1"), [el("child", [Node.text("Héllo 🎉")])])) == []

# A control character in text is reported with the path to its element
expect
	Check.problems(el("a", [Node.text("bell\u(7)")]))
		== [{ path: [at("a", 0)], kind: InvalidChar({ code_point: 7, byte_index: 4, found_in: Content(0) }) }]

# A control character in an attribute value names the attribute
expect
	Check.problems(Node.element("a", Dict.single("id", "\u(0)"), []))
		== [{ path: [at("a", 0)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: AttributeValue("id") }) }]

# The path runs from the root down to the element holding the value, and
# says which sibling
expect {
	tree = el(
		"catalog",
		[
			el("book", [el("title", [Node.text("ok")])]),
			el("book", [el("title", [Node.text("\u(1B)[0m")])]),
		],
	)
	Check.problems(tree) == [{ path: [at("catalog", 0), at("book", 1), at("title", 0)], kind: InvalidChar({ code_point: 0x1B, byte_index: 0, found_in: Content(0) }) }]
}

# Positions count every child, text nodes included
expect {
	tree = el("p", [Node.text("a"), el("b", []), el("c d", [])])
	Check.problems(tree) == [{ path: [at("p", 0), at("c d", 2)], kind: InvalidChar({ code_point: ' ', byte_index: 1, found_in: TagName }) }]
}

# A text node's problem says which child it is, other text nodes counted
expect {
	tree = el("p", [Node.text("fine"), el("b", []), Node.text("\u(7)"), Node.text("\u(8)")])
	Check.problems(tree)
		== [
			{ path: [at("p", 0)], kind: InvalidChar({ code_point: 7, byte_index: 0, found_in: Content(2) }) },
			{ path: [at("p", 0)], kind: InvalidChar({ code_point: 8, byte_index: 0, found_in: Content(3) }) },
		]
}

# A text node on its own has an empty path and position 0
expect Check.problems(Node.text("\u(C)")) == [{ path: [], kind: InvalidChar({ code_point: 0xC, byte_index: 0, found_in: Content(0) }) }]

# One value yields one problem, at its first invalid character
expect Check.problems(Node.text("ab\u(2)cd\u(3)")) == [{ path: [], kind: InvalidChar({ code_point: 2, byte_index: 2, found_in: Content(0) }) }]

# Tab, newline and carriage return are the control characters XML allows
expect Check.problems(Node.text("a\tb\nc\rd")) == []
expect Check.problems(Node.element("a", Dict.single("v", "x\ny\tz\r"), [])) == []

# Every problem in the tree is reported, in document order
expect {
	tree = Node.element(
		"r",
		Dict.from_list([("1", "a"), ("x", "\u(0)")]),
		[
			el("bad tag", [Node.text("\u(1)")]),
			el("", []),
		],
	)
	Check.problems(tree)
		== [
			{ path: [at("r", 0)], kind: InvalidChar({ code_point: '1', byte_index: 0, found_in: AttributeName("1") }) },
			{ path: [at("r", 0)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: AttributeValue("x") }) },
			{ path: [at("r", 0), at("bad tag", 0)], kind: InvalidChar({ code_point: ' ', byte_index: 3, found_in: TagName }) },
			{ path: [at("r", 0), at("bad tag", 0)], kind: InvalidChar({ code_point: 1, byte_index: 0, found_in: Content(0) }) },
			{ path: [at("r", 0), at("", 1)], kind: EmptyName(TagName) },
		]
}

# An element's own problems come before those of its children
expect {
	tree = Node.element("a", Dict.single("x", "\u(0)"), [Node.text("\u(1)"), el("b", [Node.text("\u(2)")])])
	Check.problems(tree)
		== [
			{ path: [at("a", 0)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: AttributeValue("x") }) },
			{ path: [at("a", 0)], kind: InvalidChar({ code_point: 1, byte_index: 0, found_in: Content(0) }) },
			{ path: [at("a", 0), at("b", 1)], kind: InvalidChar({ code_point: 2, byte_index: 0, found_in: Content(0) }) },
		]
}

# Within an element: tag, then each attribute's name and value in the order they were inserted
expect {
	tree = Node.element("bad tag", Dict.from_list([("x=y", "\u(0)"), ("ok", "\u(1)")]), [])
	Check.problems(tree)
		== [
			{ path: [at("bad tag", 0)], kind: InvalidChar({ code_point: ' ', byte_index: 3, found_in: TagName }) },
			{ path: [at("bad tag", 0)], kind: InvalidChar({ code_point: '=', byte_index: 1, found_in: AttributeName("x=y") }) },
			{ path: [at("bad tag", 0)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: AttributeValue("x=y") }) },
			{ path: [at("bad tag", 0)], kind: InvalidChar({ code_point: 1, byte_index: 0, found_in: AttributeValue("ok") }) },
		]
}

# A tag name cannot start with a digit, hyphen or period, but may contain them
expect Check.problems(el("1st", [])) == [{ path: [at("1st", 0)], kind: InvalidChar({ code_point: '1', byte_index: 0, found_in: TagName }) }]
expect Check.problems(el("-x", [])) == [{ path: [at("-x", 0)], kind: InvalidChar({ code_point: '-', byte_index: 0, found_in: TagName }) }]
expect Check.problems(el(".x", [])) == [{ path: [at(".x", 0)], kind: InvalidChar({ code_point: '.', byte_index: 0, found_in: TagName }) }]
expect Check.problems(el("h1.a-b_c", [])) == []

# Namespace prefixes and non-ASCII letters are legal in names
expect Check.problems(Node.element("xmlns:r", Dict.single("r:id", "rId1"), [])) == []
expect Check.problems(Node.element("café", Dict.single("日本", "x"), [])) == []

# Namespaces in XML is not checked: these are XML 1.0 names
expect Check.problems(el("a:b:c", [])) == []
expect Check.problems(el("xmlFoo", [])) == []

# Markup characters in a name are reported, since they cannot be escaped there
expect Check.problems(el("a<b", [])) == [{ path: [at("a<b", 0)], kind: InvalidChar({ code_point: '<', byte_index: 1, found_in: TagName }) }]
expect Check.problems(Node.element("a", Dict.single("x=y", ""), [])) == [{ path: [at("a", 0)], kind: InvalidChar({ code_point: '=', byte_index: 1, found_in: AttributeName("x=y") }) }]
expect Check.problems(Node.element("a", Dict.single("x\"", ""), [])) == [{ path: [at("a", 0)], kind: InvalidChar({ code_point: '"', byte_index: 1, found_in: AttributeName("x\"") }) }]

# Empty names are reported
expect Check.problems(el("", [])) == [{ path: [at("", 0)], kind: EmptyName(TagName) }]
expect Check.problems(Node.element("a", Dict.single("", "x"), [])) == [{ path: [at("a", 0)], kind: EmptyName(AttributeName) }]

# Lossy text leaves nothing to find
expect Check.problems(el("t", [Node.text_lossy("bell\u(7)", Drop)])) == []

# The quick check says clean exactly when the full one finds nothing
expect {
	trees = [
		Node.text("fine"),
		Node.text("\u(C)"),
		Node.text("\u(FFFE)"),
		Node.text("\u(FF01)"),
		Node.element("a", Dict.from_list([("id", "1"), ("class", "c")]), [Node.text("x"), el("b", [])]),
		Node.element("café", Dict.single("日本", "x\ny"), []),
		el("", []),
		el("bad tag", []),
		Node.element("a", Dict.single("", "x"), []),
		Node.element("a", Dict.single("1", "x"), []),
		Node.element("a", Dict.single("x", "\u(0)"), []),
		Node.element("a", Dict.from_list([("ok", "fine"), ("x", "\u(0)")]), []),
		el("a", [el("b", [el("c", [Node.text("\u(1)")])])]),
	]
	trees.all(|tree| Check.is_clean(tree) == Check.problems(tree).is_empty())
		and trees.map(Check.is_clean) == [Bool.True, Bool.False, Bool.False, Bool.True, Bool.True, Bool.True, Bool.False, Bool.False, Bool.False, Bool.False, Bool.False, Bool.False, Bool.False]
}
