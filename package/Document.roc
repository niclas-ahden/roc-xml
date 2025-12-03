module [
    Document,
    render,
    with_declaration,
]

import Node exposing [Node]

## XML document with optional declaration
Document : {
    root : Node,
    declaration : [NoDeclaration, Declaration { encoding : Str, version : Str }],
}

## Create a document with standard XML 1.0 UTF-8 declaration
with_declaration : Node -> Document
with_declaration = |root|
    { root, declaration: Declaration { version: "1.0", encoding: "UTF-8" } }

## Render a document to string
render : Document -> Str
render = |doc|
    when doc.declaration is
        NoDeclaration -> Node.render(doc.root)
        Declaration { encoding, version } ->
            escaped_version = escape_attr(version)
            escaped_encoding = escape_attr(encoding)
            "<?xml version=\"${escaped_version}\" encoding=\"${escaped_encoding}\"?>\n${Node.render(doc.root)}"

## Escape attribute values (quotes and ampersands)
escape_attr : Str -> Str
escape_attr = |s|
    s
    |> Str.replace_each("&", "&amp;")
    |> Str.replace_each("\"", "&quot;")

# Document without declaration
expect
    doc = {
        root: Node.element("root", [], [Node.text("Hello")]),
        declaration: NoDeclaration,
    }
    result = render(doc)
    result == "<root>Hello</root>"

# Document with declaration
expect
    doc = {
        root: Node.element("root", [], [Node.text("Hello")]),
        declaration: Declaration { version: "1.0", encoding: "UTF-8" },
    }
    result = render(doc)
    result == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>Hello</root>"

# Document with custom encoding
expect
    doc = {
        root: Node.element("root", [], []),
        declaration: Declaration { version: "1.1", encoding: "ISO-8859-1" },
    }
    result = render(doc)
    result == "<?xml version=\"1.1\" encoding=\"ISO-8859-1\"?>\n<root></root>"

# with_declaration helper
expect
    doc = with_declaration(Node.element("root", [], [Node.text("Hello")]))
    result = render(doc)
    result == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>Hello</root>"

# Document with nested structure
expect
    doc = with_declaration(
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
    result = render(doc)
    result == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<catalog><book id=\"1\"><title>Roc Programming</title><price>29.99</price></book></catalog>"

# Declaration with special characters is escaped
expect
    doc = {
        root: Node.element("root", [], []),
        declaration: Declaration { version: "1.0\"", encoding: "UTF-8&" },
    }
    result = render(doc)
    result == "<?xml version=\"1.0&quot;\" encoding=\"UTF-8&amp;\"?>\n<root></root>"
