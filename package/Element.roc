## A tree known to be well-formed XML, which is what rendering needs.
##
## There are two ways to make one from a root element. [Element.new] checks
## the tree and reports every problem in it. [Element.new_lossy] repairs the
## tree instead, and cannot fail. Either way the result was rendered when it
## was made, so [Element.render] and [Document.render] cannot fail.
import Check
import Node exposing [Node]
import Render
import Repair

Element :: { node : Node, rendered : Str }.{

	## Something in a tree that XML cannot express, and where it is.
	##
	## `path` runs from the root down to the element concerned. Each step
	## names the element and its position among its parent's children, text
	## nodes counted, so with several `book` elements it says which one. The
	## root has position 0, since nothing above it was seen. For a bad or
	## empty tag name the last step is that name.
	##
	## - `InvalidChar`: XML 1.0 has no way to write the control characters
	##   U+0000 to U+001F other than tab, newline and carriage return, nor
	##   U+FFFE and U+FFFF. Tag and attribute names are stricter still: they
	##   follow the XML `Name` grammar, so no spaces, no `<`, `=` or quotes,
	##   and no leading digit, hyphen or period. `code_point` is the
	##   character, `byte_index` where it starts in the string that holds it,
	##   and `found_in` which string that is. `Content` carries the position
	##   of the text node among its parent's children, counted like the
	##   positions in `path`.
	## - `EmptyName`: a tag or attribute name is empty.
	##
	## The checks are those of XML 1.0 well-formedness. Namespaces in XML is
	## a separate specification and is not checked, so `a:b:c` passes as a
	## name although it is not a QName, and names starting with `xml` pass
	## although they are reserved.
	Problem : {
		path : List({ tag : Str, index : U64 }),
		kind : [
			InvalidChar({ code_point : U32, byte_index : U64, found_in : [Content(U64), TagName, AttributeName(Str), AttributeValue(Str)] }),
			EmptyName([TagName, AttributeName]),
		],
	}

	## An element with the given tag, attributes and children, or every
	## problem found in it and the tree below it, in document order. Nothing
	## is lost by building a whole tree before looking at the result, since
	## each problem comes with the path to its element.
	##
	## ```roc
	## Element.new("a", Dict.empty(), [Node.text("bell\u(7)")])
	## == Err(InvalidXml([{ path: [{ tag: "a", index: 0 }], kind: InvalidChar({ code_point: 7, byte_index: 4, found_in: Content(0) }) }]))
	## ```
	##
	## Given literals alone, the compiler evaluates this while type checking.
	## `Ok(root) = Element.new(...)` then needs no error handling, and a tree
	## XML cannot express is a compile error.
	new : Str, Dict(Str, Str), List(Node) -> Try(Element, [InvalidXml(List(Problem))])
	new = |tag, attributes, children| {
		node = Node.element(tag, attributes, children)
		# Most trees are clean, and finding that out is much cheaper than
		# collecting problems with their paths
		problems = if Check.is_clean(node) {
			[]
		} else {
			Check.problems(node)
		}
		if problems.is_empty() {
			Ok(Element.{ node, rendered: Render.render(node) })
		} else {
			Err(InvalidXml(problems))
		}
	}

	## An element with the given tag, attributes and children, with
	## everything [Element.new] would report repaired instead. This cannot
	## fail, and a tree without problems comes out the same as from
	## [Element.new].
	##
	## - A character XML cannot express, in text or in an attribute value, is
	##   dropped or replaced as `replacement` says.
	## - A character a name cannot contain becomes `_`, whatever
	##   `replacement` says. A character a name can contain but not start
	##   with, like a digit, gets a `_` in front. An empty name becomes `_`.
	## - Should two attribute names of an element be repaired into the same
	##   name, the attribute stands where the first stood and has the value
	##   of the last.
	##
	## ```roc
	## Element.new_lossy("note", Dict.empty(), [Node.text("bell\u(7)")], Drop).render() == "<note>bell</note>"
	## ```
	##
	## A name that needed repair is a mistake in the program rather than in
	## its input, and this does not tell you about it. A test that gives the
	## same tree to [Element.new] does.
	new_lossy : Str, Dict(Str, Str), List(Node), Node.Replacement -> Element
	new_lossy = |tag, attributes, children, replacement| {
		node = Repair.repair(Node.element(tag, attributes, children), replacement)
		Element.{ node, rendered: Render.render(node) }
	}

	## The element as a node, to place it among the children of another. From
	## [Element.new_lossy] it is the repaired tree. It is checked or repaired
	## again as part of the tree it is placed in.
	to_node : Element -> Node
	to_node = |element| element.node

	## Render as a fragment, without a declaration. The element was rendered
	## when it was made, so this cannot fail.
	##
	## Markup characters in text and attribute values are escaped. So is
	## whitespace that a parser would otherwise normalise away: a carriage
	## return in text, and tab, newline and carriage return in attribute
	## values, are written as character references, so a parser reads back
	## exactly the strings that went in.
	render : Element -> Str
	render = |element| element.rendered

	## Structural equality, as for [Node].
	is_eq : Element, Element -> Bool
	is_eq = |a, b| a.node == b.node
}

