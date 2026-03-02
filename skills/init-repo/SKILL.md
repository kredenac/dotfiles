---
name: init-repo
description: Initialize current directory as a git repo, set up project scaffolding, and push to GitHub as a private repo. Use when user says "init repo", "init-repo", or wants to set up a new project.
user-invokable: true
---

# init-repo

Initialize the current working directory as a git repo with appropriate config, then push to GitHub as a private repo.

## Steps

1. **Check current state** — Check if already a git repo, if CLAUDE.md exists, if package.json exists, etc. Detect what kind of project this is (TypeScript, Python, etc.) or ask the user if unclear.

2. **Ask clarifying questions** — Use AskUserQuestion for anything ambiguous:
   - Project type if not obvious (TypeScript, Python, etc.)
   - Repo name if the directory name isn't a good default
   - Any other unclear details

3. **Initialize git** — Run `git init` if not already a repo.

4. **Create .gitignore** — Generate an appropriate `.gitignore` for the detected project type. For TypeScript/Node: include `node_modules/`, `dist/`, `.env`, etc. For Python: include `__pycache__/`, `.venv/`, etc. Don't overwrite an existing `.gitignore` — merge into it if needed.

5. **TypeScript project setup** — If this is a TypeScript project:
   - Ensure `package.json` exists with `"type": "module"` and a `tsx`-based start script
   - Ensure `tsconfig.json` exists with sensible defaults (ESM, strict)
   - Add `tsx` as a dev dependency if not present
   - Run `npm install` if dependencies were added

6. **CLAUDE.md** — Handle the project CLAUDE.md:
   - **If it already exists**: Read it. Ensure it contains an instruction telling Claude to keep CLAUDE.md up to date after any meaningful changes. If that instruction is missing, append it.
   - **If it doesn't exist**: Create a minimal CLAUDE.md with a project header, brief description placeholder, and the instruction: "Always keep this CLAUDE.md up to date after any meaningful changes to the project structure, conventions, or tech stack."
   - **Testing section**: If tests don't already exist in the project (no `tests/` directory, no test files), include this section in CLAUDE.md:
     ```
     ## Testing (delete this section after tests are implemented)
     When adding tests to this project, follow these conventions:
     - Use Vitest as the test runner
     - Tests live in `tests/` directory, separate from source
     - Suppress console noise from code under test — only show pass/fail
     - Write integration tests that exercise the project from the user's perspective, not isolated unit tests
     - Mock external dependencies (network, APIs, CLIs) for reliability and speed, but exercise as much real code as possible
     ```
     If tests already exist (test files or test directories are present), do NOT add this section.

7. **Initial commit** — Stage all files and create an initial commit with a descriptive message.

8. **Push to GitHub** — Use `gh repo create` to create a private repo on GitHub and push:
   ```
   gh repo create <repo-name> --private --source=. --push
   ```

9. **Summary** — Tell the user briefly what was done: repo created, files added, URL of the GitHub repo.

## Notes

- Default to TypeScript + tsx for new TS projects (ESM, `"type": "module"`).
- Always create the repo as **private**.
- If anything is unclear (project type, name, etc.), ask — don't guess.
- Don't overwrite existing files — merge or append as appropriate.
- The CLAUDE.md self-update instruction is the key requirement: every project CLAUDE.md must tell Claude to keep it current.
