## Making a tree into one XML can express. Internal to the package.
import Chars
import Check
import Node exposing [Node]

Repair := [].{

	## The tree with everything `Check.problems` would find in it repaired,
	## so that `Check.is_clean` holds for the result. The rules are those
	## documented on `Element.new_lossy`. A clean tree is returned as it is.
	repair : Node, Node.Replacement -> Node
	repair = |node, replacement|
		if Check.is_clean(node) {
			node
		} else {
			repair_node(node, replacement)
		}
}

repair_node : Node, Node.Replacement -> Node
repair_node = |node, replacement|
	match node {
		TextNode(content) => Node.text(Chars.replace_invalid(content, replacement))
		ElementNode({ tag, attributes, children }) => {
			# Two names can be repaired into the same one. Inserting in order
			# keeps the place of the first and the value of the last, which is
			# what `Dict.from_list` does with a repeated name.
			repaired_attributes = attributes.fold(
				Dict.with_capacity(attributes.len()),
				|acc, name, value| acc.insert(Chars.repair_name(name), Chars.replace_invalid(value, replacement)),
			)
			Node.element(Chars.repair_name(tag), repaired_attributes, children.map(|child| repair_node(child, replacement)))
		}
	}

# An element without attributes, to keep the trees in tests short
el : Str, List(Node) -> Node
el = |tag, children| Node.element(tag, Dict.empty(), children)

# A clean tree comes back as it is
expect {
	tree = Node.element("a", Dict.single("id", "1"), [Node.text("x"), el("b", [])])
	Repair.repair(tree, Drop) == tree
}

# Characters XML cannot express are dropped or replaced, in text and in attribute values
expect
	Repair.repair(Node.element("a", Dict.single("id", "x\u(0)y"), [Node.text("bell\u(7)")]), Drop)
		== Node.element("a", Dict.single("id", "xy"), [Node.text("bell")])

expect
	Repair.repair(Node.element("a", Dict.single("id", "x\u(0)y"), [Node.text("bell\u(7)")]), Replace("?"))
		== Node.element("a", Dict.single("id", "x?y"), [Node.text("bell?")])

expect
	Repair.repair(el("a", [Node.text("bell\u(7)")]), ReplaceWith(|code_point| "<U+${code_point.to_str()}>"))
		== el("a", [Node.text("bell<U+7>")])

# Every level of the tree is repaired
expect
	Repair.repair(el("a", [el("b", [el("c", [Node.text("\u(1)deep")])])]), Drop)
		== el("a", [el("b", [el("c", [Node.text("deep")])])])

# A text node on its own is repaired too
expect Repair.repair(Node.text("\u(C)x"), Drop) == Node.text("x")

# Names are repaired the same way whatever the replacement
expect Repair.repair(el("bad tag", []), Drop) == el("bad_tag", [])
expect Repair.repair(el("bad tag", []), Replace("?")) == el("bad_tag", [])
expect Repair.repair(el("1st", []), Drop) == el("_1st", [])
expect Repair.repair(el("", []), Drop) == el("_", [])
expect Repair.repair(Node.element("a", Dict.single("x=y", "v"), []), Drop) == Node.element("a", Dict.single("x_y", "v"), [])
expect Repair.repair(Node.element("a", Dict.single("", "v"), []), Drop) == Node.element("a", Dict.single("_", "v"), [])

# Text cleaned on its own keeps its replacement, whatever the tree is given
expect
	Repair.repair(el("bad tag", [Node.text_lossy("bell\u(7)", Replace("!")), Node.text("bell\u(7)")]), Drop)
		== el("bad_tag", [Node.text("bell!"), Node.text("bell")])

# The attributes of an element in order, for tests where the order matters
attributes_of : Node -> List((Str, Str))
attributes_of = |node|
	match node {
		ElementNode({ attributes, .. }) => attributes.to_list()
		TextNode(_) => []
	}

# Two attribute names repaired into the same one: the place of the first, the value of the last
expect {
	tree = Node.element("a", Dict.from_list([("x y", "1"), ("id", "2"), ("x_y", "3"), ("x=y", "4")]), [])
	attributes_of(Repair.repair(tree, Drop)) == [("x_y", "4"), ("id", "2")]
}

# What repairing returns is always clean
expect {
	trees = [
		Node.text("\u(C)"),
		Node.text("\u(FFFE)"),
		el("", []),
		el("bad tag", []),
		el("🎉 1", [el("-", [Node.text("\u(0)\u(1)")])]),
		Node.element("a", Dict.single("", "x"), []),
		Node.element("a", Dict.single("1", "x"), []),
		Node.element("a", Dict.from_list([("x", "\u(0)"), ("x y", "\u(FFFF)"), ("x_y", "")]), []),
		el("a", [el("b", [el("c", [Node.text("\u(1)")])])]),
	]
	replacements = [Drop, Replace("?"), Replace("\u(0)"), Replace("")]
	trees.all(|tree| !Check.is_clean(tree))
		and trees.all(|tree| replacements.all(|replacement| Check.is_clean(Repair.repair(tree, replacement))))
}

# So is it with a function for a replacement, even one that returns what XML cannot express
expect Check.is_clean(Repair.repair(el("a b", [Node.text("\u(1)")]), ReplaceWith(|_| "\u(2)")))
