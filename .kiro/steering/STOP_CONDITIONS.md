# STOP CONDITIONS (MANDATORY)

Immediately stop implementation if:

- You cannot find the referenced file.
- You cannot verify the architecture.
- Multiple implementations already exist.
- The requested feature appears to already exist.
- Creating a new file would duplicate existing functionality.

## When Stopped

Explain the issue and wait for instructions.

Do not guess.
Do not proceed.
Do not make assumptions.

## Examples:

**Stop:** "Cannot find file `UserController.php` - searched in `app/Http/Controllers/` and `app/Http/Controllers/Admin/`. Please provide the correct path."

**Stop:** "Found two existing implementations: `SkillService` and `WorkerSkillService`. Which should I extend?"

**Stop:** "The requested feature (skills display in admin) appears to already exist in `show.blade.php` lines 200-230. Should I modify the existing section or create a new one?"
