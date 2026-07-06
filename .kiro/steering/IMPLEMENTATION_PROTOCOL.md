# IMPLEMENTATION PROTOCOL (MANDATORY)

Before modifying ANY file, enter ANALYSIS MODE.

## PHASE 1 — ANALYSIS ONLY

Do NOT write code.
Do NOT edit files.
Do NOT create files.
Do NOT execute commands.

First analyze the request.

Return ONLY the following sections:

### 1. Request Understanding
Describe exactly what you believe I am asking.

### 2. Existing Code Analysis
Before suggesting any implementation, identify:
- Existing files that already solve part of the problem.
- Existing reusable logic.
- Existing UI components.
- Existing API endpoints.
- Existing database tables.
- Existing models.

If none are found, explicitly state:
"No existing implementation found after searching the project."

Do not recommend creating new code until this section is complete.

### 3. Current State
Explain how the current implementation works based ONLY on the codebase.
If something cannot be verified from the codebase, state:
"Cannot verify from current project."
Never assume.

### 4. Required Changes
List every modification required.

### 5. Files To Modify
List every file you expect to edit.
For each file include:
- reason
- estimated modification

Do not include unrelated files.

### 6. Potential Side Effects
Explain what existing functionality could break.

### 7. Questions
If anything is ambiguous, ask now.

### 8. Execution Plan
Provide the exact implementation steps.

STOP.

Wait for my approval.
Do not generate code.
Do not modify anything.

---

## PHASE 2 — POST-IMPLEMENTATION SUMMARY

After implementation, provide:

### 1. Files Modified
List every file changed with file path.

### 2. Reason for Each Modification
Explain why each file was modified.

### 3. Database Changes
- Migrations run
- Tables created/modified
- Columns added/removed
- Indexes added
- Foreign keys added

If no database changes: state "None"

### 4. Breaking Changes
- API changes
- Signature changes
- Removed features
- Behavior changes

If no breaking changes: state "None"

### 5. Manual Steps Required
- Environment variables to add
- Commands to run
- Configuration changes
- Third-party setup

If no manual steps: state "None"

### 6. Testing Checklist
- What to test
- Expected behavior
- Edge cases to verify
