module [
    Attribute,
    Node,
    element,
    text,
    num,
    bool,
    attribute,
    render,
    escape_xml,
]

## XML attribute
Attribute : { name : Str, value : Str }

## XML node
Node : [
    Element { tag : Str, attributes : List Attribute, children : List Node },
    Text Str,
]

## Create an XML element
element : Str, List Attribute, List Node -> Node
element = |tag, attributes, children|
    Element { tag, attributes, children }

## Create a text node
text : Str -> Node
text = |content|
    Text content

## Create a number node
num : Num * -> Node
num = |n|
    Text (Num.to_str(n))

## Create a boolean node
bool : Bool -> Node
bool = |b|
    Text (if b then "true" else "false")

## Create an attribute
attribute : Str, Str -> Attribute
attribute = |name, value|
    { name, value }

## Render a node to `Str`
render : Node -> Str
render = |node|
    when node is
        Text content -> escape_xml(content)
        Element { tag, attributes, children } ->
            opening = if List.is_empty(attributes) then
                "<${tag}>"
            else
                attrs_str =
                    attributes
                    |> List.map(|attr| "${attr.name}=\"${escape_xml(attr.value)}\"")
                    |> Str.join_with(" ")
                "<${tag} ${attrs_str}>"

            children_str =
                children
                |> List.map(render)
                |> Str.join_with("")

            closing = "</${tag}>"

            "${opening}${children_str}${closing}"

## Escape special XML characters
escape_xml : Str -> Str
escape_xml = |s|
    s
    |> Str.replace_each("&", "&amp;")
    |> Str.replace_each("<", "&lt;")
    |> Str.replace_each(">", "&gt;")
    |> Str.replace_each("\"", "&quot;")
    |> Str.replace_each("'", "&apos;")

# Escape special characters
expect
    input = "<tag>&\"'</tag>"
    result = escape_xml(input)
    result == "&lt;tag&gt;&amp;&quot;&apos;&lt;/tag&gt;"

# Simple element
expect
    node = element("root", [], [text("Hello")])
    result = render(node)
    result == "<root>Hello</root>"

# Element with attribute
expect
    node = element("root", [attribute("id", "1")], [text("Hello")])
    result = render(node)
    result == "<root id=\"1\">Hello</root>"

# Nested elements
expect
    node = element(
        "root",
        [],
        [
            element("child", [], [text("Hello")]),
            element("child", [], [text("World")]),
        ],
    )
    result = render(node)
    result == "<root><child>Hello</child><child>World</child></root>"

# Element with special characters in text
expect
    node = element("root", [], [text("Hello & goodbye")])
    result = render(node)
    result == "<root>Hello &amp; goodbye</root>"

# Element with special characters in attribute
expect
    node = element("root", [attribute("value", "a<b")], [])
    result = render(node)
    result == "<root value=\"a&lt;b\"></root>"

# Empty element (no children)
expect
    node = element("empty", [], [])
    result = render(node)
    result == "<empty></empty>"

# Empty text node
expect
    node = element("root", [], [text("")])
    result = render(node)
    result == "<root></root>"

# Multiple attributes
expect
    node = element("tag", [attribute("a", "1"), attribute("b", "2"), attribute("c", "3")], [])
    result = render(node)
    result == "<tag a=\"1\" b=\"2\" c=\"3\"></tag>"

# Deeply nested elements (3+ levels)
expect
    node = element(
        "level1",
        [],
        [
            element(
                "level2",
                [],
                [
                    element(
                        "level3",
                        [],
                        [
                            element("level4", [], [text("deep")]),
                        ],
                    ),
                ],
            ),
        ],
    )
    result = render(node)
    result == "<level1><level2><level3><level4>deep</level4></level3></level2></level1>"

# Mixed children (text and elements)
expect
    node = element(
        "p",
        [],
        [
            text("Hello "),
            element("strong", [], [text("world")]),
            text("!"),
        ],
    )
    result = render(node)
    result == "<p>Hello <strong>world</strong>!</p>"

# Unicode in text
expect
    node = element("root", [], [text("Héllo wörld 🎉")])
    result = render(node)
    result == "<root>Héllo wörld 🎉</root>"

# Unicode in attributes
expect
    node = element("root", [attribute("emoji", "🚀"), attribute("name", "Ñoño")], [])
    result = render(node)
    result == "<root emoji=\"🚀\" name=\"Ñoño\"></root>"

# Newlines in text
expect
    node = element("pre", [], [text("line1\nline2\nline3")])
    result = render(node)
    result == "<pre>line1\nline2\nline3</pre>"

# Whitespace in attributes
expect
    node = element("tag", [attribute("value", "  spaces  ")], [])
    result = render(node)
    result == "<tag value=\"  spaces  \"></tag>"

# Empty attribute value
expect
    node = element("input", [attribute("disabled", "")], [])
    result = render(node)
    result == "<input disabled=\"\"></input>"

# Integer node
expect
    node = element("count", [], [num(42)])
    result = render(node)
    result == "<count>42</count>"

# Negative integer node
expect
    node = element("temp", [], [num(-10)])
    result = render(node)
    result == "<temp>-10</temp>"

# Float node
expect
    node = element("price", [], [num(19.99)])
    result = render(node)
    result == "<price>19.99</price>"

# Boolean true
expect
    node = element("enabled", [], [bool(Bool.true)])
    result = render(node)
    result == "<enabled>true</enabled>"

# Boolean false
expect
    node = element("enabled", [], [bool(Bool.false)])
    result = render(node)
    result == "<enabled>false</enabled>"

# Mixed content with numbers and booleans
expect
    node = element(
        "data",
        [],
        [
            element("count", [], [num(5)]),
            element("active", [], [bool(Bool.true)]),
            element("name", [], [text("test")]),
        ],
    )
    result = render(node)
    result == "<data><count>5</count><active>true</active><name>test</name></data>"

# Standalone text node
expect
    node = text("hello")
    result = render(node)
    result == "hello"

# Standalone num node
expect
    node = num(42)
    result = render(node)
    result == "42"

# Standalone bool node
expect
    node = bool(Bool.true)
    result = render(node)
    result == "true"

# Empty string escape
expect
    result = escape_xml("")
    result == ""

# Zero
expect
    node = num(0)
    result = render(node)
    result == "0"

# Decimal number
expect
    node = num(123.456dec)
    result = render(node)
    result == "123.456"
