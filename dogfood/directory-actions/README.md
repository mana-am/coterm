# Directory Actions Dogfood

This tree is for dogfooding per-directory `coterm.json` resolution.

Use a terminal pane in coterm and `cd` into these directories:

- `dogfood/directory-actions/alpha`
- `dogfood/directory-actions/alpha/nested`
- `dogfood/directory-actions/legacy`
- `dogfood/directory-actions/legacy/prefer-dot-coterm`
- `dogfood/directory-actions/many-tab-actions`

What each one demonstrates:

- `alpha`
  - Inherits the ancestor `./.coterm/coterm.json`
  - Shows ancestor lookup from the active pane cwd
- `alpha/nested`
  - Has its own `./.coterm/coterm.json`
  - Overrides `coterm.newTerminal`
  - Replaces the surface tab bar button list
  - Still inherits parent actions into Command Palette
- `legacy`
  - Uses fallback `./coterm.json`
  - Demonstrates backward-compatible local config loading
- `legacy/prefer-dot-coterm`
  - Contains both `./coterm.json` and `./.coterm/coterm.json`
  - The `./.coterm/coterm.json` file should win
- `many-tab-actions`
  - Defines 24 custom actions plus the 4 built-ins
  - Replaces the surface tab bar button list to stress wide action rows

General expectations:

- Image-backed project-local icons start as a lock until that exact action is trusted.
- Emoji-backed project-local actions show their emoji immediately, but still prompt on first run.
- Running a trusted action opens a new terminal tab in the current pane and sends the configured shell input.
- Command Palette should update as the active pane cwd changes.
