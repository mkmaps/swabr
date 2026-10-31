# Projects

Projects removes build and dependency folders from your software projects, e.g. `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` and 27 more kinds.

## Search locations
By default: ~/dev, ~/Projects, ~/GitHub, ~/Code and other usual folders. Add your own with **Add folder …** at the top, also on external drives. The search goes 6 levels deep (adjustable).

## Safety rules
- Only folders inside a project (with package.json, Cargo.toml, go.mod, Package.swift and others).
- Folders with git-tracked files or key files (`*-keypair.json`) stay untouched.
- `bin` only in .NET projects, `vendor` only with PHP/Composer.
- Folders used in the last 7 days are marked and not preselected (adjustable).

## Afterwards
Every row says how to get the folder back (e.g. `npm install`, `cargo build`). By default they are deleted permanently; "Move to Trash instead" is available.
