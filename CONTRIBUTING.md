# Contributing

> [!IMPORTANT]
> This project is mainly written in [Fennel][] to be transpiled to Lua.
> The Lua files under `fnl/` are also copied to `lua/` directory.
>
> Do **NOT** directly edit **any** Lua files under `lua/` directory.
> Instead, edit the files under `fnl/` directory.

Any kind of contributions are welcome.

Before any changes,
please run [`make init`](#make-init)
at the repository's root directory.
For larger features,
please open an issue first to avoid duplicate work.

## Building

### `make init`

This command will setup the project:

1. Activate [`.githooks/`](./.githooks).\
   This helps automatically keep the files under `lua/` up-to-date on every
   `git-commit`.
   Note that you cannot stage unrelated Lua files under `lua/`
   if there are no corresponding files staged under `fnl/`.
   It also helps you resolve conflicts in the generated files under `lua/`.
   Follow the [section](#how-to-resolve-conflicts-in-lua) below
   for the details.

2. Generate `.envrc` for nix users.\
   It only helps if you have `nix` and `direnv` installed.
   Please check the `.envrc` contents, and run `direnv allow`.

### `make build`

This command will do two things:

1. Transpile all the updated **Fennel** files
   under `fnl/` to `lua/` directory.
2. Copy all the updated **Lua** files
   under `fnl/` to `lua/` directory.

This command is also executed automatically on [`make test`](#testing)
and
(once you run [`make init`](#make-init))
on `git-commit`.

See also the section:
[How to resolve conflicts in `lua/`](#how-to-resolve-conflicts-in-lua).

### How to resolve conflicts in `lua/`

(Please make sure you have already run [`make init`](#make-init).)

1. Resolve all conflicts in `fnl/` at the commit.
2. Run `make clean build`.
3. Done!
   All the Lua files should be up-to-date without any conflicts.

### Architecture

As described above, this project is mainly written in [Fennel][];
however, some files are written in Lua under `fnl/`:

- `config.lua`
  to make it easier for prospective contributors unfamiliar with [Fennel][].

```tree
fnl/
└── emission/
    └── config.lua
```

## Testing

1. Make sure [Requirements](#test-requirements) are installed,
   or follow the steps [for nix users](#testing-for-nix-users).
2. Run `make test`.

### Test Requirements

- [make][]: the build/test interface
- [fennel][]: the compiler
- [vusted][]: the test runner

#### Testing for nix users

If you have `nix` installed,
you can automate the requirement installation
with the following options enabled:

1. `flake` feature
2. `programs.direnv.enable`

Then, run `direnv allow` in this project directory.
Otherwise, please run `nix develop` in this project directory.

[fennel]: https://sr.ht/~technomancy/fennel/
[make]: https://www.gnu.org/software/make/manual/html_node/index.html
[vusted]: https://github.com/notomo/vusted
