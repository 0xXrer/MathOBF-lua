
**Features**

* Replaces numeric literals with complex mathematically generated expressions.
* Replaces string literals with either plain `string.char(...)` expressions or encrypted byte arrays with a runtime decryption routine when a password is provided.
* Several generator strategies produce arithmetic, factorial-sum, base representation, sine-based and log/exp-based expressions.
* Depth-limited expression composition to control complexity.
* Simple math-based KDF and PRNG used for XOR encryption of bytes.
* Runtime block included for decrypting encrypted strings and converting byte arrays back to strings.

**Important notes**

* This is an obfuscator for code obfuscation and not a security mechanism. The encryption used is lightweight XOR with a custom PRNG; do not treat it as strong cryptography.
* The script uses `string.gsub` to replace placeholders — take care if your source contains unusual `%` sequences; the code includes escaping to reduce issues but edge cases may remain.
* For demonstration the repository uses an in-memory `source` string. When integrating into file-processing pipelines, ensure correct escaping and safe handling of patterns.

## Usage (example)

1. Add `obfuscator_advanced.lua` to your project.
2. Adjust `PASSWORD` in the demonstration block or pass a password when calling `obfuscate_source(source, password)`.
3. Run under Luau or Lua 5.4 interpreter.

### Example

```lua
-- Simple demo inside the script:
local PASSWORD="super_secure_math"
local source = [[
print("hi")
print('test123')
print(42)
]]
local result = obfuscate_source(source, PASSWORD)
print(result)
```

## Files

* `obfuscator_advanced.lua` — main obfuscator implementation (comments in English included below).

## Contact

Author: `0xXrer`
