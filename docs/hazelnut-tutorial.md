# Hazelnut: giving unfinished programs a meaning

A tutorial based on **Cyrus Omar, Ian Voysey, Michael Hilton, Jonathan Aldrich,
and Matthew A. Hammer, _Hazelnut: A Bidirectionally Typed Structure Editor
Calculus_**, POPL 2017 ([extended paper](https://arxiv.org/html/1607.04180v5)).

**The central idea:** make incomplete programs legitimate objects in the
language, then define editing operations that preserve their static meaning.
When a programmer introduces an expression that does not yet fit its context,
retain it inside a **non-empty hole** so construction can continue.

This tutorial assumes familiarity with functions, syntax trees, and basic
static types. It introduces the typing notation as it goes. By the end, you
should be able to explain a Hazelnut edit sequence, implement its core typing
rules, and state precisely what its editor guarantees.

The [research companion](hazelnut-context.md) contains the context inventory,
source summaries, evidence notes, and explicit citation paths through depth 2:
**Hazelnut → its references → their references**. The expansion follows selected
technical and historical branches. Source labels such as **ST06** link to that
annotated bibliography. Paper section numbers refer to the arXiv v5 extended
version of the original work.

## Learning route

1. [See the editing problem](#1-the-problem-is-an-intermediate-state).
2. [Learn the small language](#2-a-small-language-with-three-kinds-of-missingness).
3. [Separate synthesis from checking](#3-types-flow-in-two-directions).
4. [Reason about incomplete types](#4-an-unknown-type-is-partial-information).
5. [Understand non-empty holes](#5-a-non-empty-hole-separates-two-typing-obligations).
6. [Represent the cursor](#6-the-cursor-is-a-position-in-a-tree).
7. [Work through an edit sequence](#7-build-a-program-without-working-outside-in).
8. [Understand the guarantees](#8-what-the-editor-proves).
9. [Implement and extend the design](#9-from-calculus-to-editor).
10. [Connect holes to logic and possible evaluation](#10-a-hole-has-a-type-and-a-context).

## 1. The problem is an intermediate state

Assume a function:

```text
incr : num → num
```

You want to build:

```text
incr(incr(3))
```

A natural construction order is to write the outer function, open its argument,
and then name the inner function before supplying its argument:

```text
incr
incr(…)
incr(incr)
incr(incr(3))
```

The intended final program is well-typed. The intermediate expression
`incr(incr)` is not: the outer function expects a number, but its current
argument is a function.

A structure editor can always keep the program syntactically well-formed by
representing missing branches as holes. But if it also insists on ordinary
well-typedness, it may force you to construct the inner application first:

```text
incr(□(□))
```

Only then can you put `incr` in the inner function position. That is a valid
construction order, but requiring it makes the type discipline dictate too
much of the programmer's workflow.

Hazelnut permits the function-first order by using a different intermediate
expression:

```text
incr(⦇incr⦈)
```

The brackets `⦇ … ⦈` are an actual syntax constructor: a **non-empty hole**.
They preserve the inner expression while deferring its agreement with the
surrounding expected type. You can continue building inside:

```text
incr(⦇incr(□)⦈)
incr(⦇incr(3)⦈)
incr(incr(3))
```

The last step removes the wrapper when the enclosed expression can fit.

> **First mental model:** a non-empty hole turns a temporary mismatch into a
> well-defined boundary inside the program.

### Where this idea sits historically

The Cornell Program Synthesizer already treated programs as hierarchical
structures and coordinated editing, execution, and debugging around that
representation ([CPS81](hazelnut-context.md#cps81)). The Synthesizer Generator
went further in another direction: language specifications and attribute
grammars supported generated editors with incremental semantic analysis
([SG84](hazelnut-context.md#sg84)).

Following the latter reference one level further reaches Knuth's work on
attribute grammars ([KN68](hazelnut-context.md#kn68)). This matters because
semantic information in editors predates Hazelnut. Hazelnut's distinctive
question is: **what formal language describes the editor's unfinished states,
and which actions preserve their well-typedness?**

**Paper connection:** §§1–2, especially the second example in Figure 2.

## 2. A small language with three kinds of missingness

Hazelnut begins with a simply typed lambda calculus containing numbers,
functions, application, addition, and explicit type annotations.

We will use slightly simplified notation:

| Notation | Meaning |
| --- | --- |
| `num` | The numeric type |
| `A → B` | Functions taking an `A` and returning a `B` |
| `λx. e` | A function with parameter `x` and body `e` |
| `f(a)` | Function application |
| `e : A` | An explicit type ascription |
| `?` | An empty **type** hole |
| `□` | An empty **expression** hole |
| `⦇e⦈` | A non-empty expression hole containing `e` |
| `⟨e⟩` or `⟨A⟩` | The expression or type selected by the cursor |

The paper uses the same empty-hole symbol for types and expressions; we use
`?` and `□` to make their different roles visible. Its cursor triangles are
rendered here as angle brackets. Capital letters such as `A` and `B` stand
for arbitrary types in our explanations; they are not polymorphic type
variables in the core language.

The cursor-free grammar is:

```text
Types        A ::= num | A → A | ?

Expressions  e ::= x
                 | λx. e
                 | e(e)
                 | n
                 | e + e
                 | e : A
                 | □
                 | ⦇e⦈
```

The paper calls these **H-types** and **H-expressions**: types and expressions
that may contain holes. A complete expression has no expression holes and no
type holes in its annotations.

Keep three questions distinct:

1. **Is code missing?** Represent it with `□`.
2. **Is type information missing?** Represent it with `?`.
3. **Is there code whose connection to its surroundings is unfinished?**
   Represent it with `⦇e⦈`.

For example, `(λx. x) : ? → ?` has a fully present lambda body but an
incomplete annotation. Conversely, `(λx. □) : num → num` has a complete
annotation but missing code.

**Paper connection:** §3.1, Figure 3.

## 3. Types flow in two directions

Before explaining holes formally, we need to know how type information moves
through an expression.

A **typing context**, written `Γ`, records the types of variables in scope:

```text
Γ = incr : num → num, x : num
```

The symbol `⊢` reads “under these assumptions.” Hazelnut uses two judgments:

```text
Γ ⊢ e ⇒ A      e synthesizes type A
Γ ⊢ e ⇐ A      e checks against expected type A
```

The paper calls checking **analysis**. The difference is which information is
an input:

- **Synthesis:** given `Γ` and `e`, determine `A`.
- **Checking:** given `Γ`, `e`, and `A`, determine whether `e` fits.

### 3.1 Start with expressions that tell us their types

A number synthesizes `num`. A variable synthesizes the type recorded in `Γ`:

```text
Γ ⊢ 3 ⇒ num

if x : A is in Γ, then Γ ⊢ x ⇒ A
```

For addition, the operator tells us what to expect from each child:

```text
Γ ⊢ e₁ ⇐ num       Γ ⊢ e₂ ⇐ num
--------------------------------
         Γ ⊢ e₁ + e₂ ⇒ num
```

Read an inference rule as: if the statements above the line hold, the statement
below the line follows.

For application with a known function type:

```text
Γ ⊢ f ⇒ A → B       Γ ⊢ a ⇐ A
-----------------------------
        Γ ⊢ f(a) ⇒ B
```

The function supplies the argument's expected type. This is already a small
dialogue between synthesis and checking.

### 3.2 A lambda benefits from an expected type

Consider `λx. x + 1`. Its syntax does not contain a parameter-type annotation.
If the expected type is `num → num`, however, checking is straightforward:

```text
Γ, x : num ⊢ x + 1 ⇐ num
-------------------------------
Γ ⊢ λx. x + 1 ⇐ num → num
```

More generally:

```text
Γ, x : A ⊢ e ⇐ B
---------------------
Γ ⊢ λx. e ⇐ A → B
```

Hazelnut's core has **no synthesis rule for a bare lambda**. At a position
where a type must be synthesized, an ascription provides the missing bridge:

```text
Γ ⊢ e ⇐ A
-----------------
Γ ⊢ (e : A) ⇒ A
```

Thus:

```text
(λx. x + 1) : num → num
```

can synthesize a type at the top level. The editor can help construct that
ascription; the programmer need not manually anticipate every annotation.

### 3.3 Why this is a good fit for an editor

At an unfinished function body, the editor can carry:

```text
available variables: x : num
expected type:       num
```

Those are useful facts for displaying information, checking a proposed edit,
or asking a synthesis service for a candidate expression.

Pierce and Turner's local type inference work provides the immediate
background for propagating information between nearby syntax nodes
([PT00](hazelnut-context.md#pt00)). Christiansen gives an accessible account of
the checking/synthesis distinction ([CH13](hazelnut-context.md#ch13)); his
references lead to an executable tutorial by Löh, McBride, and Swierstra
([LP10](hazelnut-context.md#lp10)).

The alternative tradition represented by Damas and Milner
([DM82](hazelnut-context.md#dm82)) reconstructs types using constraints and
unification. Hazelnut §6.4 observes that edits introducing new constraints can
have consequences far from the cursor. Its chosen discipline makes the
expected type and local assumptions explicit instead. This is a design choice
of this calculus, not a claim that every bidirectional type system avoids
unification.

**Paper connection:** §3.1, Figure 4; §§6.3–6.4.

## 4. An unknown type is partial information

An empty expression cannot tell us whether its eventual replacement will be a
number or a function. Hazelnut therefore gives it the type hole:

```text
Γ ⊢ □ ⇒ ?
```

Now suppose it appears as the argument of `incr`. We need to check something
whose synthesized type is `?` against the expected type `num`.

Ordinary equality is too strict. Hazelnut uses **type consistency**, written
`A ~ B`:

```text
? ~ A                         A ~ ?

A ~ A

A₁ ~ B₁       A₂ ~ B₂
-------------------------
(A₁ → A₂) ~ (B₁ → B₂)
```

Two types are consistent when their known structure does not conflict.

```text
num ~ ?                       yes
(num → ?) ~ (? → num)          yes
num ~ (num → num)              no
```

We can now state the rule connecting synthesis to checking:

```text
Γ ⊢ e ⇒ A       A ~ B
---------------------
     Γ ⊢ e ⇐ B
```

This is the static **subsumption** rule. In this system it compares types by
consistency, rather than by a subtype relation.

Since `?` is consistent with every type, `□` checks against every expected
type. That says the missing expression is an outstanding obligation, not that
we have constructed a value of every type.

### 4.1 Consistency is deliberately not transitive

We have:

```text
num ~ ?
? ~ (num → num)
```

But we must not conclude:

```text
num ~ (num → num)
```

Missing information can agree with either possibility without making the two
possibilities agree with each other.

Siek and Taha introduced this central machinery for gradual typing
([ST06](hazelnut-context.md#st06)). Hazelnut observes that it also describes
the static behavior needed for type holes.

### 4.2 A depth-2 explanation: sets of possible types

Garcia, Clark, and Tanter's _Abstracting Gradual Typing_
([AGT16](hazelnut-context.md#agt16)) explains partial types through a
**concretization** function, `γ`. Specialized to our language:

```text
γ(num)   = {num}
γ(?)     = the set of all complete types
γ(A → B) = {S → T | S ∈ γ(A), T ∈ γ(B)}
```

Then:

```text
A ~ B exactly when γ(A) and γ(B) overlap
```

For example, `num → ?` and `? → num` overlap at `num → num`.
But `{num}` and the possible completions of `num → num` do not overlap.

AGT's references lead to Cousot and Cousot's abstract interpretation framework
([CC77](hazelnut-context.md#cc77)). The useful lesson here is small: **an
incomplete description can have a precise meaning as information about possible
complete descriptions**. We do not need the general machinery of program
analysis to understand this instance.

Be careful about the scope of the explanation. Pairwise consistency does not
solve a whole-program constraint problem or promise a globally compatible
completion. Hazelnut's `?` is not a unification variable whose one eventual
solution is remembered and enforced everywhere it is used.

### 4.3 What if we do not know whether something is a function?

The application rule still needs a domain and codomain. Hazelnut introduces
**matched arrow types**. In functional notation:

```text
matchArrow(A → B) = (A, B)
matchArrow(?)     = (?, ?)
matchArrow(num)   = undefined
```

The general application rule becomes:

```text
Γ ⊢ f ⇒ T       matchArrow(T) = (A, B)       Γ ⊢ a ⇐ A
-----------------------------------------------------
                    Γ ⊢ f(a) ⇒ B
```

Likewise, to check a lambda against `T`, match `T` to `(A, B)`, then check the
body against `B` with `x : A` in scope.

Consequently, `□(3)` can synthesize `?`: the missing function has an unknown
domain and codomain. But `3(3)` cannot be typed, because `num` cannot be
matched as an arrow.

Matching decomposes currently available information. It does not secretly
rewrite a `?` annotation into a chosen complete function type.

**Paper connection:** §3.1, Figures 4–5; §6.2.

## 5. A non-empty hole separates two typing obligations

The rule for a non-empty hole is short:

```text
Γ ⊢ e ⇒ A
----------------
Γ ⊢ ⦇e⦈ ⇒ ?
```

There are two distinct views:

- **Inside:** `e` must synthesize some type. Its structure and bindings remain
  meaningful, so editing and type-aware services can operate there.
- **Outside:** the wrapper synthesizes `?`. The surrounding context can check
  it against its expected type while the connection remains unfinished.

For `Γ = incr : num → num`, derive the important case:

```text
Γ ⊢ incr ⇒ num → num
--------------------
Γ ⊢ ⦇incr⦈ ⇒ ?          ? ~ num
--------------------------------
       Γ ⊢ ⦇incr⦈ ⇐ num
```

Therefore `incr(⦇incr⦈)` is well-typed in Hazelnut even though
`incr(incr)` is not.

### 5.1 The wrapper does not make arbitrary contents legal

These two restrictions are essential:

1. If `y` is unbound, `⦇y⦈` is not a way to make it bound. Its interior still
   needs a typing derivation in `Γ`.
2. A bare lambda does not synthesize a type. To place it inside a non-empty
   hole in this core calculus, an ascription can make it synthesize, as in
   `⦇((λx. x) : num → num)⦈`.

Similarly, wrapping the entire ill-typed expression `3(3)` does not fix its
interior. A suitable internal boundary, such as `⦇3⦈(3)`, is a different
H-expression with its own typing derivation.

The hole is thus more disciplined than “ignore this subtree.” It preserves
the subtree's internal obligations while suspending its agreement with its
immediate surroundings.

### 5.2 A useful reading of the paper's novelty

Ordinary diagnostics can tell you that an expression does not fit. Hazelnut
makes that situation part of the formal syntax, with rules for continuing to
edit it. Its language of incomplete programs can represent both **absence**
and **unfinished connection**.

**Paper connection:** §2.2 and §3.1, rules 1f–1g.

## 6. The cursor is a position in a tree

So far we have described incomplete programs. An editor also needs a current
location.

Hazelnut puts exactly one cursor on an expression or a type:

```text
incr(⟨□⟩)

(λx. x) : (num → ⟨?⟩)
```

These cursor-bearing structures are **Z-expressions** and **Z-types**. The `Z`
refers to Huet's **zipper** ([HU97](hazelnut-context.md#hu97)).

A zipper represents:

```text
selected subtree + enough surrounding structure to reconstruct the whole tree
```

For a cursor on the right side of `x + □`, a frame can remember:

```text
focus: □
frame: the right child of an addition whose left child is x
```

Moving to the parent reconstructs that addition around the focus. Moving into
a child records the parent and its other children as surrounding structure.
Hazelnut's formal grammar expresses the same one-focus discipline by marking
exactly one recursive branch.

Huet's references supply two useful grandchildren: Paulson's account of
functional programming and persistent updates
([PA91](hazelnut-context.md#pa91)), and the MENTOR structured-editor experience
([ME84](hazelnut-context.md#me84)). Together they explain the practical setting
for the zipper: efficient manipulation of a persistent tree around a moving
point of attention.

### Cursor erasure

Write `erase(z)` for removing only the cursor markers:

```text
erase(incr(⟨□⟩)) = incr(□)
```

The holes remain. Cursor erasure lets us state an editor's typing invariant
using the ordinary H-expression typing judgments.

Keep a **zipper context** distinct from a **typing context**:

- The zipper records surrounding tree structure.
- `Γ` records variables and their types.

Traversing a zipper under a lambda updates `Γ`, but these are different pieces
of information.

**Paper connection:** §3.2, Figure 6.

## 7. Build a program without working outside-in

Hazelnut's primitive actions are:

| Action | Purpose |
| --- | --- |
| `move child n` / `move parent` | Change the selected tree position |
| `construct shape` | Introduce a variable, literal, lambda, application, type, or other constructor |
| `del` | Replace the selected expression or type with an empty hole |
| `finish` | Remove a selected non-empty-hole wrapper when its contents can be exposed |

Actions have a **bidirectional semantics**, just as expressions have
bidirectional typing. An edit where the expected type is known behaves
differently from one where the result must synthesize its own type.

### 7.1 The complete nested-increment trace

Assume throughout that `Γ` contains `incr : num → num`. This is Figure 2 of
the paper in our notation:

| Step | Action just performed | Resulting editor state |
| --- | --- | --- |
| 0 | Start | `⟨□⟩` |
| 1 | `construct var incr` | `⟨incr⟩` |
| 2 | `construct ap` | `incr(⟨□⟩)` |
| 3 | `construct var incr` | `incr(⦇⟨incr⟩⦈)` |
| 4 | `construct ap` | `incr(⦇incr(⟨□⟩)⦈)` |
| 5 | `construct lit 3` | `incr(⦇incr(⟨3⟩)⦈)` |
| 6 | `move parent` | `incr(⦇⟨incr(3)⟩⦈)` |
| 7 | `move parent` | `incr(⟨⦇incr(3)⦈⟩)` |
| 8 | `finish` | `incr(⟨incr(3)⟩)` |

Here is the information flow behind the interesting steps:

**Step 1:** At the top level, `incr` synthesizes `num → num`.

**Step 2:** Constructing an application wraps the selected function and creates
a missing argument. The argument is checked against `num`; the whole
application synthesizes `num`.

**Step 3:** The new variable synthesizes `num → num`, inconsistent with the
expected `num`. The analytic construction rule therefore inserts a non-empty
hole and places the cursor on the expression inside it.

**Step 4:** Inside the wrapper, `incr` can be edited in synthesis mode. Building
an application produces `incr(□)`, which synthesizes `num`. The wrapper itself
continues to synthesize `?`.

**Step 8:** The enclosed `incr(3)` checks against the outer argument's expected
type, `num`. Removing the wrapper is now permitted.

This is the payoff: the programmer can identify a function before constructing
the application around it, even when that function alone would not fit the
current expected type.

### 7.2 “Finish” does not mean “contains no holes”

At step 4, `incr(□)` already synthesizes `num`. You could move the cursor to
the enclosing non-empty hole and finish it immediately:

```text
incr(⟨⦇incr(□)⦈⟩)
          finish
incr(⟨incr(□)⟩)
```

The argument hole is still present. **Finishing discharges the obligation at
one boundary; it does not certify that the entire expression is complete.**

In synthesis mode, a well-typed non-empty hole can expose its interior's
synthesized type. In checking mode, that interior must check against the
expected type. Surrounding zipper rules must also remain satisfied.

### 7.3 A lambda at the top level

The first example in the paper demonstrates another helpful action:

```text
⟨□⟩
  construct lam x
(λx. □) : (⟨?⟩ → ?)
```

The inserted ascription lets the result synthesize a type. After filling the
annotation with `num → num` and moving to the body, you can build:

```text
□  →  x  →  x + □  →  x + 1
```

These arrows abbreviate construction steps with cursor movement omitted.
Every body checks against `num` under `x : num`.

**Paper connection:** Figures 1–2; §3.3, especially rules 13d, 13e, 13h,
and 16a–16b.

## 8. What the editor proves

The paper's main result is **action sensibility**. It is a preservation theorem
about editing.

### 8.1 Checking mode preserves an expected type

Suppose:

```text
Γ ⊢ erase(z) ⇐ A
```

If action `α` takes `z` to `z′` under the analytic action judgment at `A`, then:

```text
Γ ⊢ erase(z′) ⇐ A
```

The same external expectation is satisfied before and after the edit.

### 8.2 Synthesis mode permits the type to change

Suppose:

```text
Γ ⊢ erase(z) ⇒ A
```

If the synthetic action judgment takes `(z, A)` to `(z′, B)`, then:

```text
Γ ⊢ erase(z′) ⇒ B
```

There is no requirement that `A = B`. For example, a top-level empty hole
synthesizes `?`, and constructing `3` changes the synthesized type to `num`.

### 8.3 Why the proof can work

At the cursor, each action rule establishes the relevant typing fact.
For example, deleting an expression in checking mode leaves an empty hole,
which checks against the same expected type.

Away from the cursor, **zipper rules** carry the edit through surrounding
constructors. They mirror the typing rules. Under `λx. e` checked at `A → B`,
the body action is checked at `B` under `Γ, x : A`.

The proof proceeds by induction over action derivations: local correctness,
combined with correct propagation through the surrounding tree, establishes
correctness of the whole resulting state.

### 8.4 Actions are partial

Sensibility says: **if an action is defined, its result preserves the required
typing judgment**. It does not say every requested action is defined.

Moving to a nonexistent child is undefined. Finishing `⦇incr⦈` where `num` is
expected is undefined. Even a syntactically reasonable edit to an annotation
can be rejected if the annotated expression would no longer check.

Non-empty-hole insertion is specified by particular rules. It is not a general
promise that the editor automatically repairs every imaginable tree change.

### 8.5 The other theorems guard against different failures

| Property | What it establishes | Why an editor designer needs it |
| --- | --- | --- |
| Action sensibility, Theorem 1 | Defined edits preserve well-typedness in the appropriate mode. | Editing does not destroy the model's static meaning. |
| Movement erasure invariance, Theorem 2 | Moving the cursor does not change the cursor-erased expression or type. | Navigation cannot accidentally edit the program. |
| Reachability, Theorem 3 | Positions in the same underlying tree can be reached by movement. | No syntactic region is inaccessible. |
| Constructability, Theorem 6 | Every well-typed H-expression is constructible from an empty hole in the corresponding mode; H-types are constructible too. | The action vocabulary can express the language. |
| Type-action determinism, Theorem 7 | A type action has at most one result. | Type editing is predictable. |
| Expression-action determinism, Theorem 8 | Expression actions have unique results for subsumption-minimal derivations. | A disciplined rule-selection strategy gives predictable expression editing. |

Constructability includes unfinished expressions, even ones containing
superfluous non-empty holes. This is why the calculus includes an explicit
`construct nehole` action in addition to automatic wrapping.

### 8.6 The subtlety in determinism

An analytic action may have a specific checking-mode rule. It may also appear
possible to route the edit through synthesis using action subsumption. For
some constructors, those routes produce different annotations or structures.

The paper therefore restricts the determinism result to
**subsumption-minimal derivations**: use action subsumption as a last resort,
after more specific analytic rules.

Dunfield and Krishnaswami discuss the proof-theoretic organization of
bidirectional checking ([DK13](hazelnut-context.md#dk13)); following their
references reaches Andreoli's focusing work
([AN92](hazelnut-context.md#an92)). This is useful background for understanding
why rule-selection discipline matters. Hazelnut's cursor and proof-theoretic
focus are suggestively related, but the paper does not establish their
equivalence.

### 8.7 Read “well-typed” at the right level

These results concern the language **with holes**. They do not say a missing
piece has already been implemented, that any edit preserves program behavior,
or that an incomplete program has the runtime guarantees of a complete one.

For example, local consistency permits the annotation in:

```text
(λx. x(x)) : ? → ?
```

Both uses of `x` have type `?`; arrow matching and consistency allow the
application. Yet replacing only the type holes with finite simple types cannot
make self-application well-typed: the parameter would need a type `A` equal
to `A → B`. A statically meaningful incomplete state need not have a completion
obtained merely by filling its existing type holes.

**Paper connection:** §§3.3–3.5 and §6.4. The paper provides an
[Agda mechanization](https://www.cs.cmu.edu/~comar/hazelnut-popl17/).

## 9. From calculus to editor

The architecture has three useful layers:

```text
input event → abstract action → typed edit state → rendered view
```

The mathematical semantics governs the middle transition. A UI decides how
keystrokes, buttons, or other events produce actions and how states are shown.

### 9.1 Implement the statics first

The rules above suggest four small, mutually supporting operations:

```text
consistent(A, B)           → boolean
matchArrow(A)              → domain and codomain, or failure
synthesize(Γ, e)           → type, or failure
check(Γ, e, expectedType)   → success or failure
```

For `check`, handle a lambda using the expected type's matched arrow. For the
other core expression forms, synthesize a type and compare it with the
expectation using consistency. For `synthesize`, use the expression's
constructor; reject a bare lambda.

Two implementation details deserve care:

- Synthesizing `⦇e⦈` must first successfully synthesize `e`; returning `?`
  without checking the interior implements a different system.
- A consistency implementation must not add transitive closure or store `?`
  as a shared unification variable.

### 9.2 Add the cursor and actions

Define cursor-bearing forms that enforce one selected position. Implement
cursor erasure and movement before construction. Then implement the synthetic
and analytic action judgments, including their zipper cases and the
last-resort treatment of action subsumption.

An implementation-shaped sketch of the outer interaction loop is:

```text
on an action:
    attempt the action under the current typing mode and context
    if it has a result:
        adopt the resulting edit state and synthesized type, if any
    render the current state
```

This sketch is not an additional Hazelnut rule. It describes how a partial
action semantics can drive a UI.

The reference implementation, **HZ**, uses OCaml, the React library, and
js_of_ocaml. Here React means the **OCaml functional reactive programming
library**. The paper connects the stream of actions, states, and views to
functional reactive programming ([WH00](hazelnut-context.md#wh00)). The
[original resource page](https://www.cs.cmu.edu/~comar/hazelnut-popl17/)
links both HZ and the mechanization.

Although local structural updates are efficient, changes to a function's type
or an ascription may require rechecking other subexpressions. The paper
discusses caching and incrementality; the zipper alone is not a proof that all
typed edits take constant time.

### 9.3 Extend the language by extending its obligations

The paper's worked extension adds **binary sum types**:

```text
A + B
injL(e)
injR(e)
case(e, x.e₁, y.e₂)
```

A value of `A + B` comes from either the left type or the right type, and case
analysis handles both possibilities.

The existing design suggests the necessary pieces:

1. Add sum types, injections, and case expressions to the syntax.
2. Add a cursor position for each new type or expression child.
3. Extend consistency componentwise over sums.
4. Define sum matching: a sum reveals its components, `?` matches `? + ?`, and
   a known number or arrow does not match a sum.
5. Check an injection against its selected component type.
6. Check both case branches against the same expected result type, with their
   respective payload variables in scope.
7. Add construction and zipper rules, including annotations or non-empty holes
   where required.
8. Extend the proofs of sensibility, movement invariance, reachability,
   constructability, and the relevant determinism properties.

In this extension, injections and case expressions have checking rules.
Synthetic construction can insert an ascription. Do not silently infer a
common branch type and assume that is the paper's system.

The metatheory acts as a collection of design checks: a forgotten cursor case
can undermine reachability; a missing constructor can undermine
constructability; a bad typing premise can undermine sensibility.

**Paper connection:** §§4–5.

## 10. A hole has a type and a context

Return to:

```text
(λx. □) : num → num
```

The hole's obligation is more informative than “produce a number.” It is:

```text
with x : num available, produce an expression checking against num
```

For example, `x + 1` is a possible replacement. A free variable absent from
the local context is not.

This is the connection to **contextual modal type theory**, or CMTT
([CM08](hazelnut-context.md#cm08)). A contextual metavariable represents an
unknown term together with its type and the assumptions it is allowed to use.

### 10.1 The logical background, one generation further

CMTT cites Pfenning and Davies' reconstruction of modal logic
([PD01](hazelnut-context.md#pd01)). Roughly, that work gives a disciplined
account of validity independent of ordinary local truth assumptions. CMTT
generalizes the treatment to explicitly specified contexts.

Under the propositions-as-types viewpoint, an unfinished term is analogous to
a proof with outstanding obligations. The context records which assumptions
are available to discharge each obligation. Permitting holes does not provide
a completed proof of every proposition; it records the missing work.

Hazelnut discusses this interpretation but does not include an explicit
global modal context in its core judgments. The surrounding typing and zipper
structure supplies the local context as an action descends to a hole.

### 10.2 Why evaluation would need more machinery

Imagine wanting to evaluate:

```text
((λx. □) : num → num)(3)
```

Later, you plan to replace the hole with `x + 1`. If evaluation simply
discarded the binding of `x`, the eventual replacement would have lost the
information that `x` was `3`.

One possible representation keeps a **hole closure**:

```text
hole identity: u
original local context: x : num
accumulated substitution: x ↦ 3
```

If `u` is later filled with `x + 1`, applying the stored substitution yields
`3 + 1`.

This is an illustration of the future evaluation strategy discussed in
Hazelnut §6.7, **not an evaluation rule proved for the original calculus**.
The hole identity `u` and stored substitution belong to that prospective
representation; the core expression-hole syntax has no such names.

CMTT's references lead to _Explicit Substitutions_
([ES90](hazelnut-context.md#es90)). The relevant idea is to represent a
substitution as something the calculus can retain and manipulate, rather than
requiring every substitution to disappear immediately into a known term.

### 10.3 Three notions that are easy to conflate

| Notion | What is unknown or delayed? | Role here |
| --- | --- | --- |
| A gradual unknown type | Static information about the type of existing code | Background for `?`, consistency, and matching |
| An explicit dynamic-value facility | A value's runtime type is packaged and inspected explicitly | Earlier approach discussed by ST06, with DY91 as a depth-2 reference |
| An expression hole | The implementation of some code, or its connection to a context | The primary object being edited in Hazelnut |

The second row refers to Abadi, Cardelli, Pierce, and Plotkin's work
([DY91](hazelnut-context.md#dy91)). Reading it in this citation chain helps
explain why importing gradual consistency does not, by itself, decide what a
missing expression should do at runtime.

Hazelnut discusses several possibilities: prevent execution, raise an
exception when a hole is reached, synthesize code to fill it, or use a
contextual representation supporting some form of incomplete execution.
These are design choices beyond its core editing theorem.

### 10.4 A useful interface for synthesis

The same pair of facts—local assumptions and an expected type—can serve as
input to a program synthesizer. Hazelnut cites type-and-example-directed
synthesis ([OZ15](hazelnut-context.md#oz15)) as related work.

For a hole under `x : num` expected to produce `num`, types alone admit many
candidates: `x`, `0`, `x + 1`, and so on. Examples or other specifications help
choose among them. Hazelnut contributes a well-defined place to ask the
question, rather than an algorithm that always finds the intended answer.

**Paper connection:** §§6.5–6.7 and §7.1.2.

## 11. Check your understanding

### Exercise 1: consistency

Which pairs are consistent?

```text
a. num → ?          and ? → num
b. num              and ? → ?
c. ?                and num → num
```

**Answer:** (a) and (c). In (b), the known outer constructors conflict:
number versus function. Unknown components inside the function cannot erase
that conflict.

### Exercise 2: checking versus synthesis

Can `λx. x` synthesize a type? Can it check against `num → num`? How can it
appear at the top level?

**Answer:** A bare lambda does not synthesize in this core. It checks against
`num → num` because `x` checks against `num` under `x : num`. The ascribed
expression `((λx. x) : num → num)` synthesizes `num → num`.

### Exercise 3: the contents of a non-empty hole

Suppose `Γ` is empty. Does `⦇y⦈` synthesize `?`?

**Answer:** No. Its rule first requires `y` to synthesize a type under `Γ`,
but `y` is not bound. The wrapper only defers the boundary's type agreement.

### Exercise 4: finishing early

With `incr : num → num`, may the selected hole in
`incr(⟨⦇incr(□)⦈⟩)` be finished?

**Answer:** Yes. Its interior synthesizes `num`, consistent with the outer
argument's expected `num`. The result still contains an empty expression hole.

### Exercise 5: sensibility versus totality

Does action sensibility require an editor to accept an action that changes
the annotation on `3 : num` to `num → num` while retaining the expression `3`?

**Answer:** No. The annotation-editing zipper rule requires the expression to
check against the new annotation. It does not, so that transition is undefined.
Sensibility constrains the result of a defined action.

### Exercise 6: static meaning versus completion

Why does `(λx. x(x)) : ? → ?` challenge the claim “well-typed with holes means
there is a solution to all the missing types”?

**Answer:** Its local uses of unknown information are consistent, but no finite
simple parameter type can satisfy `A = A → B`. Type consistency does not carry
out global unification.

## 12. The paper in one page

Hazelnut's construction can be remembered as five layers:

```text
ordinary expressions and types
    + explicit holes
    + bidirectional typing, consistency, and matching
    + a structural cursor
    + typed edit actions
    = a calculus of statically meaningful editing
```

Its most important representational move is the **non-empty hole**. A
programmer can retain a useful expression even when it does not yet fit its
context, while both the surrounding program and the enclosed expression
remain statically meaningful.

Its most important theorem is **action sensibility**. The invariant belongs
to every reachable editor state, rather than only to a completed program
submitted to a compiler.

The reference context explains the ingredients:

- **Structure editors and attribute grammars:** why program structure is a
  useful editing model, and why semantic editor support already has a history.
- **Bidirectional typing:** how a context supplies expectations and an
  expression supplies information.
- **Gradual typing and abstract interpretation:** how unknown type information
  can have a precise, compositional meaning.
- **Zippers and persistent data structures:** how to identify and manipulate
  one structural position.
- **Contextual modal types and explicit substitutions:** how missing code can
  be understood relative to assumptions, and what future execution strategies
  might need to remember.

For a second reading of the original paper, use this order:

1. Figures 1–2: recognize the interactions.
2. Figures 3–5: reconstruct the syntax and typing rules.
3. §3.2: understand cursor-bearing syntax and erasure.
4. §3.3.1, then the action rules: keep sensibility in mind while reading.
5. §3.4: notice the condition on determinism.
6. §4: see how the proof obligations guide a language extension.
7. §§6–7: distinguish established results from proposed interpretations and
   future work.

The [source map](hazelnut-context.md#4-verified-depth-2-paths) makes the
two-generation reference paths explicit, and the
[annotated source cards](hazelnut-context.md#5-annotated-source-cards) provide
links and evidence notes for further reading.
