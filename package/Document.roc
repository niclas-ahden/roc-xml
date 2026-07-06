## XML documents: a root node plus an optional XML declaration.
import Node exposing [Node]

## XML document with optional declaration
Doc : {
	root : Node,
	declaration : [NoDeclaration, Declaration({ encoding : Str, version : Str })],
}

Document := [].{

	## Create a document with standard XML 1.0 UTF-8 declaration
	with_declaration : Node -> Doc
	with_declaration = |root|
		{ root, declaration: Declaration({ version: "1.0", encoding: "UTF-8" }) }

	## Render a document to string
	render : Doc -> Str
	render = |doc|
		match doc.declaration {
			NoDeclaration => Node.render(doc.root)
			Declaration({ encoding, version }) => {
				escaped_version = escape_attr(version)
				escaped_encoding = escape_attr(encoding)
				"<?xml version=\"${escaped_version}\" encoding=\"${escaped_encoding}\"?>\n${Node.render(doc.root)}"
			}
		}
}

# Escape attribute values (quotes and ampersands)
escape_attr : Str -> Str
escape_attr = |s|
	s
		->replace_each("&", "&amp;")
		->replace_each("\"", "&quot;")

# Replace every occurrence of `from` in `s` with `to`.
replace_each : Str, Str, Str -> Str
replace_each = |s, from, to|
	Str.join_with(s.split_on(from), to)

# Document without declaration
expect {
	doc = {
		root: Node.element("root", [], [Node.text("Hello")]),
		declaration: NoDeclaration,
	}
	result = Document.render(doc)
	result == "<root>Hello</root>"
}

# Document with declaration
expect {
	doc = {
		root: Node.element("root", [], [Node.text("Hello")]),
		declaration: Declaration({ version: "1.0", encoding: "UTF-8" }),
	}
	result = Document.render(doc)
	result == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>Hello</root>"
}

# Document with custom encoding
expect {
	doc = {
		root: Node.element("root", [], []),
		declaration: Declaration({ version: "1.1", encoding: "ISO-8859-1" }),
	}
	result = Document.render(doc)
	result == "<?xml version=\"1.1\" encoding=\"ISO-8859-1\"?>\n<root></root>"
}

# with_declaration helper
expect {
	doc = Document.with_declaration(Node.element("root", [], [Node.text("Hello")]))
	result = Document.render(doc)
	result == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>Hello</root>"
}

# Document with nested structure
expect {
	doc = Document.with_declaration(
		Node.element(
			"catalog",
			[],
			[
				Node.element(
					"book",
					[Node.attribute("id", "1")],
					[
						Node.element("title", [], [Node.text("Roc Programming")]),
						Node.element("price", [], [Node.num(29.99)]),
					],
				),
			],
		),
	)
	result = Document.render(doc)
	result == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<catalog><book id=\"1\"><title>Roc Programming</title><price>29.99</price></book></catalog>"
}

# Declaration with special characters is escaped
expect {
	doc = {
		root: Node.element("root", [], []),
		declaration: Declaration({ version: "1.0\"", encoding: "UTF-8&" }),
	}
	result = Document.render(doc)
	result == "<?xml version=\"1.0&quot;\" encoding=\"UTF-8&amp;\"?>\n<root></root>"
}
