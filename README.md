# roc-xml

Simple XML generation library for Roc.

## Quick start

```roc
app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0-rc1/3hT3SoHZ6qbEsa9qVFLUW3547U5LeoNd1KbpqLpz4r1i.tar.zst",
    xml: "https://github.com/niclas-ahden/roc-xml/releases/download/1.0.0/8Nm5dN5Z6YKawPkhPqbTUfGVbsQztG8bXTa7RTBKgMbz.tar.zst",
}

import pf.Stdout
import xml.Node
import xml.Document

main! = |_args| {
    doc = Document.with_declaration(
        Node.element(
            "root",
            [Node.attribute("version", "1.0")],
            [
                Node.element("item", [], [Node.text("Hello")]),
                Node.element("item", [], [Node.text("World")]),
            ],
        ),
    )

    Stdout.line!(Document.render(doc))?

    Ok({})
}
```

Output:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<root version="1.0"><item>Hello</item><item>World</item></root>
```

## Documentation

View the brief API documentation at [https://niclas-ahden.github.io/roc-xml/](https://niclas-ahden.github.io/roc-xml/).
