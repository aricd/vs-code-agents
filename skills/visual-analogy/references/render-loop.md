# Render and revision loop

Use this procedure when an analogy moves from text specification to an image, slide, document, or
web artifact.

## 1. Inspect the consumer

Inspect the actual destination at the size and aspect ratio the audience will see. Record:

- canvas dimensions and crop behavior;
- existing title, body, footer, and note regions;
- typography, palette, line weight, texture, and whitespace;
- repeated visual grammar across neighboring artifacts;
- the exact asset or slide being replaced.

Do not rely on memory of the deck or a full-resolution source image alone.

## 2. Build the render brief

Convert the selected text specification into a production brief:

- label every input image by role: edit target, style reference, or supporting insert;
- quote all text verbatim;
- state reading order and composition;
- state the semantic color grammar;
- list physical, directional, and causal invariants;
- list approved elements that must remain unchanged;
- list elements to remove;
- list forbidden artifacts and plausible wrong readings.

For an edit, repeat the invariants in every iteration. Preserve approved work aggressively.

## 3. Render one complete draft

Create a complete candidate before polishing local details. A draft must expose the whole mapping
so composition and semantic contradictions can be judged together.

## 4. Review at delivery scale

Check the rendered artifact, not only the source asset.

### Semantic review

- Does the first reading match the learning objective?
- Does each color, direction, object, and state keep one meaning?
- Do realistic objects obey the physical behavior their realism implies?
- Are closely related mechanisms visually distinguishable?
- Does the detector, control, or mitigation attach to the mechanism it governs?
- Does the visual silently narrow or replace the user's criterion?

### Presentation review

- Is the main point visible before details?
- Is text exact, crisp, and readable at delivery scale?
- Are labels adjacent to their referents?
- Are connectors unambiguous and clear of text?
- Does whitespace produce hierarchy rather than emptiness?
- Does the artifact match the approved visual language without copying irrelevant clutter?

## 5. Diagnose before editing

Record each problem as:

```text
Observed cue: <what the image shows>
Unintended inference: <what a viewer may conclude>
Source mismatch: <which proposition or mapping it violates>
Correction: <the smallest semantic change that resolves it>
Propagation check: <other cues produced by the same assumption>
```

A complaint such as "this is confusing" is evidence about the mechanism. Find the wrong mapping
before moving pixels. Do not remove or weaken the learning criterion merely because the first
render failed to demonstrate it.

## 6. Iterate with one targeted change

Make the next edit as narrow as possible:

- one text correction;
- one direction or state correction;
- one object replacement;
- one mapping cleanup;
- one density reduction.

If the correction changes the analogy's structure, update the text specification and rescore the
candidate before rendering again.

## 7. Verify the consumer artifact

After selecting the final asset:

- save it under a stable, versioned project path;
- update only the intended consumer reference or embedded payload;
- preserve slide, page, note, and asset counts unless the request changes them;
- verify the embedded bytes or resolved asset match the selected render;
- re-render the destination and inspect it at delivery scale;
- remove temporary screenshots and discarded intermediates from the handoff.

## Stop condition

Stop when:

- every hard semantic gate passes;
- the intended reading wins without presenter repair;
- all exact text is correct and legible;
- no new issue appeared in the destination render;
- another iteration would change aesthetic preference rather than explanatory meaning.
