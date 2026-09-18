## Rendering a complete XML document.
import Element exposing [Element]
import Node

Document := [].{

	## `root` as a complete document, with the declaration
	## `<?xml version="1.0" encoding="UTF-8"?>` in front.
	##
	## Those are the only version and encoding the package can produce: Roc
	## strings are UTF-8, and the characters and names it checks for are
	## those of XML 1.0. A document without a declaration is also XML 1.0,
	## so use [Element.render] to render without one.
	##
	## A document needs an element at its root, which is why this takes an
	## [Element] rather than a [Node]. Every part of it was checked or
	## repaired when it was made, so the result is well-formed.
	render : Element -> Str
	render = |root| {
		# Written out in full: `root.render()` here resolves to this very
		# function and recurses until the stack runs out
		body = Element.render(root)
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n${body}"
	}
}

# Render a document from an element built in a test, or pass its problems through
rendered : Try(Element, [InvalidXml(List(Element.Problem))]) -> Try(Str, [InvalidXml(List(Element.Problem))])
rendered = |root|
	match root {
		Ok(element) => Ok(Document.render(element))
		Err(err) => Err(err)
	}

# Document with text
expect rendered(Element.new("root", Dict.empty(), [Node.text("Hello")])) == Ok("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>Hello</root>")

# Empty root element
expect rendered(Element.new("root", Dict.empty(), [])) == Ok("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root></root>")

# Document with nested structure
expect {
	root = Element.new(
		"catalog",
		Dict.empty(),
		[
			Node.element(
				"book",
				Dict.single("id", "1"),
				[
					Node.element("title", Dict.empty(), [Node.text("Roc Programming")]),
					Node.element("price", Dict.empty(), [Node.num(29.99)]),
				],
			),
		],
	)
	rendered(root) == Ok("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<catalog><book id=\"1\"><title>Roc Programming</title><price>29.99</price></book></catalog>")
}

# Problems anywhere in the document come out at the root, with their paths
expect {
	root = Element.new("root", Dict.empty(), [Node.element("item", Dict.empty(), [Node.text("\u(0)")])])
	rendered(root) == Err(InvalidXml([{ path: [{ tag: "root", index: 0 }, { tag: "item", index: 0 }], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: Content(0) }) }]))
}

# A lossy element makes a document without any error handling
expect
	Document.render(Element.new_lossy("root", Dict.empty(), [Node.element("item", Dict.empty(), [Node.text("bell\u(7)")])], Drop))
		== "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root><item>bell</item></root>"
