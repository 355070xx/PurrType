# McBopomofo Associated Phrases

This directory keeps the generated McBopomofo associated phrase table used as
an association seed source for PurrType.

Source:

- https://github.com/openvanilla/fcitx5-mcbopomofo
- `data/associated-phrases-v2.txt`
- fetched from `refs/heads/master` at commit
  `17252f34d6771e4fbf1790d18ab2d1f089e3a5c1`

License:

- MIT License, kept in `LICENSE.txt`

PurrType does not use this file as an input-code dictionary. The generation
script reads the associated phrase rows, discards Bopomofo readings and
punctuation rows, and keeps only Chinese phrase continuations for
`resources/association_generated.tsv`.
