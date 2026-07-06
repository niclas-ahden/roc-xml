app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
	xml: "../package/main.roc",
}

import pf.Stdout
import xml.Node
import xml.Document

main! = |_args| {
	# Build a document and render it to a string.
	root = Node.element(
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
	)
	doc = Document.with_declaration(root)
	rendered = Document.render(doc)
	Stdout.line!("Rendered:")
	Stdout.line!(rendered)

	Ok({})
}
