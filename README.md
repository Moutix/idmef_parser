# 🔍 IDMEF / IODEF viewer
![ruby](https://img.shields.io/static/v1?label=ruby&message=v2.6&color=red&style=flat-square&logo=ruby)
![gems](https://img.shields.io/static/v1?label=gems&message=v3.0.3&color=red&style=flat-square&logo=rubygems)

> A script to parse IDMEF / IODEF RFC and generate graphs for a better view and understanding of thoses concepts

## Prerequisites

- Ruby (tested with version 2.6)
- RubyGems (tested with version 3.0.3)
    - haml (tested with version 5.1.2)
    - ruby-graphviz (tested with version 1.2.5)
    - prawn (tested with version 2.3.0)

## Usage

```sh
ruby idmef.rb  # To parse the IDMEF RFC (rfc4765.txt)
ruby iodef.rb  # To parse the IODEF RFC (rfc5070.txt)

ruby graph_generator.rb  # To generate classes diagram from already parsed IDMEF / IODEF RFC

ruby gen_html.rb  # Build a website to navigate through the classes
```

## Author

👤 **Sélim Menouar**
* GitHub: [@ningirsu](https://github.com/ningirsu)

## 🤝 Contributing

Contributions, issues and feature requests are welcome!

## Show your support

Give a ⭐️ if this project helped you!
