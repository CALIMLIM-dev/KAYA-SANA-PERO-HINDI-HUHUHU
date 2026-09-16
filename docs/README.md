# Appendices

Material for the research paper, kept beside the code so it cannot drift from it.

| File | Contents | How it is kept current |
|---|---|---|
| appendix-architecture.md | The two programs, the database, the services around them, security, deployment | By hand |
| appendix-use-cases.md | Actors and what each can do | By hand |
| appendix-dfd.md | Data flow diagrams, levels 0 to 3 | By hand |
| appendix-erd.md | Entity relationship diagram (Mermaid) | `php artisan kaya:document-schema ../docs` |
| appendix-data-dictionary.md | Every table and column | `php artisan kaya:document-schema ../docs` |
| appendix-api.md | Every API endpoint and admin route | Generated from `php artisan route:list --json` |
| appendix-tests.md | The test suites and what they cover | By hand, counts from the last run |
| appendix-licences.md | Third-party components, data sources, licences and attributions | By hand |

Also relevant, in the repository root: `README.md` (how to run it), `PLAN-barya-overhaul.md` (the pricing model and its reasoning), `STATUS.md` (what shipped, what is open), `CHANGELOG.md`.

Still to add for the paper, not in this folder: screenshots of each screen (the golden images in `kaya_app/test/goldens/` are exact renders at 1080x2400 and can be used directly), the user manual, and the survey instruments.
