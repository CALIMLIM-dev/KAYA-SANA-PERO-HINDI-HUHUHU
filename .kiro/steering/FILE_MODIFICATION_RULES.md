# FILE MODIFICATION RULES (MANDATORY)

## Never Overwrite Existing Files

Use `str_replace` for targeted edits, not `fs_write` to overwrite.

## Large Section Replacements

If replacing a large section of code, explain why it's necessary.

## Comments

Preserve existing comments unless they are incorrect or misleading.

## Minimal Changes

Make the smallest possible change to achieve the goal.
