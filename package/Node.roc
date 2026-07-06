## XML nodes and rendering.
Node := [
	Element({ tag : Str, attributes : List(Attribute), children : List(Node) }),
	Text(Str),
].{

	## Create an XML element
	element : Str, List(Attribute), List(Node) -> Node
	element = |tag, attributes, children|
		Element({ tag, attributes, children })

	## Create a text node
	text : Str -> Node
	text = |content|
		Text(content)

	## Create a number node
	num : a -> Node where [a.to_str : a -> Str]
	num = |n|
		Text(n.to_str())

	## Create a boolean node
	bool : Bool -> Node
	bool = |b|
		Text(
			if b {
				"true"
			} else {
				"false"
			},
		)

	## Create an attribute
	attribute : Str, Str -> Attribute
	attribute = |name, value|
		{ name, value }

	## Render a node to `Str`
	render : Node -> Str
	render = |node|
		match node {
			Text(content) => escape_xml(content)
			Element({ tag, attributes, children }) => {
				opening = 
					if attributes.is_empty() {
						"<${tag}>"
					} else {
						attrs_str = Str.join_with(
							attributes.map(|attr| "${attr.name}=\"${escape_xml(attr.value)}\""),
							" ",
						)
						"<${tag} ${attrs_str}>"
					}

				children_str = Str.join_with(children.map(render), "")
				closing = "</${tag}>"
				"${opening}${children_str}${closing}"
			}
		}

	## Escape special XML characters
	escape_xml : Str -> Str
	escape_xml = |s|
		s
			->replace_each("&", "&amp;")
			->replace_each("<", "&lt;")
			->replace_each(">", "&gt;")
			->replace_each("\"", "&quot;")
			->replace_each("'", "&apos;")
}

## XML attribute
Attribute : { name : Str, value : Str }

# Replace every occurrence of `from` in `s` with `to`.
replace_each : Str, Str, Str -> Str
replace_each = |s, from, to|
	Str.join_with(s.split_on(from), to)

# Escape special characters
expect {
	input = "<tag>&\"'</tag>"
	result = Node.escape_xml(input)
	result == "&lt;tag&gt;&amp;&quot;&apos;&lt;/tag&gt;"
}

# Simple element
expect {
	node = Node.element("root", [], [Node.text("Hello")])
	result = Node.render(node)
	result == "<root>Hello</root>"
}

# Element with attribute
expect {
	node = Node.element("root", [Node.attribute("id", "1")], [Node.text("Hello")])
	result = Node.render(node)
	result == "<root id=\"1\">Hello</root>"
}

# Nested elements
expect {
	node = Node.element(
		"root",
		[],
		[
			Node.element("child", [], [Node.text("Hello")]),
			Node.element("child", [], [Node.text("World")]),
		],
	)
	result = Node.render(node)
	result == "<root><child>Hello</child><child>World</child></root>"
}

# Element with special characters in text
expect {
	node = Node.element("root", [], [Node.text("Hello & goodbye")])
	result = Node.render(node)
	result == "<root>Hello &amp; goodbye</root>"
}

# Element with special characters in attribute
expect {
	node = Node.element("root", [Node.attribute("value", "a<b")], [])
	result = Node.render(node)
	result == "<root value=\"a&lt;b\"></root>"
}

# Empty element (no children)
expect {
	node = Node.element("empty", [], [])
	result = Node.render(node)
	result == "<empty></empty>"
}

# Empty text node
expect {
	node = Node.element("root", [], [Node.text("")])
	result = Node.render(node)
	result == "<root></root>"
}

# Multiple attributes
expect {
	node = Node.element("tag", [Node.attribute("a", "1"), Node.attribute("b", "2"), Node.attribute("c", "3")], [])
	result = Node.render(node)
	result == "<tag a=\"1\" b=\"2\" c=\"3\"></tag>"
}

# Deeply nested elements (3+ levels)
expect {
	node = Node.element(
		"level1",
		[],
		[
			Node.element(
				"level2",
				[],
				[
					Node.element(
						"level3",
						[],
						[
							Node.element("level4", [], [Node.text("deep")]),
						],
					),
				],
			),
		],
	)
	result = Node.render(node)
	result == "<level1><level2><level3><level4>deep</level4></level3></level2></level1>"
}

# Mixed children (text and elements)
expect {
	node = Node.element(
		"p",
		[],
		[
			Node.text("Hello "),
			Node.element("strong", [], [Node.text("world")]),
			Node.text("!"),
		],
	)
	result = Node.render(node)
	result == "<p>Hello <strong>world</strong>!</p>"
}

# Unicode in text
expect {
	node = Node.element("root", [], [Node.text("Héllo wörld 🎉")])
	result = Node.render(node)
	result == "<root>Héllo wörld 🎉</root>"
}

# Unicode in attributes
expect {
	node = Node.element("root", [Node.attribute("emoji", "🚀"), Node.attribute("name", "Ñoño")], [])
	result = Node.render(node)
	result == "<root emoji=\"🚀\" name=\"Ñoño\"></root>"
}

# Newlines in text
expect {
	node = Node.element("pre", [], [Node.text("line1\nline2\nline3")])
	result = Node.render(node)
	result == "<pre>line1\nline2\nline3</pre>"
}

# Whitespace in attributes
expect {
	node = Node.element("tag", [Node.attribute("value", "  spaces  ")], [])
	result = Node.render(node)
	result == "<tag value=\"  spaces  \"></tag>"
}

# Empty attribute value
expect {
	node = Node.element("input", [Node.attribute("disabled", "")], [])
	result = Node.render(node)
	result == "<input disabled=\"\"></input>"
}

# Integer node
expect {
	node = Node.element("count", [], [Node.num(42.I64)])
	result = Node.render(node)
	result == "<count>42</count>"
}

# Negative integer node
expect {
	node = Node.element("temp", [], [Node.num(-10.I64)])
	result = Node.render(node)
	result == "<temp>-10</temp>"
}

# Float node
expect {
	node = Node.element("price", [], [Node.num(19.99)])
	result = Node.render(node)
	result == "<price>19.99</price>"
}

# Boolean true
expect {
	node = Node.element("enabled", [], [Node.bool(Bool.True)])
	result = Node.render(node)
	result == "<enabled>true</enabled>"
}

# Boolean false
expect {
	node = Node.element("enabled", [], [Node.bool(Bool.False)])
	result = Node.render(node)
	result == "<enabled>false</enabled>"
}

# Mixed content with numbers and booleans
expect {
	node = Node.element(
		"data",
		[],
		[
			Node.element("count", [], [Node.num(5.I64)]),
			Node.element("active", [], [Node.bool(Bool.True)]),
			Node.element("name", [], [Node.text("test")]),
		],
	)
	result = Node.render(node)
	result == "<data><count>5</count><active>true</active><name>test</name></data>"
}

# Standalone text node
expect {
	node = Node.text("hello")
	result = Node.render(node)
	result == "hello"
}

# Standalone num node
expect {
	node = Node.num(42.I64)
	result = Node.render(node)
	result == "42"
}

# Standalone bool node
expect {
	node = Node.bool(Bool.True)
	result = Node.render(node)
	result == "true"
}

# Empty string escape
expect {
	result = Node.escape_xml("")
	result == ""
}

# Zero
expect {
	node = Node.num(0.I64)
	result = Node.render(node)
	result == "0"
}

# Decimal number
expect {
	node = Node.num(123.456)
	result = Node.render(node)
	result == "123.456"
}
