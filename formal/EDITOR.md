# Executable Hazelnut core and reactive definition navigation

`Formal/Hazelnut.lean` translates the **core H-type/H-expression static
semantics** of [Hazelnut, arXiv v5](https://arxiv.org/html/1607.04180v5), then
defines an executable, bounded expression-action editor. `Formal/Editor.lean`
adds a source projection, lexical go-to-definition, typed LSP contracts, and a
reactive event fold. `EditorMain.lean` executes the examples.

All dependencies are in Lean's `Std` distribution. Proofs use kernel-checked
terms, including ordinary `decide` for finite examples. There are no proof
placeholders, user-declared axioms, classical choice, or native-decide proofs.
A transitive dependency audit of all **1,826 declarations** in the two modules,
including private/generated helpers, found only `propext` and `Quot.sound`.

## Run

From `formal/`, using the repository's Lean toolchain:

```sh
lake build
lake env lean --run EditorMain.lean
```

These commands were verified with Lean **4.29.1**. The executable prints the
complete nested-increment edit trace, then two distinct targets for shadowed
`x` references, including one inside a non-empty hole. It demonstrates accepted
navigation, rejection of a well-formed but incorrect binder, stale-response
rejection after an edit, and acceptance after cursor-only movement. The file
also contains kernel-checked examples for UTF-16 astral characters, escaped
newlines, token boundaries, capabilities, fresh request ids, and ill-typed hole
contents. The shadowing example itself is built from an empty editor by 16
actions; its definition request therefore uses an actually edited snapshot.

## Exact core static-rule correspondence

Numbers refer to v5 §3.1, Figures 3–5.

| Paper | Lean definition |
| --- | --- |
| Figure 3 H-types: number, arrow, empty hole | `Ty.num`, `Ty.arr`, `Ty.hole` |
| Figure 3 H-expressions | All eight constructors of `Expr` |
| 1a, variable | `Synth.var`, first-match `lookup` |
| 1b, application and arrow matching | `Synth.app`, `matchArrow` |
| 1c, numeral | `Synth.lit` (numerals represented by `Nat`) |
| 1d, addition | `Synth.plus` |
| 1e, ascription | `Synth.asc` |
| 1f, empty expression hole | `Synth.hole` |
| 1g, non-empty hole | `Synth.nonempty`; its interior **must synthesize** |
| 2a, analytic lambda | `Check.lam` |
| 2b, consistency subsumption | `Check.sub`; consistency is symmetric |
| 3a–b, either side a type hole | `Consistent.holeL`, `Consistent.holeR` |
| 3c, reflexivity | `Consistent.refl`, derived structurally from the constructors |
| 3d, componentwise arrows | `Consistent.arr` |
| Figure 5, matched arrows | `matchArrow (arr a b) = some (a,b)`, `matchArrow hole = some (hole,hole)`, `matchArrow num = none` |

`typing` structurally computes both synthesis and analysis; `synth` and `check`
are its projections. `synth_iff` and `check_iff` prove **soundness and
completeness** against the mutually inductive judgments. `synthesis_unique`
derives uniqueness. A bare lambda has no synthesis rule. Consistency does not
unify type holes or take transitive closure.

**Reference discrepancy:** the checked upstream OCaml revision compares each
arrow's own two components, rather than corresponding components of the two
arrows. This Lean definition follows paper rule 3d: `consistent a c &&
consistent b d`. `EditorMain.lean` checks both arrow counterexamples recorded
in [TOOLS.md](TOOLS.md#hazelnut-ocaml): `(num → num)` versus
`((num → num) → (num → num))` is inconsistent, whereas
`(num → (num → num))` versus `(num → (? → num))` is consistent. The upstream
OCaml module is therefore not treated as an unconditional semantic oracle.
The separate upstream Agda check and its explicit assumptions are recorded
in [TOOLS.md](TOOLS.md#hazelnut-agda).

Names use `String`; environments are nearest-first lists. This is an explicit
shadowing representation of lexical binding, rather than the paper's
identification of syntax up to alpha-renaming. Alpha-equivalence, substitution,
and the weakening metatheory are outside this development.

## Actions and their precise boundary

`ZExpr` is a focus and a list of enclosing expression frames. `ZTy` similarly
represents a type focus. Every value has exactly one focus. Their `erase`
functions reconstruct the tree; `movement_erasure` and
`type_movement_erasure` prove that every successful movement leaves it intact.
`Child.first` and `Child.second` correspond to the paper's child 1 and child 2.

| Implemented action | Correspondence and differences |
| --- | --- |
| `move`, `moveTy` | Expression-to-expression cases of 8a, 8c, 8e–p; type movement 6a–d. Annotation-to-type cursor transitions 8b, 8d are absent. |
| `erase` | Expression deletion 15a–b; type deletion 14. |
| `var`, `lit` | 13c–d and 13j–k: introduce at an empty hole; insert a non-empty hole on analytic mismatch. |
| `lam` | 13f exactly at an analytic arrow/hole. Synthetic/mismatching construction has the erased shape of 13e/13g, but selects the **body**, rather than the annotation's domain. |
| `app` | 13h–i: wrap the current expression as a function, with a non-empty hole when it cannot match an arrow; select the new argument hole. |
| `plus` | 13l–m: retain the current expression as the left operand, wrapping a numeric mismatch; select the right hole. |
| `wrap` | Synthetic non-empty-hole construction 13n; requires synthesis. The analytic ascription-inserting variant is absent. |
| `finish` | 16a–b: expose the interior only if the entire result is well-typed in the root mode. |
| `editTy .num/.arrow` | 12b/12a: fill an empty type hole or construct an arrow around the selected domain, focusing its codomain. |
| `ascribe t`, `setType t` | Explicit editor conveniences for inserting/replacing a whole annotation. These are **not** literal translations of 13a–b or the full annotation-cursor rules. |

`localInfo` recovers the focus's lexical context and bidirectional mode from
the outer frames. It follows the information flow of 18a–h. `construct`
computes an actual replacement and cursor; `step` rechecks its reconstructed
expression to discharge the surrounding typing premises. A rejected action
returns `none`; `react` retains the prior state.

`action_sensibility` proves that every successful `step` is declaratively
well-typed. In analysis the root expected type stays fixed; in synthesis the
output may have a new type. `fold_checked` preserves this invariant over any
finite action list. This is a **checked implementation theorem**, not a claim
to have translated all action-derivation constructors or reproved the paper's
Theorem 1 by induction on those derivations.

The action layer is a bounded deterministic variant: separate type zippers
are available, but a type cursor is not embedded in `ZExpr`; annotation updates
are atomic. No action-relation equivalence, full constructability, cursor
reachability, subsumption-minimality theorem, or sum-type extension is claimed.
The complete Figure 2 trace is implemented, including its temporary mismatch
and subsequent finish. There is no evaluation semantics for incomplete terms.

## Source projection and lexical resolution

The source document is `render zipper.erase`. It is a canonical **single-line**
projection: identifiers are quoted; quotes, backslashes, LF, and CR are escaped.
Spans count UTF-16 code units, not UTF-8 bytes or Unicode scalar values. An
astral character such as `😀` contributes two units. All ranges are zero-based
and half-open; a position at a token's exclusive end does not hit it.

The byte-level implementation is deliberate: Lean 4.29's `String.toList`
internally depends on classical choice. `utf16Length` instead counts UTF-8
leading bytes (continuations contribute zero; four-byte leaders contribute two),
and `utf8Chars` structurally decodes valid String bytes for identifier escaping.
The span proofs use this executable definition and its append law; a separate
equivalence proof against Lean's choice-dependent String iterators is not claimed.

`references` traverses the actual syntax and records each variable occurrence,
its source span, and its enclosing lambda scope. Entering a lambda pushes a
binding constructed from that lambda's name, body, and source offset. Entering
a non-empty hole retains the scope. `lookupBinding` returns the **first**
matching binder. Empty holes, hole delimiters, literals, annotations, binder
declaration tokens, and unresolved free variables yield no definition.

The checked connection to syntax is explicit:

* `definition_sound`: an emitted link witnesses a variable in the syntax index,
  a hit on that variable's span, and the nearest-binder `Lexical` judgment.
* `lexical_unique` and `shadowing`: a matching inner binder cannot be skipped.
* `scope_sources` and `definition_target_in_syntax`: the target is a lambda
  actually present in the input tree, not an externally supplied valid range.
* `reference_bounds`, `binding_bounds`, `definition_spans`: origin, target, and
  target-selection spans lie within the UTF-16 length of the source projection.
* `binding_contains_selection` and `definition_valid`: the full lambda range
  contains the selected binder-name range; all ranges are ordered.

The URI is supplied by the single-document host; external bindings in a typing
context have no source declaration here. URI parsing, imported definitions,
multiline pretty-printing, text parsing, incremental indexing, and cross-file
navigation are outside the model.

## LSP contract and reactive lifecycle

The modeled contract is the established [LSP 3.17 definition request](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_definition),
including [Position](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#position)
and [LocationLink](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#locationLink).
This names the modeled specification version, rather than claiming it is the
latest LSP release.

* `DefinitionParams` contains `textDocument.uri` and `position`.
* The server advertises `definitionProvider` and selects mandatory/default
  `utf-16`. Requests are disabled when `definitionProvider` is false.
* `answer` emits `null`, a singleton `Location[]`, or a singleton
  `LocationLink[]`. Links require the client's `textDocument.definition.linkSupport`;
  the optional origin range is always provided. The location fallback selects
  the binder name.
* `answer_wire_valid` proves every emitted coordinate lies in LSP's
  `0..2^31-1` range. Projections too long for that representation return `null`.
* `Pending` captures the source expression, URI, version, position, capability,
  and fresh request id. **Snapshot/version are local bookkeeping**, not invented
  fields of LSP's definition request or reply. `serve` computes a reply from
  that snapshot. Logical natural-number ids can be encoded as JSON-RPC strings.
* `update` folds edit, request, and response events. A source-changing edit
  increments the version and clears old navigation. Cursor-only movement
  leaves the source version unchanged. At most one request is pending; a
  superseding request gets a new id.
* Response acceptance checks request id, URI, version, snapshot, and equality
  with the definition computed from the current syntax. Even a well-formed
  forged target is rejected. `stale_response_rejected` proves rejection after
  a version change.
* `view` exposes the current source and accepted binder selection to a UI.
  `reactive_invariant` preserves typing and current-snapshot navigation over
  **every finite event trace**. `navigation_sound`, `navigation_wire_valid`,
  and `view_selection_valid` connect the accepted result and displayed
  selection to that invariant.

This is an executable semantic editor model with typed protocol payloads and
asynchronous events. JSON encoding, JSON-RPC framing, initialization transport,
URI validation, progress, cancellation/error messages, document synchronization
notifications, and a graphical frontend are adapter work, not implemented
network services or additional proved properties.
