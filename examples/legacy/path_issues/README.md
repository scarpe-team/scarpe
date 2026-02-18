# Examples with Hardcoded Path Issues

These examples were written for Shoes3's specific directory structure and use
hardcoded paths like `#{DIR}/samples/good/` that don't exist in Scarpe.

- **_why-stories.rb**: Uses `#{DIR}/samples/good/_why-stories.yaml` path
  - Accompanying YAML and SVG files are preserved here
  - Could work if paths were updated (but we don't modify examples)

The `DIR` constant in Scarpe points to the Scarpe installation directory,
matching Shoes3 behavior. However, Scarpe doesn't maintain the same
`samples/` directory structure that Shoes3 had.
