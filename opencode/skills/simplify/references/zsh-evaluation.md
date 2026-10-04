# Evaluation of the Zsh condensation

The revision improved conceptual organization and made the book easier to scan.
Its presentation improved less consistently. Some explanations became too
compressed, and the new conceptual order introduced prerequisites before
explaining them. Four organizing questions are useful; they are not proof that
Zsh requires only four concepts.

## Comparison and evidence

This evaluation compares the original PR #22 book outline and first chapter at
[`99939a2`](https://github.com/seanjennings960/dotfiles/commit/99939a2bd79d5d3a3e8059d48bf933962b37caa9)
with the condensation at
[`7757c3f`](https://github.com/seanjennings960/dotfiles/commit/7757c3f64a7c7135e7b09a2592124d685fbef0f2).
The intervening expanded overview existed in the editing session but was not a
separate commit. These counts therefore compare against the original PR, not
against that longer draft.

| Measure | Original PR | Condensed revision |
| --- | ---: | ---: |
| Overview and outline, words | 1,121 | 483 |
| Chapter 1, words | 812 | 644 |
| Combined words | 1,933 | 1,127 |
| Total chapters in the plan | 15 | 5 |
| Written chapters | 1 | 1 |

Word counts use `git show <revision>:<path> | wc -w` for
`docs/tutorials/zsh/intro-to-zsh.md` and `docs/tutorials/zsh/ch1.md`.
The combined reduction is about 42%. It measures length, not learning effort.
The later book completion and terminal companion at `d2c2683` are outside this
comparison.

## What improved

The [original beginner chapter][before-ch1] separated command arguments,
variables and quotes, and wildcards. The [revision][after-ch1] groups them under
one question, "What exact words reach the command?" This is a substantive
connection. It explains why quoting a wildcard changes what a program receives.

The same organizing model appears in the [revised overview][after-intro] and
the beginner walkthrough. Context covers the state a command uses. Arguments
cover the words it receives. Execution covers streams and process behavior.
Interaction covers entering commands and inspecting state. Readers get a
consistent way to locate explanations instead of a list of features at different
levels of detail.

The revision also treats testing as a practice throughout the material and uses
one workspace function to connect the planned deeper chapters. The opening
retains the repo's motivation of understanding agent-generated work. These
changes give the material a purpose beyond memorizing syntax.

Some improvements add necessary information rather than remove words. Chapter 1
now starts Zsh explicitly, selects the keymap its shortcuts assume, and shows
that `false | true` returns success by default. The worked exercise explains why
`wc -l < "shopping list.txt"` receives no filename argument. These details help
the reader distinguish command text, arguments, and redirection.

## What the condensation did not solve

### Distinct questions still depend on each other

Shell options belong to context but change expansion and pipeline behavior.
Completion constructs arguments, and hooks execute commands. Execution still
contains several different mechanisms, including data flow and process lifetime.
The four categories reduce overlap in explanations; they are not independent
parts of the shell, nor an established minimum. The published rewrite did not
compare alternative groupings or explain where dependencies cross its boundaries.

### Concept order became teaching order

In the revised chapter, the context section uses `echo "$PATH"` and
`export MY_SETTING="enabled"` before the arguments section explains quoting and
assignments. That is a regression for an introduction with no assumed shell
experience. The original chapter explained command arguments and quoting before
introducing environment variables.

The deeper plan also puts autoloading and localized function state before its
chapter on writing functions. A useful reference taxonomy does not automatically
provide a good learning sequence. Keep the four questions for orientation while
introducing only the prerequisite needed for the next exercise.

### Some promises became too vague to audit

The [original outline][before-intro] explicitly named native Zsh word splitting
and array indexing differences, `pipestatus`, the limits of `ERR_EXIT`, and
previewing file selections before applying changes. The revised outline uses
broader labels such as "quoting and expansion" and "explicit error handling."
Those labels could include the original lessons, but they no longer commit to
teaching them.

Likewise, one table row now covers scripts, streams, process substitution, jobs,
signals, cleanup, and debugging. It is a compact contents list, not evidence that
these subjects became one easier concept. Short examples and specific caveats
must carry the explanation when the chapters are written.

## Implications for the skill

Keep the central technique of grouping material by the questions it answers.
Add a preservation inventory before editing and a prerequisite review afterward.
Check each proposed merge against a case where the distinction matters. Permit
small reminders and layered explanations when they help the reader act.

The shell examples and keybindings were checked during the condensation. Those
checks support their technical accuracy. They do not show that a beginner learns
faster from the revision. A useful next evaluation would ask a reader to explain
an unfamiliar command's arguments and failure status using the tutorial.

## Review cases for the skill

These are manual checks of the instructions, not results from reader testing or
independent agent runs.

| Situation | Expected decision | Instruction that supports it |
| --- | --- | --- |
| Quoting, variable expansion, and globbing appear in separate sections with repeated explanation. | Group them by how they construct arguments, retaining literal versus expanded examples. | Group by mechanism and retain distinguishing examples. |
| A context-first tutorial uses quoted assignments before explaining them. | Supply the prerequisite or change the teaching order while retaining the concept map. | Separate conceptual organization from teaching order. |
| An edit replaces a rule about pipeline failures with the words "handle errors." | Restore the rule or explicitly acknowledge that coverage was removed. | Account for essential items and reject vague substitutes. |
| A short guide already explains one task with a necessary exception. | Keep the exception and make only changes that improve clarity; do not invent a multi-part taxonomy. | Avoid target counts and allow already simple material to remain. |

[before-ch1]: https://github.com/seanjennings960/dotfiles/blob/99939a2bd79d5d3a3e8059d48bf933962b37caa9/docs/tutorials/zsh/ch1.md
[after-ch1]: https://github.com/seanjennings960/dotfiles/blob/7757c3f64a7c7135e7b09a2592124d685fbef0f2/docs/tutorials/zsh/ch1.md
[before-intro]: https://github.com/seanjennings960/dotfiles/blob/99939a2bd79d5d3a3e8059d48bf933962b37caa9/docs/tutorials/zsh/intro-to-zsh.md
[after-intro]: https://github.com/seanjennings960/dotfiles/blob/7757c3f64a7c7135e7b09a2592124d685fbef0f2/docs/tutorials/zsh/intro-to-zsh.md