# Render an element built in a test, or pass its problems through
rendered : Try(Element, [InvalidXml(List(Element.Problem))]) -> Try(Str, [InvalidXml(List(Element.Problem))])
rendered = |tree|
	match tree {
		Ok(element) => Ok(element.render())
		Err(err) => Err(err)
	}

# A path step, to keep the expected paths in tests short
at : Str, U64 -> { tag : Str, index : U64 }
at = |tag, index| { tag, index }

# An element node without attributes, to keep the trees in tests short
el : Str, List(Node) -> Node
el = |tag, children| Node.element(tag, Dict.empty(), children)

# An element renders like the node it is
expect rendered(Element.new("root", Dict.single("id", "1"), [Node.text("Hello")])) == Ok("<root id=\"1\">Hello</root>")

# Every problem in the tree comes out, with the root at the top of each path
expect
	Element.new("root", Dict.empty(), [el("bad tag", [Node.text("\u(0)")])])
		== Err(
			InvalidXml([
				{ path: [at("root", 0), at("bad tag", 0)], kind: InvalidChar({ code_point: ' ', byte_index: 3, found_in: TagName }) },
				{ path: [at("root", 0), at("bad tag", 0)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: Content(0) }) },
			]),
		)

# The root's own tag and attributes are checked like any other
expect Element.new("", Dict.empty(), []) == Err(InvalidXml([{ path: [at("", 0)], kind: EmptyName(TagName) }]))
expect
	Element.new("a", Dict.single("id", "\u(0)"), [])
		== Err(InvalidXml([{ path: [at("a", 0)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: AttributeValue("id") }) }]))

# Lossy text leaves nothing for the check to find
expect rendered(Element.new("t", Dict.empty(), [Node.text_lossy("bell\u(7)", ReplaceWith(|code_point| "_x000${code_point.to_str()}_"))])) == Ok("<t>bell_x0007_</t>")

# A tree built from literals is proven while type checking, so this needs no error handling
literal : Str
literal = {
	Ok(root) = Element.new("catalog", Dict.empty(), [Node.element("book", Dict.single("id", "1"), [Node.text("Roc")])])
	root.render()
}

expect literal == "<catalog><book id=\"1\">Roc</book></catalog>"

# A lossy element drops what XML cannot express, in text and in attribute values
expect Element.new_lossy("note", Dict.empty(), [Node.text("bell\u(7)")], Drop).render() == "<note>bell</note>"
expect Element.new_lossy("note", Dict.single("id", "a\u(0)b"), [], Drop).render() == "<note id=\"ab\"></note>"

# Or replaces it, by a string or by what a function returns
expect Element.new_lossy("note", Dict.empty(), [Node.text("bell\u(7)")], Replace("?")).render() == "<note>bell?</note>"
expect
	Element.new_lossy("note", Dict.empty(), [Node.text("bell\u(7)")], ReplaceWith(|code_point| "_x000${code_point.to_str()}_")).render()
		== "<note>bell_x0007_</note>"

# A replacement is text like any other, so its markup is escaped
expect Element.new_lossy("note", Dict.empty(), [Node.text("bell\u(7)")], Replace("<bell>")).render() == "<note>bell&lt;bell&gt;</note>"

# Names are repaired, the root's own and those below it
expect Element.new_lossy("bad tag", Dict.single("1", "x"), [el("", [])], Drop).render() == "<bad_tag _1=\"x\"><_></_></bad_tag>"

