# Hazelnut: research context and source map

This is the research companion to [the Hazelnut tutorial](hazelnut-tutorial.md).
It records the context gathered, summarizes the relevant contributions, and
explains the tutorial's teaching order.

## 1. Scope and method

The root is Omar, Voysey, Hilton, Aldrich, and Hammer's **Hazelnut: A
Bidirectionally Typed Structure Editor Calculus**, published at POPL 2017. The
requested [arXiv URL](https://arxiv.org/abs/1607.04180) currently identifies the
extended version **v5, February 4, 2019**; the first preprint appeared in 2016.
Section, figure, and theorem numbers below refer to v5.

Citation depth means **backward reference edges**:

```text
depth 0: Hazelnut
depth 1: a work in Hazelnut's bibliography
depth 2: a work cited by that depth-1 work
```

The bibliography contains 68 entries. All are inventoried by role below. The
depth-2 expansion is **curated for the tutorial**, following the branches that
explain its technical choices. It is not an exhaustive expansion of all 68
bibliographies. A citation path establishes a bibliographic connection, not
necessarily a claim that Hazelnut directly adopted the grandchild's design.

Evidence labels distinguish:

- **Text:** relevant portions of the work and, where needed, its bibliography
  were inspected. This does not mean every proof was independently checked.
- **Abstract/author page:** an abstract or author-maintained description was
  inspected.
- **Via parent:** the account comes from the citing work; the original work's
  technical text was not inspected. Metadata was checked where available.

Research gathered October 11, 2026. Links are to the consulted text, author
pages, or identified publication records. Some author-hosted PDFs are preprints;
their cover dates can differ from the publication year.

## 2. Summary of the root paper

**Problem.** Ordinary language definitions usually describe completed programs.
During editing, programs are frequently incomplete or temporarily inconsistent,
which makes language-aware services harder to specify.

**Representation.** Hazelnut adds empty expression holes, non-empty expression
holes, and type holes to a small simply typed lambda calculus. An editor state
adds exactly one structural cursor.

**Static semantics.** Bidirectional typing separates synthesizing a type from
checking against an expected type. Type consistency and type matching make
these judgments work with incomplete types.

**Interaction semantics.** Move, construct, delete, and finish are formal
transitions between editor states. Selected construction rules insert a
non-empty hole when a newly constructed expression conflicts with its expected
type. The interior remains independently typeable.

**Central guarantee.** Action sensibility says that a well-typed state remains
well-typed after a defined action. In checking mode the expected type stays
fixed; in synthesis mode the resulting type may change.

**Additional guarantees.** Movement preserves the cursor-erased expression;
all cursor positions are reachable; every well-typed expression is
constructible from an empty hole in the appropriate mode. Expression-action
determinism requires subsumption-minimal derivations.

**Demonstrations.** A sum-type extension exercises the metatheory. An OCaml
implementation uses React and js_of_ocaml. An Agda development mechanizes the
semantics and metatheory.

**Boundary.** Evaluation of expressions with holes is a design space discussed
in the paper, rather than a completed operational semantics for incomplete
execution. Likewise, the metatheory does not establish usability or productivity
benefits.

## 3. Inventory of Hazelnut's immediate references

Numbers are the original bibliography positions, corresponding to `bib.bibN`
anchors in [the HTML bibliography](https://arxiv.org/html/1607.04180v5#bib).
These groups describe the references' roles in Hazelnut; they are not claims
that every listed work was read separately.

| Role | References | Context supplied |
| --- | --- | --- |
| Evidence about programming difficulties | 2 Altadmri & Brown; 24 Holzmann; 26 Jones; 34 Marceau et al.; 53 Sarkar; 56 Stefik & Siebert; 67 Yoon & Myers | Motivation for better treatment of intermediate states, syntax, and comprehension. |
| Structure editors and editor frameworks | 5 Borras et al. (CENTAUR); 8 Chiusano (Unison); 12 Conway et al. (Alice); 20 Garlan & Miller (GNOME); 28 Ko & Myers (Barista); 31 Lerner et al. (Polymorphic Blocks); 33 Lotem & Chuchem (Lamdu); 50 Reps & Teitelbaum; 51 Resnick et al. (Scratch); 58 Sufrin & De Moor; 59 Teitelbaum & Reps; 60 Tillmann et al. (TouchDevelop); 62 Voelter; 63–65 Voelter et al. | Prior structural interaction models, language-specific environments, and interface design. Descriptions of evolving tools are historical, as reported in Hazelnut. |
| Text-oriented recovery and completion | 3 Amorim et al.; 15 de Jonge et al.; 27 Kats et al. | Placeholders and parser recovery address incomplete syntax from a textual starting point. |
| Typing foundations | 9 Chlipala et al.; 10 Christiansen; 13 Damas & Milner; 14 Davies & Pfenning; 16 Dunfield & Krishnaswami; 22 Harper; 42 Odersky et al.; 47 Pierce & Turner | The small underlying calculus, bidirectional information flow, and alternatives based on type reconstruction. |
| Gradual typing | 11 Cimini & Siek; 18 Garcia & Cimini; 19 Garcia, Clark & Tanter; 49 Rastogi et al.; 54 Siek & Taha | Unknown type information, consistency, matching, inference, and systematic language construction. |
| Holes, proof refinement, synthesis, and contexts | 1 GHC typed holes; 6 Brady (Idris); 21 Gordon et al. (LCF); 30 Lee & Friedman; 35 McBride; 40 Nanevski et al.; 41 Norell (Agda); 45 Osera & Zdancewic; 46 Pientka (Beluga); 52 Sands; 68 Ziliani et al. (Mtac) | Ways to understand or fill missing expressions; logical context and possible future evaluation behavior. |
| Representation and formal foundations | 23 Harper & Stone; 25 Huet; 29 Lee et al.; 32 Licata & Harper; 37 Milner et al.; 48 Pouillard; 55 Simmons & Pfenning; 61 Urban et al. | Zippers, mechanization, binding conventions, language definitions, and proof-theoretic organization. |
| Editor services and specialized notation | 36 Mens & Tourwé; 39 Mooty et al.; 43–44 Omar et al. | Refactoring, completion, library-specific interaction, and type-specific languages. |
| Implementation and interaction models | 4 Balat; 7 Burckhardt et al.; 17 Elliott; 57 Sufrin; 66 Wan & Hudak | Web implementation, reactive interaction, value editing, live feedback, and formal editor commands. |
| Broader perspective | 38 Minsky | Historical motivation for program representations beyond strings. |

## 4. Verified depth-2 paths

Each row is an actual citation path. The middle work appears in Hazelnut's
bibliography; the last work appears in the middle work's references. Works
that are also immediate references, such as Damas & Milner, can occur at both
path lengths. Depth is a property of a path, not an exclusive label on a work.

| Path from Hazelnut | Edge evidence in the parent | Why bring the grandchild into the tutorial? |
| --- | --- | --- |
| HZ → SG84 → KN68 | SG84, references, p. 48 | Attribute grammars already formalized information flowing through syntax trees; Hazelnut adds an invariant about editable states. |
| HZ → HU97 → PA91 | HU97, introduction and final reference list | Persistent tree updates motivate representing a movable focus and its surrounding path. |
| HZ → HU97 → ME84 | HU97, §1.1 and final reference list | Zippers arose in a setting already concerned with structured editing and proof tools. |
| HZ → CH13 → LP10 | CH13, §3 and references, pp. 10–11 | A concrete implementation route from simply typed to dependently typed bidirectional checking. |
| HZ → DK13 → AN92 | DK13, §2 and references | Proof-search organization explains why typing modes and disciplined rule application matter. |
| HZ → ST06 → DY91 | ST06, introduction and reference [1] | Distinguishes missing static type information from an explicit dynamically tagged value facility. |
| HZ → ST06 → DM82 | ST06, reference [9] | Makes the contrast with unification-based type reconstruction explicit. DM82 is also HZ reference 13. |
| HZ → AGT16 → CC77 | AGT16, introduction and references | Supplies a mathematical interpretation of partial information rather than treating consistency as an arbitrary exception. |
| HZ → CM08 → PD01 | CM08, introduction and references | Explains the progression from modal validity to validity relative to a named collection of assumptions. |
| HZ → CM08 → ES90 | CM08, introduction, §4.3, and references | Explains why an unknown expression may need an explicit substitution recording what happened to its variables. |

The terminal works' own bibliographies are outside this traversal.

## 5. Annotated source cards

### HZ

**Cyrus Omar, Ian Voysey, Michael Hilton, Jonathan Aldrich, and Matthew A.
Hammer. _Hazelnut: A Bidirectionally Typed Structure Editor Calculus_. POPL,
2017.** [Extended text](https://arxiv.org/html/1607.04180v5),
[PDF](https://arxiv.org/pdf/1607.04180v5),
[author resource page](https://www.cs.cmu.edu/~comar/hazelnut-popl17/).

- **Depth:** 0. **Evidence:** text, including examples, static rules, action
  rules, theorem statements, extension, discussion, and bibliography.
- **Contribution:** a calculus of typed editing, with non-empty holes preserving
  meaningful states during flexible construction.
- **Use:** the tutorial's definitions, worked edit trace, and theorem claims.

### CPS81

**Tim Teitelbaum and Thomas Reps. _The Cornell Program Synthesizer: A
Syntax-directed Programming Environment_. CACM 24(9), 1981, pp. 563–573.**
[Author-hosted abstract](https://www.cs.wisc.edu/wpis/abstracts/cacm81.abs.html).

- **Depth:** 1; HZ reference 59. **Evidence:** abstract/author page and HZ §6.1.
- **Contribution:** unifies structural editing, execution, and debugging around
  a language grammar.
- **Use:** establishes that editing program structure has a long history.

### SG84

**Thomas Reps and Tim Teitelbaum. _The Synthesizer Generator_. Practical
Software Development Environments, 1984, pp. 42–48.**
[Text](https://www.cs.wisc.edu/wpis/papers/psde84.pdf).

- **Depth:** 1; HZ reference 50. **Evidence:** text, introduction and references.
- **Contribution:** generates language-based editors from descriptions including
  attribute grammars; incrementally updates semantic information and reports
  violations of relationships.
- **Use:** prevents the mistaken history that previous structural editors only
  understood syntax. Maintaining attributed trees and maintaining Hazelnut's
  well-H-typed editor states are different guarantees.

### PT00

**Benjamin C. Pierce and David N. Turner. _Local Type Inference_. TOPLAS 22(1),
2000, pp. 1–44; conference version 1998.**
[Text](https://www.cis.upenn.edu/~bcpierce/papers/lti-toplas.pdf).

- **Depth:** 1; HZ reference 47. **Evidence:** text, abstract, introduction, and
  part of the bibliography.
- **Contribution:** partial inference using information at adjacent syntax-tree
  nodes, including downward propagation of expected information.
- **Use:** explains the local dialogue between an expression and its context.
  Hazelnut uses a much smaller type system than this paper.

### CH13

**David Raymond Christiansen. _Bidirectional Typing Rules: A Tutorial_. 2013.**
[Text](https://davidchristiansen.dk/tutorials/bidirectional.pdf).

- **Depth:** 1; HZ reference 10. **Evidence:** text, introductory construction,
  annotation example, further reading, and bibliography.
- **Contribution:** explains how checking and synthesis turn typing rules into
  an implementable, syntax-directed discipline.
- **Use:** the tutorial's introduction to judgments and the need for ascriptions.

### DK13

**Jana Dunfield and Neelakantan R. Krishnaswami. _Complete and Easy
Bidirectional Typechecking for Higher-Rank Polymorphism_. ICFP, 2013.**
[2013 text](https://arxiv.org/html/1306.6032v1).

- **Depth:** 1; HZ reference 16. **Evidence:** text, introduction, declarative
  typing discussion, and references.
- **Contribution:** a proof-theoretic declarative system with a sound and
  complete algorithm for predicative higher-rank polymorphism.
- **Use:** explains why bidirectional typing is a foundation that can scale;
  higher-rank polymorphism is not part of the original Hazelnut core.

### DM82

**Luis Damas and Robin Milner. _Principal Type-schemes for Functional
Programs_. POPL, 1982, pp. 207–212.**
[Publication record](https://doi.org/10.1145/582153.582176).

- **Depth:** 1 and 2 along the ST06 path. **Evidence:** via HZ §6.4 and ST06;
  publication metadata checked.
- **Contribution:** principal type schemes for an ML-style functional language.
- **Use:** contrasts global constraint-solving expectations with Hazelnut's
  explicitly local treatment of incomplete type information.

### HU97

**Gérard Huet. _The Zipper_. JFP 7(5), 1997, pp. 549–554.**
[Author-hosted text](https://pauillac.inria.fr/~huet/PUBLIC/zip.pdf).

- **Depth:** 1; HZ reference 25. **Evidence:** text, introduction, representation,
  navigation operations, and bibliography. The PDF has an old template header;
  1997 is the publication year used in HZ.
- **Contribution:** represents a focused subtree together with a path containing
  the surrounding structure, permitting local functional navigation and updates.
- **Use:** explains Z-expressions and cursor erasure. Structural locality alone
  does not imply constant-time typechecking.

### ST06

**Jeremy G. Siek and Walid Taha. _Gradual Typing for Functional Languages_.
Scheme and Functional Programming Workshop, 2006, pp. 81–92.**
[Text](https://jsiek.github.io/home/siek06gradual.pdf).

- **Depth:** 1; HZ reference 54. **Evidence:** text, introduction, unknown types,
  statement of the cast-based approach, and bibliography.
- **Contribution:** uses partially known types and consistency to combine static
  and dynamic checking under programmer control.
- **Use:** supplies the immediate context for Hazelnut's type-hole consistency.
  Sharing static machinery does not automatically give Hazelnut a runtime.

### AGT16

**Ronald Garcia, Alison M. Clark, and Éric Tanter. _Abstracting Gradual
Typing_. POPL, 2016.** [Text](https://www.cs.ubc.ca/~rxg/agt.pdf).

- **Depth:** 1; HZ reference 19. **Evidence:** text, introduction, §4 definitions
  of concretization, precision, predicate lifting, and function lifting, plus
  references.
- **Contribution:** interprets gradual types as sets of static types and derives
  gradual judgments using abstraction.
- **Use:** explains consistency as overlap of possible complete types. The
  tutorial specializes that explanation to Hazelnut's `num` and arrow types.

### CM08

**Aleksandar Nanevski, Frank Pfenning, and Brigitte Pientka. _Contextual Modal
Type Theory_. TOCL 9(3), 2008.**
[Author-hosted preprint](https://www.cs.cmu.edu/~fp/papers/tocl07.pdf).

- **Depth:** 1; HZ reference 40. **Evidence:** text, introduction, §4.3 on
  substitutions, and bibliography. The consulted preprint is dated 2007.
- **Contribution:** internalizes context-relative reasoning; gives a uniform
  account of contextual metavariables and explicit substitutions.
- **Use:** motivates holes as obligations with both a type and a local context,
  and the prospective use of hole closures during evaluation.

### WH00

**Zhanyong Wan and Paul Hudak. _Functional Reactive Programming from First
Principles_. PLDI, 2000.**
[HZ's use of this reference](https://arxiv.org/html/1607.04180v5#S5.SS1).

- **Depth:** 1; HZ reference 66. **Evidence:** via HZ §5.
- **Contribution in context:** the reactive-programming background for an
  interaction loop of actions, model states, and rendered views.
- **Use:** situates HZ's implementation. This branch was not expanded to depth 2.

### OZ15

**Peter-Michael Osera and Steve Zdancewic. _Type-and-example-directed Program
Synthesis_. PLDI, 2015.**
[HZ's synthesis discussion](https://arxiv.org/html/1607.04180v5#S6.SS6).

- **Depth:** 1; HZ reference 45. **Evidence:** via HZ §6.6 and its bibliography.
- **Contribution in context:** combining types and examples to guide synthesis.
- **Use:** shows why a well-defined typed hole is a useful interface for a
  synthesis service. Hazelnut itself does not supply such a synthesizer.

### KN68

**Donald E. Knuth. _Semantics of Context-free Languages_. Mathematical
Systems Theory 2, 1968, pp. 127–145; correction 1971.**
[Publication record](https://doi.org/10.1007/BF01692511).

- **Depth:** 2 via SG84. **Evidence:** via SG84; metadata checked.
- **Contribution in context:** attribute grammars describe semantic information
  associated with syntax-tree nodes.
- **Use:** gives historical context to inherited information, synthesized
  information, and incremental semantic analysis. Bidirectional typing is not
  identified with attribute grammars.

### PA91

**Lawrence C. Paulson. _ML for the Working Programmer_. Cambridge University
Press, first edition, 1991.**
[First-edition author page](https://www.cl.cam.ac.uk/~lp15/MLbook/first/).

- **Depth:** 2 via HU97. **Evidence:** author page and HU97's introduction.
- **Contribution in context:** functional programming techniques, including the
  functional-array approach Huet uses as a comparison for persistent updates.
- **Use:** explains why keeping a focus can avoid repeatedly navigating from
  the root for nearby tree edits.

### ME84

**Véronique Donzeau-Gouge, Gérard Huet, Gilles Kahn, and Bernard Lang.
_Programming Environments Based on Structured Editors: The MENTOR
Experience_. In _Interactive Programming Environments_, 1984, pp. 128–140.**
[Citation and discussion in HU97](https://pauillac.inria.fr/~huet/PUBLIC/zip.pdf).

- **Depth:** 2 via HU97. **Evidence:** via HU97 §1.1 and bibliography.
- **Use:** historical context for structured editing; no independent claims
  about MENTOR's complete typing or interaction semantics are needed here.

### LP10

**Andres Löh, Conor McBride, and Wouter Swierstra. _A Tutorial Implementation
of a Dependently Typed Lambda Calculus_. Fundamenta Informaticae 102(2),
2010, pp. 177–207.** [Author page and code](https://www.andres-loeh.de/LambdaPi/).

- **Depth:** 2 via CH13. **Evidence:** author abstract, plus CH13's further
  reading and bibliography.
- **Contribution:** an executable Haskell presentation progressing from simple
  to dependent types.
- **Use:** further practice implementing the typing machinery after learning
  Hazelnut's smaller core.

### AN92

**Jean-Marc Andreoli. _Logic Programming with Focusing Proofs in Linear
Logic_. Journal of Logic and Computation 2(3), 1992, pp. 297–347.**
[Publication record](https://doi.org/10.1093/logcom/2.3.297).

- **Depth:** 2 via DK13. **Evidence:** via DK13 §2; metadata checked.
- **Contribution in context:** focusing organizes proof search into disciplined
  phases rather than arbitrary interleavings of rules.
- **Use:** background for proof-theoretic organization. HZ's discussion of
  action subsumption cites Simmons & Pfenning directly; it does not prove a
  correspondence between cursor motion and Andreoli focusing.

### DY91

**Martín Abadi, Luca Cardelli, Benjamin Pierce, and Gordon Plotkin.
_Dynamic Typing in a Statically Typed Language_. TOPLAS 13(2), 1991,
pp. 237–268.** [Publication record](https://doi.org/10.1145/103135.103138).

- **Depth:** 2 via ST06. **Evidence:** via ST06's introduction; metadata checked.
- **Contribution in context:** explicit support for dynamic values and typecase
  within a statically typed language.
- **Use:** helps separate unknown static information, runtime type inspection,
  and entirely missing expressions.

### CC77

**Patrick Cousot and Radhia Cousot. _Abstract Interpretation: A Unified
Lattice Model for Static Analysis of Programs by Construction or Approximation
of Fixpoints_. POPL, 1977, pp. 238–252.**
[Author-hosted summary and paper](https://www.di.ens.fr/~cousot/COUSOTpapers/POPL77.shtml).

- **Depth:** 2 via AGT16. **Evidence:** author summary and AGT16's use of the
  abstraction/concretization framework.
- **Contribution:** a framework relating concrete computation to sound abstract
  descriptions.
- **Use:** background for AGT's interpretation of imprecise types. The tutorial
  does not need the general theory of fixpoints to explain type consistency.

### PD01

**Frank Pfenning and Rowan Davies. _A Judgmental Reconstruction of Modal
Logic_. Mathematical Structures in Computer Science 11(4), 2001,
pp. 511–540.** [Author-hosted preprint](https://www.cs.cmu.edu/~fp/papers/mscs00.pdf).

- **Depth:** 2 via CM08. **Evidence:** text, abstract and introduction, plus
  CM08's explanation of the connection.
- **Contribution:** reconstructs constructive modalities by distinguishing
  judgments, propositions, and categorical validity.
- **Use:** explains the logical background that CMTT generalizes to arbitrary
  explicitly specified contexts.

### ES90

**Martín Abadi, Luca Cardelli, Pierre-Louis Curien, and Jean-Jacques Lévy.
_Explicit Substitutions_. POPL, 1990, pp. 31–46.**
[Publication record](https://doi.org/10.1145/96709.96712).

- **Depth:** 2 via CM08. **Evidence:** citation as given in CM08 and its
  explanation of explicit substitutions; original technical text not inspected.
- **Contribution in context:** represents substitution inside a calculus rather
  than leaving it entirely as a meta-level operation.
- **Use:** background for the tutorial's explicitly labeled illustration of
  retaining an environment while a hole is unresolved.

## 6. Pedagogical reordering

| Teaching step | Question answered | Paper location / source context |
| --- | --- | --- |
| 1. An intermediate-state problem | Why should an unfinished program have a meaning? | HZ §§1–2; CPS81, SG84 → KN68 |
| 2. A small language | What are the expressions and types we manipulate? | HZ §3.1 |
| 3. Two directions of typing | Where does the expected type come from? | HZ §3.1; PT00, CH13 → LP10 |
| 4. Partial type information | How can a typechecker reason without a complete type? | HZ §3.1; ST06, AGT16 → CC77 |
| 5. Non-empty holes | How can we retain a currently mismatched expression? | HZ §2.2 and rules 1f–1g |
| 6. Structural cursor | Where does an action happen? | HZ §3.2; HU97 → PA91, ME84 |
| 7. Worked editing trace | How do all these pieces cooperate? | HZ Figure 2 and §3.3 |
| 8. Editor guarantees | What has actually been proved? | HZ §§3.3–3.5; DK13 → AN92 as background |
| 9. Implementation and extension | How can I build on the calculus? | HZ §§4–5; WH00 |
| 10. Contextual holes and evaluation | What further machinery would incomplete execution need? | HZ §§6.5–6.7 and §7.1.2; CM08 → PD01, ES90; ST06 → DY91 |

The reordering deliberately introduces each formal object just before it is
needed. References explain a design decision at that point in the tutorial,
instead of appearing only in a final related-work catalogue.
