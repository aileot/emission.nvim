# Changelog

## [1.1.0](https://github.com/aileot/emission.nvim/compare/v1.0.1...v1.1.0) (2024-12-08)


### Features

* **config:** deprecate `highlight.filter` option in favor of `{added,removed}.filter` ([#31](https://github.com/aileot/emission.nvim/issues/31)) ([f0d7ca0](https://github.com/aileot/emission.nvim/commit/f0d7ca0068bc48c151a75b2aa375cb5d5e053605))
* **interface:** add `.override()` ([#19](https://github.com/aileot/emission.nvim/issues/19)) ([bba5813](https://github.com/aileot/emission.nvim/commit/bba5813ab7a0d747a4e76ef65695fdd89dcc8c45))
* **interface:** add `.reset()` to reset to last `.setup()` config ([#21](https://github.com/aileot/emission.nvim/issues/21)) ([f63979c](https://github.com/aileot/emission.nvim/commit/f63979c0afe83fa06b4abc2156c85ca10bc399eb))
* **option:** add `{added,removed}.min_byte` ([#34](https://github.com/aileot/emission.nvim/issues/34)) ([7c5c54d](https://github.com/aileot/emission.nvim/commit/7c5c54dc7107f07eae929ac7654431581deca55e))
* **option:** add `{added,removed}.min_row_offset` filter ([#25](https://github.com/aileot/emission.nvim/issues/25)) ([23c73fb](https://github.com/aileot/emission.nvim/commit/23c73fb6cc08cb5f57962e82f0b1a3f0488ef229))
* **option:** add helper interface `on_events` ([#23](https://github.com/aileot/emission.nvim/issues/23)) ([8d356d8](https://github.com/aileot/emission.nvim/commit/8d356d8f7683fcd3e9c844fbf4b1694471ff225e))
* **option:** add option `{added,removed}.enabled` ([#29](https://github.com/aileot/emission.nvim/issues/29)) ([c235ed1](https://github.com/aileot/emission.nvim/commit/c235ed199c7917f3b873ae22a8bcb4b97347b7a2))
* **option:** deprecate `highlight.min_byte` in favor of `{added,removed}.min_byte` ([#35](https://github.com/aileot/emission.nvim/issues/35)) ([9fa4d4c](https://github.com/aileot/emission.nvim/commit/9fa4d4ccbf1a1ba65b04dce75001f3bb98478948))
* **option:** enable filters per added/removed ([#27](https://github.com/aileot/emission.nvim/issues/27)) ([17c3891](https://github.com/aileot/emission.nvim/commit/17c389130486b022df7e721c4d7875372c5b9deb))


### Bug Fixes

* **config:** make `.override()` work as expected ([#22](https://github.com/aileot/emission.nvim/issues/22)) ([d1c7179](https://github.com/aileot/emission.nvim/commit/d1c717907a7822279769e7ebc38592319f6191fc))
* **option:** correct `min_row_offset` adjustment ([#30](https://github.com/aileot/emission.nvim/issues/30)) ([a0b350c](https://github.com/aileot/emission.nvim/commit/a0b350cb697f82f13fa6312156702c9bc2a8363d))
* **setup:** override default config at `hl_map` options ([#14](https://github.com/aileot/emission.nvim/issues/14)) ([5f6aa17](https://github.com/aileot/emission.nvim/commit/5f6aa1737e01e4da292ac48d4076e6e2339754b5))

## [1.0.1](https://github.com/aileot/emission.nvim/compare/v1.0.0...v1.0.1) (2024-12-01)


### Bug Fixes

* **detach:** discard highlight stack on detach ([#10](https://github.com/aileot/emission.nvim/issues/10)) ([47da944](https://github.com/aileot/emission.nvim/commit/47da944ba6bd7d5112db52fdddb7db4ccfe4b731)), closes [#8](https://github.com/aileot/emission.nvim/issues/8)

## 1.0.0 (2024-12-01)

Initial Release
