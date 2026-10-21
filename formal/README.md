# Lean formalization

This directory contains the kernel-checked algebra and compact certificate
checks that accompany the GAP/C++ computations. It is deliberately not a
second search engine.

Evidence policy:

- project sources contain no `sorry`, `admit`, or project-defined `axiom`;
- headline certificate theorems use kernel reduction (`by decide` or
  definitional `rfl`), not `native_decide`;
- Lean and mathlib are pinned by `lean-toolchain` and `lake-manifest.json`;
- each certificate states what it checks and what remains outside its trusted
  boundary; and
- the geometric branch-cycle/descent theorem remains a cited external theorem
  unless and until its geometry is separately formalized.

Build from this directory with:

```sh
lake build
```

or from the repository root with:

```sh
make check-lean
```
