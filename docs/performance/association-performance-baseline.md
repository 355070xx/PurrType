# PurrType Association Performance Baseline

Generated on 2026-05-17 HKT by running `make test`, which invokes `PurrTypeEngineStartupBenchmark`.

This baseline records a local runtime tree without building a package. The benchmark runs one engine instance in this sequence: cold init, Classic Sucheng, Cangjie, Pinyin, Classic association, New Sucheng phrase. Treat the numbers as regression reference points for this machine, not as cross-machine SLA values.

| Phase | Time | RSS |
| --- | ---: | ---: |
| Baseline process | n/a | 5.5 MB |
| Cold init | 91.52 ms | 21.9 MB |
| Classic Sucheng first lookup | 0.05 ms | 21.9 MB |
| Cangjie first lookup | 286.97 ms | 65.6 MB |
| Pinyin first lookup | 318.54 ms | 94.8 MB |
| Classic association first lookup | 1030.72 ms | 160.3 MB |
| New Sucheng phrase first lookup | 148.72 ms | 168.8 MB |

Loaded entry counts after all phases:

- Quick: 19567
- Cangjie: 148613
- Pinyin: 70994

Regression checks covered in the same run:

- Cold init loads Classic Sucheng but keeps Cangjie and Pinyin deferred.
- Classic Sucheng lookup does not load Cangjie or Pinyin.
- Cangjie lookup loads Cangjie while keeping Pinyin deferred.
- Classic association first lookup keeps `你 -> 好` first.
- New Sucheng phrase first lookup resolves the seeded `hionaomjoo` phrase path.
