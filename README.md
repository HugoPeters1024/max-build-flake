## Patch vscode lps extension for java with 1 command:

$(nix build .#jdtlsPatcher --print-out-paths)/bin/patch-vscode-jdtls

This will build ecj and eclipse and use the resulting language server to patch the plugin.

