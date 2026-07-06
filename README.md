# roc-xml

Simple XML generation library for Roc.

## Quick start

```roc
app [main!] {
    pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
    xml: "package/main.roc",
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

    Stdout.line!(Document.render(doc))

    Ok({})
}
```

Output:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<root version="1.0"><item>Hello</item><item>World</item></root>
```

See [examples](examples/) for a runnable program.

## Documentation

View the brief API documentation at [https://niclas-ahden.github.io/roc-xml/](https://niclas-ahden.github.io/roc-xml/).
