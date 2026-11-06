---
name: simplify
description: Use when asked to simplify, condense, or consolidate tutorials, explanations, plans, or documentation by reducing overlapping concepts while preserving meaning and usability.
---

# Simplify

Reduce what the reader must learn to accomplish the material's purpose. Seek
the smallest useful set of distinct concepts that preserves the necessary
meaning. A shorter document or fewer headings alone does not establish success.

## 1. Establish what must survive

- Identify the audience, intended tasks, and reason this material exists.
  Preserve the specific motivation that makes it worth reading.
- Record the starting version and scope. Separate essential claims, decisions,
  and distinctions from examples, repeated explanations, and incidental detail.
- Note prerequisites, exceptions, and failure behavior. In runnable material,
  record assumptions needed to reproduce the examples. In plans or policies,
  preserve responsibilities and conditions that change a decision.

Keep this inventory brief. Ask for clarification only when uncertainty would
change what can be removed; otherwise proceed with an explicit assumption.

## 2. Find a smaller conceptual model

Give each candidate concept a distinct question it helps the reader answer.
Group topics by shared meaning or mechanism, rather than by similar vocabulary.
Quoting and globbing, for example, both determine the arguments a command receives.

Test the proposed boundaries:

- If two concepts answer the same question, try merging them.
- If a concept collects unrelated questions, split it or choose a better basis
  for grouping. Renaming many topics as one category does not simplify them.
- Try removing or merging a remaining concept. Keep the distinction when its
  loss makes a relevant explanation ambiguous or requires more exceptions.
- Map every essential item to the model. Use cross-references for genuine
  dependencies instead of repeating the explanation or pretending independence.

Consider a plausible alternative, including the existing structure. Prefer the
model that explains the required material with fewer independent ideas and less
special handling. Do not force a target count or claim a proven minimum.

## 3. Rebuild for the reader

Conceptual organization and teaching order are separate choices. Introduce what
an example depends on before asking the reader to use it. A concept may recur at
greater depth; one concept need not equal one chapter.

- Explain each idea once in a natural home. Keep short reminders where readers
  need them to complete a task.
- Retain examples that distinguish cases readers could confuse, along with
  expected results and the relevant caveats. Remove duplicate demonstrations.
- Use tables for comparison and navigation. Use prose or worked examples to
  explain mechanisms; a dense inventory is not a lesson.
- Keep terminology stable and write complete sentences. Expand a sentence when
  compression makes the reader supply a missing assumption or infer a new term.

Apply sentence-level editing after restructuring. Preserve the material's
purpose and voice while removing repeated claims.

## 4. Check preservation and usefulness

Account for each essential item as retained or relocated. Reconsider omissions;
make any deliberate reduction in scope explicit. Broad labels such as "error
handling" do not preserve a specific rule about which failures get reported.

Walk through a representative reader task and a counterexample that challenges
the grouping. Check whether the reader can find the needed explanation and has
its prerequisites. Verify affected runnable examples and navigation where
applicable. Separate those checks from evidence of actual reader comprehension.

Review the result for distinct concepts, preserved meaning, prerequisite order,
and readable presentation. Stop when further compression would weaken one of
these. Keeping a useful distinction or leaving an already simple passage alone
can be the right result.

Report the organizing model, the main improvement, any meaningful tradeoff, and
what you verified. If reporting length or section counts, name the baseline and
compare the same scope. Treat those counts as size measurements, not proof of
reduced conceptual complexity.

## Worked evaluation

Read [the Zsh evaluation](references/zsh-evaluation.md) when a concrete example
of the tradeoffs would help. It examines both the stronger organization and the
teaching-order problems introduced by a condensation.
