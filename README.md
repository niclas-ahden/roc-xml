# roc-xml

Simple XML generation library for Roc.

View the API documentation at [https://niclas-ahden.github.io/roc-xml/](https://niclas-ahden.github.io/roc-xml/).

## Quick start

```roc
app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
    xml: "https://github.com/niclas-ahden/roc-xml/releases/download/0.1.0/92TXyuk6rCZ_LjDEMp0DSwLhus595LAnsUR6R2sYALI.tar.br",
}

import pf.Stdout
import xml.Node
import xml.Document

main! = |_args|
    doc =
        Node.element("root", [Node.attribute("version", "1.0")], [
            Node.element("item", [], [Node.text("Hello")]),
            Node.element("item", [], [Node.text("World")]),
        ])
        |> Document.with_declaration

    Stdout.line!(Document.render(doc))
```

Output:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<root version="1.0"><item>Hello</item><item>World</item></root>
```

## Status

`roc-xml` is using the (old) Rust version of the Roc compiler. It'll be rewritten to use the Zig version in the future.

## Documentation

View the API documentation at [https://niclas-ahden.github.io/roc-xml/](https://niclas-ahden.github.io/roc-xml/).

### Generating documentation locally

```bash
./docs.sh 0.1.0
```

This will generate HTML documentation and place it in `www/0.1.0/`.
