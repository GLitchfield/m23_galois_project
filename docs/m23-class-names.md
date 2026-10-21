# M23 conjugacy-class names

The canonical names in this project are the uppercase forms of the GAP
character-table names from `CharacterTable("M23")`: `1A` through the paired
classes `7A/7B`, `11A/11B`, `14A/14B`, `15A/15B`, and `23A/23B`. These agree
with the labels used by Häfner and the ATLAS character table.

The natural permutation representation returned by `MathieuGroup(23)` has the
same 17 classes, but GAP does not store a unique fusion from its computed table
to the library table. `PossibleClassFusions` returns 16 choices, independently
swapping four paired families. Order, class size, centralizer size, and natural
cycle structure do not distinguish the members of a pair.

Consequences:

- character-table calculations should use library-table positions and names;
- a raw natural-action representative should not be called `7A`, `11A`, etc.
  merely because it is the first computed class of that order;
- algorithms that require a specifically named non-rational class must either
  construct an ATLAS-standard representative or carry a verified fusion map;
- computations symmetric under swapping each paired family do not require that
  extra choice.

`data/reference/m23_classes.tsv` records the unambiguous invariants and inverse
pairing. The generation script deliberately checks that all natural classes
matching a library row have the same cycle shape rather than choosing an
unsupported fusion.

