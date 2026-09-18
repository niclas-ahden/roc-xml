## Writing a tree out as XML. Internal to the package.
import Node exposing [Node]

Render := [].{

	## The tree as XML, without a declaration. The tree must be clean, as
	## `Check.is_clean` has it: names and characters are written as they are,
	## so only a clean tree renders as well-formed XML.
	##
	## Markup characters in text and attribute values are escaped. So is
	## whitespace that a parser would otherwise normalise away: a carriage
	## return in text, and tab, newline and carriage return in attribute
	## values, are written as character references, so a parser reads back
	## exactly the strings that went in.
	render : Node -> Str
	render = |node| render_into("", node)
}

# Append the rendering of `node` to `out`. One string grows through the whole
# tree, rather than every element building its own and copying it into its
# parent's.
render_into : Str, Node -> Str
render_into = |out, node|
	match node {
		TextNode(content) => out.concat(escape_text(content))
		ElementNode({ tag, attributes, children }) => {
			opened = attributes.fold(
				out.concat("<").concat(tag),
				|acc, name, value| acc.concat(" ").concat(name).concat("=\"").concat(escape_attribute(value)).concat("\""),
			)
			children.fold(opened.concat(">"), render_into).concat("</").concat(tag).concat(">")
		}
	}

# Escape element text. `<` and `&` cannot appear in text, and `>` is escaped
# too so that `]]>` cannot. Quotes need no escaping in text and are left
# alone. A parser turns a carriage return, alone or before a newline, into a
# newline, so it is written as a character reference to survive.
escape_text : Str -> Str
escape_text = |s|
	if s.to_utf8().any(|byte| byte == '&' or byte == '<' or byte == '>' or byte == '\r') {
		s
			.replace_each("&", "&amp;")
			.replace_each("<", "&lt;")
			.replace_each(">", "&gt;")
			.replace_each("\r", "&#13;")
	} else {
		# Most text holds none of them, and one look is cheaper than four
		s
	}

# Escape an attribute value. Values are written in double quotes, so `<`, `&`
# and `"` are escaped and `>` and `'` are left alone. Attribute value
# normalisation turns tab, newline and carriage return into spaces, so they
# are written as character references to survive.
escape_attribute : Str -> Str
escape_attribute = |s|
	if s.to_utf8().any(|byte| byte == '&' or byte == '<' or byte == '"' or byte == '\t' or byte == '\n' or byte == '\r') {
		s
			.replace_each("&", "&amp;")
			.replace_each("<", "&lt;")
			.replace_each("\"", "&quot;")
			.replace_each("\t", "&#9;")
			.replace_each("\n", "&#10;")
			.replace_each("\r", "&#13;")
	} else {
		# Most values hold none of them, and one look is cheaper than six
		s
	}

# An element without attributes, to keep the trees in tests short
el : Str, List(Node) -> Node
el = |tag, children| Node.element(tag, Dict.empty(), children)

# Only what XML forbids is escaped: `<`, `&` and, for `]]>`, `>` in text
expect escape_text("<tag>&\"'</tag>") == "&lt;tag&gt;&amp;\"'&lt;/tag&gt;"
expect escape_text("a]]>b") == "a]]&gt;b"
expect escape_text("") == ""

# In a double-quoted attribute value `"` is escaped as well, and `'` and `>` are not
expect escape_attribute("<tag>&\"'</tag>") == "&lt;tag>&amp;&quot;'&lt;/tag>"

# Markup and whitespace escaping in an attribute value do not interfere
expect escape_attribute("<\n&") == "&lt;&#10;&amp;"

# Simple element with text
expect Render.render(el("root", [Node.text("Hello")])) == "<root>Hello</root>"

# Element with attribute
expect Render.render(Node.element("root", Dict.single("id", "1"), [Node.text("Hello")])) == "<root id=\"1\">Hello</root>"

# Nested elements
expect {
	tree = el(
		"root",
		[
			el("child", [Node.text("Hello")]),
			el("child", [Node.text("World")]),
		],
	)
	Render.render(tree) == "<root><child>Hello</child><child>World</child></root>"
}

