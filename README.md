# roc-xml

Simple XML generation in Roc.

## Quick start

```roc
app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0-rc1/3hT3SoHZ6qbEsa9qVFLUW3547U5LeoNd1KbpqLpz4r1i.tar.zst",
    xml: "https://github.com/niclas-ahden/roc-xml/releases/download/2.0.0/66gygDre4vwq7EReM2UQdvKQyvCJjCitFaFUuESpkqnR.tar.zst",
}

import pf.Stdout
import xml.Document
import xml.Element
import xml.Node

main! = |_args| {
    library = Element.new(
        "library",
        Dict.single("version", "1.0"),
        [
            Node.element("book", Dict.from_list([("id", "1"), ("lang", "en")]), [Node.text("Roc & XML")]),
            Node.element("book", Dict.empty(), [Node.text("Hello")]),
        ],
    )?

    Stdout.line!(Document.render(library))?

    # The above errors on invalid input like certain control characters which aren't allowed in
    # XML 1.0, or invalid/empty tag/attribute names. If you'd rather avoid error handling you
    # can use `Element.new_lossy` which avoids erroring by "fixing" any issues. It drops or replaces
    # invalid characters in text and attribute values, and repairs invalid tag and attribute names
    # with "_", so "bad tag" becomes "bad_tag" and an empty name becomes "_".
    note = Element.new_lossy("note", Dict.empty(), [Node.text("ring\u(7) ring")], Drop)

    Stdout.line!(Element.render(note))?

    Ok({})
}
```

Output:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<library version="1.0"><book id="1" lang="en">Roc &amp; XML</book><book>Hello</book></library>
<note>ring ring</note>
```

You can either render an `Element` fragment or a full `Document` (which adds
the XML declaration). The output is valid XML 1.0 in UTF-8 regardless, since
XML doesn't require a declaration.

## How building works

Use `Node.text`, `Node.element` and the other constructors to build up your
tree. Wrap it in an `Element`, which ensures that it is well-formed XML:

- `Element.new` checks the tree and returns the element or every problem in
  the tree.
- `Element.new_lossy` repairs the tree instead, and cannot fail.

Then optionally wrap that in a `Document.render` if you want an XML declaration,
or just call `Element.render` to render the fragment you've got.

### Attributes

Attributes are a `Dict` from name to value, so an element cannot have the
same attribute twice. Use `Dict.empty()` for none, `Dict.single` for one and
`Dict.from_list` for several. They are rendered in the order they were
inserted.

Markup characters in text and attribute values are escaped when rendered.
So is whitespace a parser would otherwise normalise away: a carriage return
in text, and tab, newline and carriage return in attribute values, are
written as character references. A parser reads back exactly the strings
that went in.

**Note:** Right now you're using these long `Dict.from_list(...)` ways of
adding attributes, but Roc will probably add a way to write `Dict` literals
in the future like `{"foo": "bar"}` or such. I'm anticipating that with this
API choice, but if it doesn't come to fruition we can always change how we
add attributes.

### `Element.new`

What cannot be escaped is reported in a highly specific error:

```roc
Element.new("a", Dict.empty(), [Node.text("bell\u(7)")])
    == Err(
        InvalidXml([
            {
                path: [{ tag: "a", index: 0 }],
                kind: InvalidChar({
                    code_point: 7,
                    byte_index: 4,
                    found_in: Content(0),
                }),
            },
        ]),
    )
```

We try to give you as detailed and actionable information as possible to
help you troubleshoot the issue in the input. Hopefully this leads to less
frustration when some weird characters sneak their way into your documents.

`path` runs from the root down to the element concerned. Each step names
the element and its position among its parent's children, text nodes
counted, so with several `book` elements it says which one. The root has
position 0. `kind` is one of:

- `InvalidChar`: XML 1.0 has no way to write the control characters U+0000
  to U+001F other than tab, newline and carriage return, nor U+FFFE and
  U+FFFF. Tag and attribute names are stricter still and follow the XML
  `Name` grammar, so no spaces, no `<`, `=` or quotes, and no leading digit,
  hyphen or period. `found_in` is `Content(index)`, `TagName`,
  `AttributeName(name)` or `AttributeValue(name)`. The index is the position
  of the text node among its parent's children.
- `EmptyName`: a tag or attribute name is empty.

These are the XML 1.0 well-formedness rules. Namespaces in XML is not
checked, so `a:b:c` passes as a name although it is not a QName.

### `Element.new_lossy`

Use this when you're confident that your input is valid or when you'd
rather not handle errors and can accept that the XML you're getting may
be altered to conform to the standard:

```roc
notes = Element.new_lossy(
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

Element.render(notes)
```

Output:

```xml
<my_notes _="2026" _1st="yes"><note>ring ring</note><note id="ab"></note></my_notes>
```

The last argument says what happens to each character XML cannot express,
and is one of:

- `Drop`: leave each one out, so `"a\u(0)b\u(7)c"` becomes `"abc"`.
- `Replace(str)`: with `Replace("?")` it becomes `"a?b?c"`.
- `ReplaceWith(fn)`: pass in `fn` which determines how each code point
  is replaced.

That goes for text and attribute values. Names are repaired the same way
whatever you chose: a character a name cannot contain becomes `_`, one it
cannot start with gets a `_` in front, so `1st` becomes `_1st`, and an empty
name becomes `_`. Should two attribute names of an element be repaired into
the same name, the value of the last one is kept.

### One piece of text: `Node.text_lossy`

`Node.text_lossy` does the same for a single text node, which can be convenient
to avoid errors when using `Element.new`. For example:

```roc
cell = |value| Node.text_lossy(value, ReplaceWith(|code_point| "<U+${code_point.to_str()}>"))
```

### Trees built from literals

Roc evaluates expressions built from literals while type checking, so a
constant document can be destructured without handling the error. A name
XML cannot express is then a compile error rather than a runtime one:

```roc
workbook_xml : Str
workbook_xml = {
    Ok(root) = Element.new("workbook", Dict.empty(), [Node.element("sheets", Dict.empty(), [])])
    Document.render(root)
}
```

## Documentation

View the API documentation at [https://niclas-ahden.github.io/roc-xml/](https://niclas-ahden.github.io/roc-xml/).
