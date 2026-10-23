---
name: extract-transcript
description: >-
  Download and format the transcript/captions of a YouTube video from its URL
  (or video id), and optionally summarize it. Use this skill whenever the user
  shares a YouTube link or video id and wants the words from it -- e.g. "get the
  transcript", "what does this video say", "pull the captions", "transcribe this
  YouTube video", "summarize this video/talk/lecture/podcast", "give me the
  notes from this video", or asks for a TL;DR, key points, or detailed outline
  of a YouTube video. Trigger even when the user does not say the word
  "transcript" but clearly wants the spoken content of a YouTube video in text.
  YouTube only for now; the structure anticipates other platforms later.
---

# extract-transcript

Turn a YouTube video into clean Markdown text, then (when asked) summarize it at
the level of detail the user needs. The heavy lifting of fetching and formatting
is done by a small, reliable Python script so the transcript comes out
predictably every time; your job is to run it, hand back the Markdown, and
produce good summaries on top of it.

## When to use this

Use it whenever the user points at a YouTube video and wants its spoken content
as text: a raw transcript, cleaned-up notes, or a summary. A URL or a bare
11-character video id is enough to start. If the user only wants a summary, you
still fetch the transcript first -- the transcript is the source material every
summary is built from.

## Workflow

1. **Get the input.** Accept a full YouTube URL (`watch?v=`, `youtu.be/`,
   `/shorts/`, `/live/`, `/embed/`) or a bare video id. You don't need to parse
   it yourself -- the script does.
2. **Make sure the dependency is present.** The script needs
   `youtube-transcript-api`. If it isn't installed, install it:
   `pip install youtube-transcript-api` (add `--break-system-packages` on a
   managed/system Python if pip refuses).
3. **Run the fetch script** (see below) to produce the Markdown transcript.
4. **Deliver the transcript** as a `.md` file when the user wants the transcript
   itself, or keep it in hand as source material when they only asked for a
   summary.
5. **Summarize if asked**, choosing the detail level from the guidance further
   down. Match the level to what the user actually wants rather than defaulting
   to the longest one.

## Running the fetch script

The script lives at `scripts/fetch_transcript.py` next to this file. It prints
Markdown to stdout, or writes it to a file with `-o`.

```bash
# Print a grouped, timestamped Markdown transcript
python scripts/fetch_transcript.py "https://www.youtube.com/watch?v=VIDEO_ID"

# Save it to a file
python scripts/fetch_transcript.py "https://youtu.be/VIDEO_ID" -o transcript.md

# Clean prose with no timestamps -- best when the next step is summarizing
python scripts/fetch_transcript.py VIDEO_ID --no-timestamps -o transcript.md

# Prefer a non-English caption track, falling back to English
python scripts/fetch_transcript.py VIDEO_ID --languages es en

# See what caption tracks exist before committing to one
python scripts/fetch_transcript.py VIDEO_ID --list-languages
```

Useful options: `--group-seconds N` controls paragraph size (default 30; raise
it for denser paragraphs), `--raw` emits one line per caption snippet, and
`--no-timestamps` produces flowing prose. Default output keeps timestamps
because they let you and the user jump back to any moment in the video and let
summaries cite where a point was made.

### When fetching fails

The script exits non-zero and explains the cause. The usual ones:

- **Transcripts disabled / none available.** Some videos genuinely have no
  captions. Tell the user plainly; there is no transcript to extract. (Do not
  invent one.)
- **No transcript in the requested language.** Run with `--list-languages` and
  either pick an available track or use the built-in translation by choosing a
  language the track can be translated to.
- **Request blocked / IP blocked.** YouTube blocks many datacenter/VPN IPs. If
  you're running on a cloud host, the fetch may fail even though the video has
  captions. Report this honestly and suggest running from a residential
  connection or configuring a proxy, rather than silently giving up.

## Transcript Markdown format

The script emits a consistent structure so downstream tooling and summaries can
rely on it. Always keep this shape:

```markdown
# <Video title, or "YouTube transcript <id>" if the title can't be fetched>

- **Source:** https://www.youtube.com/watch?v=VIDEO_ID
- **Video ID:** `VIDEO_ID`
- **Language:** English (`en`) - auto-generated
- **Approx. length:** 12:34
- **Caption snippets:** 245
- **Retrieved:** 2026-07-25

---

## Transcript

**[0:00]** First grouped paragraph of spoken text, with several short caption
snippets merged into something readable...

**[0:31]** Next paragraph, and so on.
```

The header is a metadata block (source link, id, caption language and whether it
was manually written or auto-generated, approximate length, snippet count, and
retrieval date). The body is the transcript itself: caption snippets merged into
~30-second paragraphs, each prefixed with a `**[timestamp]**` anchor. Timestamps
are formatted `M:SS`, or `H:MM:SS` once a video passes an hour. Auto-generated
captions carry no punctuation or speaker labels from YouTube -- don't pretend
otherwise, though you may lightly clean obvious artifacts when producing a
polished version if the user asks.

## Summarizing the transcript

A transcript is raw material; most users ultimately want it distilled. Offer, or
pick, one of these levels. They differ in length and purpose, not just size --
choose by what the user will do with it. When in doubt, ask, or give the TL;DR
first and offer to go deeper.

Ground every level strictly in what was actually said. Attribute claims to the
speaker rather than asserting them as fact ("the presenter argues..."), keep the
video's own order unless a thematic regrouping clearly serves the reader better,
and never invent details, numbers, or quotes that aren't in the transcript. When
you cite a specific moment, use the `[timestamp]` from the transcript so the
user can verify it.

### Level 1 - TL;DR (headline)

One to three sentences, ~40-60 words. The single core message and why it
matters. This is what someone reads to decide whether the video is worth their
time. Lead with the conclusion, not the setup.

> **TL;DR:** A hands-on walkthrough of setting up retrieval-augmented
> generation with open-source models. The presenter's main claim is that a small
> local model plus good retrieval beats a large model with none, and shows a
> working example to prove it.

### Level 2 - Key points (executive summary)

A 2-3 sentence framing paragraph followed by 5-8 bullet takeaways, ~150-300
words total. Captures the main arguments, the structure of the video, and its
conclusions -- enough that the reader can discuss it without watching. Each
bullet should be a substantive point (a claim, a step, a finding), not a topic
label. Add a `[timestamp]` to bullets that map to a specific moment.

### Level 3 - Detailed outline (section-by-section)

Follow the video's flow and break it into its natural sections with `##`
headings, each anchored to the timestamp where it begins. Under each, give the
key sub-points, notable examples, data, and any memorable direct quotes (kept
short and marked as quotes). Aim for completeness of ideas while still being
much shorter than the transcript -- roughly 500+ words for a typical talk.
Preserve nuance, caveats, and the reasoning behind claims, not just the
conclusions. This is the level for study notes, show notes, or thorough review.

### Choosing (and combining) levels

The levels nest: Level 2 expands the TL;DR; Level 3 expands the key points. A
good default when the user is vague is to lead with the TL;DR and key points,
then offer the detailed outline. For a short clip, Level 1-2 is usually plenty;
for a lecture, interview, or long podcast, Level 3 earns its length. If the user
asks for something even deeper (verbatim structured notes, a glossary of terms,
a step-by-step of a tutorial), treat that as an extension of Level 3 -- same
principles, more granularity -- built from the transcript, section by section.

## Extending beyond YouTube (future)

This skill is YouTube-only today, but the design anticipates more platforms. The
platform-specific logic (recognizing a URL and fetching its captions) is
isolated at the top of `scripts/fetch_transcript.py`; the Markdown format and
the summary levels above are platform-agnostic and should be reused unchanged.
To add a platform later, add a URL-recognition + caption-fetch pair for it and
dispatch on the URL, then feed its snippets into the same formatting and
summarizing pipeline.