# Special characters in text, with quotes written as they are
expect Render.render(Node.text("Ben & Jerry's said \"hi\"")) == "Ben &amp; Jerry's said \"hi\""

# Special characters in an attribute
expect Render.render(Node.element("root", Dict.single("value", "a<b"), [])) == "<root value=\"a&lt;b\"></root>"

# Empty element
expect Render.render(el("empty", [])) == "<empty></empty>"

# Empty text node
expect Render.render(el("root", [Node.text("")])) == "<root></root>"

# Attributes are written in the order they were inserted
expect {
	tree = Node.element("tag", Dict.from_list([("c", "3"), ("a", "1"), ("b", "2")]), [])
	Render.render(tree) == "<tag c=\"3\" a=\"1\" b=\"2\"></tag>"
}

# An attribute given twice is written once, where it first stood and with its last value
expect {
	tree = Node.element("tag", Dict.from_list([("id", "1"), ("class", "c"), ("id", "2")]), [])
	Render.render(tree) == "<tag id=\"2\" class=\"c\"></tag>"
}

# Deeply nested elements
expect {
	tree = el("level1", [el("level2", [el("level3", [el("level4", [Node.text("deep")])])])])
	Render.render(tree) == "<level1><level2><level3><level4>deep</level4></level3></level2></level1>"
}

# Mixed children, text and elements
expect {
	tree = el(
		"p",
		[
			Node.text("Hello "),
			el("strong", [Node.text("world")]),
			Node.text("!"),
		],
	)
	Render.render(tree) == "<p>Hello <strong>world</strong>!</p>"
}

# Unicode in text
expect Render.render(el("root", [Node.text("Héllo wörld 🎉")])) == "<root>Héllo wörld 🎉</root>"

# Unicode in attributes
expect {
	tree = Node.element("root", Dict.from_list([("emoji", "🚀"), ("name", "Ñoño")]), [])
	Render.render(tree) == "<root emoji=\"🚀\" name=\"Ñoño\"></root>"
}

# Newlines in text
expect Render.render(el("pre", [Node.text("line1\nline2\nline3")])) == "<pre>line1\nline2\nline3</pre>"

# Whitespace in attributes
expect Render.render(Node.element("tag", Dict.single("value", "  spaces  "), [])) == "<tag value=\"  spaces  \"></tag>"

# Empty attribute value
expect Render.render(Node.element("input", Dict.single("disabled", ""), [])) == "<input disabled=\"\"></input>"

# Number and boolean nodes
expect Render.render(el("count", [Node.num(42.I64)])) == "<count>42</count>"
expect Render.render(el("price", [Node.num(19.99)])) == "<price>19.99</price>"
expect Render.render(el("enabled", [Node.bool(Bool.True)])) == "<enabled>true</enabled>"

# A replacement is text like any other, so its markup is escaped
expect Render.render(Node.text_lossy("bell\u(7)", ReplaceWith(|code_point| "<U+${code_point.to_str()}>"))) == "bell&lt;U+7&gt;"

# Tab, newline and carriage return are the control characters XML allows.
# A carriage return is written as a character reference, since a parser would
# otherwise turn it into a newline.
expect Render.render(Node.text("a\tb\nc\rd")) == "a\tb\nc&#13;d"
expect Render.render(Node.text("a\r\nb")) == "a&#13;\nb"

# Tab, newline and carriage return in an attribute value are written as
# character references, since attribute value normalisation would otherwise
# turn them into spaces
expect Render.render(Node.element("a", Dict.single("v", "x\ny\tz\r"), [])) == "<a v=\"x&#10;y&#9;z&#13;\"></a>"

# Namespace prefixes and non-ASCII letters are written as they are
expect Render.render(Node.element("xmlns:r", Dict.single("r:id", "rId1"), [])) == "<xmlns:r r:id=\"rId1\"></xmlns:r>"
expect Render.render(Node.element("café", Dict.single("日本", "x"), [])) == "<café 日本=\"x\"></café>"
