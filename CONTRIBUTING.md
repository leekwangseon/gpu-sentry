# Contributing

Contributions are welcome. Open an issue before large changes, keep each pull
request focused, and do not include customer logs or credentials.

## Development

Requirements: Bash 4.4+, ShellCheck 0.9+, and Bats for the optional test suite.

```bash
make lint
make test
```

All shell files must use strict mode, quote expansions, pass ShellCheck, and
include tests for parsing or diagnostic-policy changes. Commit messages should
be imperative and releases use Semantic Versioning.

