app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.26.0/EuuihZ91yAY1ANck1QytRBcW2jexEfH6yVmxcPCHEHDz.tar.zst",
	xml: "../package/main.roc",
}

import pf.Stdout
import xml.Document
import xml.Element
import xml.Node exposing [Node]

main! = |args| {
	# Use `Node.text`, `Node.element` and the other constructors to build up your tree. Wrap it in
	# an `Element`, which ensures that it is well-formed XML.
	#
	# Attributes are a `Dict`, so an element can't have the same attribute twice. Use `Dict.empty()`
	# for none, `Dict.single` for one and `Dict.from_list` for several.
	library = Element.new(
		"library",
		Dict.single("version", "1.0"),
		[
			Node.element(
				"book",
				Dict.from_list([("id", "1"), ("lang", "en")]),
				[
					# Markup characters like the "&" here are escaped for you
					Node.element("title", Dict.empty(), [Node.text("Roc & XML")]),
					# `Node.num` and `Node.bool` are shorthands for text holding a number or a boolean
					Node.element("price", Dict.empty(), [Node.num(29.99)]),
					Node.element("in_stock", Dict.empty(), [Node.bool(Bool.True)]),
				],
			),
			Node.element("book", Dict.empty(), [Node.text("Hello")]),
		],
	)?

	# You can either render an `Element` fragment or a full `Document` (which adds the XML
	# declaration). The output is valid XML 1.0 in UTF-8 regardless, since XML doesn't require a
	# declaration.
	Stdout.line!("== A document")?
	Stdout.line!(Document.render(library))?

	Stdout.line!("\n== The same element as a fragment")?
	Stdout.line!(Element.render(library))?

	# `Element.new` errors on invalid input like certain control characters which aren't allowed in
	# XML 1.0, or invalid/empty tag/attribute names. That's what the `?` above is for.
	#
	# Here the second note holds a bell character, which XML can't express. We add one note per
	# command line argument so that the list is only known when the program runs. Roc would
	# otherwise work out the result while type checking (see `workbook_xml` below).
	notes = ["fine", "ring\u(7) ring"].concat(args.map(|_| "fine"))

	Stdout.line!("\n== What `Element.new` tells you about invalid input")?
	match Element.new("notes", Dict.empty(), notes.map(note)) {
		Ok(_) => Stdout.line!("unexpected: a bell character passed the check")?
		Err(InvalidXml(problems)) => {
			# We try to give you as detailed and actionable information as possible to help you
			# troubleshoot the issue in the input. You get every problem in the tree, not just
			# the first one.
			Stdout.line!(Str.join_with(problems.map(describe), "\n"))?
		}
	}

	# If you'd rather avoid error handling you can use `Element.new_lossy` which avoids erroring by
	# "fixing" any issues. Use it when you're confident that your input is valid, or when you can
	# accept that the XML you're getting may be altered to conform to the standard.
	#
	# There's no `?` and no `match` here, since there's no error to handle.
	repaired = Element.new_lossy(
		# An invalid name: a name cannot contain a space, so it becomes "_"
		"my notes",
		Dict.from_list([
			# An empty name becomes "_"
			("", "2026"),
			# A name cannot start with a digit, so it gets a "_" in front
			("1st", "yes"),
		]),
		[
			# A control character in text is dropped, since we said `Drop`
			Node.element("note", Dict.empty(), [Node.text("ring\u(7) ring")]),
			# So is one in an attribute value
			Node.element("note", Dict.single("id", "a\u(0)b"), []),
		],
		Drop,
	)

	Stdout.line!("\n== `Element.new_lossy` fixes the issues instead")?
	Stdout.line!(Element.render(repaired))?

	# `Drop` is one of three things you can do with a character XML can't express. You can also
	# `Replace` each one with a string, or give `ReplaceWith` a function which determines how each
	# code point is replaced.
	replaced = Element.new_lossy("notes", Dict.empty(), notes.map(note), Replace("?"))

	Stdout.line!("\n== The same notes as above, with `Replace(\"?\")`")?
	Stdout.line!(Element.render(replaced))?

	# `Node.text_lossy` does the same for a single text node, which can be convenient to avoid
	# errors when using `Element.new`. Here only the cells are repaired, and everything else in
	# the tree is still checked.
	cell = |value| Node.element("cell", Dict.empty(), [Node.text_lossy(value, ReplaceWith(|code_point| "<U+${code_point.to_str()}>"))])
	row = Element.new("row", Dict.empty(), notes.map(cell))?

	Stdout.line!("\n== `Node.text_lossy` with `ReplaceWith`")?
	Stdout.line!(Element.render(row))?

	Stdout.line!("\n== A document checked at compile time")?
	Stdout.line!(workbook_xml)?

	Ok({})
}

## A note holding some text. A function that builds part of a tree returns a `Node`, and goes
## into a list of children like any other node.
note : Str -> Node
note = |content| Node.element("note", Dict.empty(), [Node.text(content)])

## A problem as a sentence. `path` runs from the root down to the element concerned, and each
## step names the element and its position among its siblings, so with several `note` elements
## it says which one.
describe : Element.Problem -> Str
describe = |problem| {
	location = Str.join_with(problem.path.map(|step| "${step.tag}[${step.index.to_str()}]"), "/")
	what = match problem.kind {
		InvalidChar({ code_point, byte_index, .. }) => "code point ${code_point.to_str()} at byte ${byte_index.to_str()} can't be written in XML"
		EmptyName(_) => "a name is empty"
	}
	"${location}: ${what}"
}

## Roc evaluates expressions built from literals while type checking, so a constant document can
## be destructured without handling the error. A name XML cannot express is then a compile error
## rather than a runtime one. Try changing "workbook" to "work book" and run `roc check`.
workbook_xml : Str
workbook_xml = {
	Ok(root) = Element.new("workbook", Dict.empty(), [Node.element("sheets", Dict.empty(), [])])
	Document.render(root)
}
