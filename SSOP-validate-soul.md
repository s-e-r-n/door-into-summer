# SSOP validate-soul

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| Higgsfield job | `higgsfield generate get --json -- <id>` | the store line | `validation.generation_of`, through `jobs.shown_fields` | `Generation`: `result_url: str`, `extension: str`, `model`, `aspect`, `quality`, `resolution`, `prompt: str \| None`, `batch: int \| None` | a generation without a `result_url` naming a file extension; a field of another type than the store line's |
| the image's pixel size | `magick identify -format "%w %h"` on the downloaded file | `parameters.ratio`, `parameters.resolution` of the store line | `validation.pixel_size` | `tuple[int, int]`, both positive | a ratio with a zero term |
| store line | `validation.validate` | store.jsonl | `store.Line` | `parameters.ratio: str`, `parameters.resolution: str`, `parameters.quality: str \| None`, `parameters.batch: int \| None`, `model`, `prompt: str \| None` | a store line without a ratio or a resolution |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `store.Line`, `store.Parameters` | | the fields of a store line | | bin/review/store.py |
| `validation.validate` | `store.Line`, `jobs.shown_fields`, `Card` | `session`, `attempt`, `card` | the gallery file name | bin/review/validation.py |

Edges: `validation` needs `store.Line` and `store.Parameters`.

1. bin/review/store.py
2. bin/review/validation.py
3. README.md, tests/validate.test.sh, project-level-past-decisions-log.md

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| store | the store line's schema and how a line is appended | `Line` and its fields; `append` raises `AlreadyFiled` or `OSError` |
| validation | what filing an image requires of its job, and where a field the job lacks comes from | `validate(session, attempt, card)` returns the file name; raises `NotShown`, `HiggsfieldFailed`, `AlreadyFiled`, `OSError` |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| the store line of a job | store.jsonl, through `store` | a card's `validated`, `--match`, the uniqueness check of `append` | `store.append`, called by `validation.validate` |

## Amendments

- `validation.parameters_of` reads the pixel size of every filed image, and uses it only where the job holds no `aspect` or no `resolution`: one code path, one more `magick identify` per validation.
- The rug case of tests/validate.test.sh asserted the refusal of a job without `prompt`, which the correction removed; it now asserts the refusal of a job without `result_url`, the one field still required.