# Text cleaned on its own keeps its replacement, and the rest of the tree gets the tree's
expect
	Element.new_lossy("row", Dict.empty(), [Node.text_lossy("a\u(7)", Replace("!")), Node.text("b\u(7)")], Drop).render()
		== "<row>a!b</row>"

# A clean tree comes out the same from both
expect {
	children = [Node.element("book", Dict.single("id", "1"), [Node.text("Ben & Jerry\r\n")])]
	Element.new("shelf", Dict.single("n", "1"), children) == Ok(Element.new_lossy("shelf", Dict.single("n", "1"), children, Drop))
		and rendered(Element.new("shelf", Dict.single("n", "1"), children)) == Ok(Element.new_lossy("shelf", Dict.single("n", "1"), children, Drop).render())
}

# What a lossy element holds is the repaired tree, which the check finds nothing in
expect {
	lossy = Element.new_lossy("bad tag", Dict.single("x y", "\u(0)"), [Node.text("\u(1)"), el("1", [])], Replace("\u(2)"))
	lossy.to_node() == Node.element("bad_tag", Dict.single("x_y", "\u(FFFD)"), [Node.text("\u(FFFD)"), el("_1", [])])
		and Check.is_clean(lossy.to_node())
}

# An element goes among the children of another as a node
expect
	match Element.new("inner", Dict.empty(), []) {
		Ok(inner) => rendered(Element.new("outer", Dict.empty(), [inner.to_node()])) == Ok("<outer><inner></inner></outer>")
		Err(_) => Bool.False
	}

expect {
	inner = Element.new_lossy("in ner", Dict.empty(), [], Drop)
	rendered(Element.new("outer", Dict.empty(), [inner.to_node()])) == Ok("<outer><in_ner></in_ner></outer>")
}

# Elements compare like their nodes
expect Element.new("a", Dict.empty(), []) == Element.new("a", Dict.empty(), [])
expect Element.new("a", Dict.empty(), []) != Element.new("b", Dict.empty(), [])
expect Element.new_lossy("a b", Dict.empty(), [], Drop) == Element.new_lossy("a_b", Dict.empty(), [], Drop)

# Part of a tree can be checked early by making it an element. Its problems
# come with paths from that element, and it goes into a larger tree as a node.
book_with_title : Str, Str -> Try(Node, [BadTitle(List(Element.Problem))])
book_with_title = |title, subtitle| {
	title_element = Element.new("title", Dict.empty(), [Node.text(title)]) ? |InvalidXml(problems)| BadTitle(problems)
	Ok(el("book", [title_element.to_node(), el("subtitle", [Node.text(subtitle)])]))
}

expect book_with_title("\u(0)", "fine") == Err(BadTitle([{ path: [at("title", 0)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: Content(0) }) }]))

# The rest of the tree is checked at the root, with full paths
expect
	match book_with_title("fine", "\u(1)") {
		Ok(book) => Element.new("shelf", Dict.empty(), [book]) == Err(InvalidXml([{ path: [at("shelf", 0), at("book", 0), at("subtitle", 1)], kind: InvalidChar({ code_point: 1, byte_index: 0, found_in: Content(0) }) }]))
		Err(_) => Bool.False
	}

expect
	match book_with_title("fine", "also fine") {
		Ok(book) => rendered(Element.new("shelf", Dict.empty(), [book])) == Ok("<shelf><book><title>fine</title><subtitle>also fine</subtitle></book></shelf>")
		Err(_) => Bool.False
	}

# Errors of your own are handled before the tree is checked, the way any
# Roc error is
titled : Str -> Try(Node, [EmptyTitle])
titled = |title|
	if title.is_empty() {
		Err(EmptyTitle)
	} else {
		Ok(el("book", [Node.text(title)]))
	}

library : List(Str) -> Try(Element, [EmptyTitle, InvalidXml(List(Element.Problem))])
library = |titles| {
	books = titles.map_try(titled)?
	Element.new("library", Dict.empty(), books)
}

expect library(["a", "", ""]) == Err(EmptyTitle)
expect library(["a", "\u(0)"]) == Err(InvalidXml([{ path: [at("library", 0), at("book", 1)], kind: InvalidChar({ code_point: 0, byte_index: 0, found_in: Content(0) }) }]))
expect
	match library(["a", "b"]) {
		Ok(element) => element.render() == "<library><book>a</book><book>b</book></library>"
		Err(_) => Bool.False
	}
