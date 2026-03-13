# Issue #505 Resolution: Centralize Shoes Size Mappings

## Summary

Successfully centralized all Shoes text size mappings (banner, title, subtitle, tagline, caption, para, inscription) into a single source of truth in `scarpe-components`, eliminating code duplication across 5+ files.

## Problem

The mapping of Shoes size names to pixel values was duplicated in multiple locations:
- `scarpe-components/lib/scarpe/components/calzini.rb`
- `lib/scarpe/wv/para.rb`
- `scarpe-components/lib/scarpe/components/tiranti.rb` (hardcoded thresholds)
- `spikes/libui/para.rb` (experimental code)
- `spikes/glibui/para.rb` (experimental code)

This caused maintenance issues and risked inconsistencies if sizes were updated in one place but not others.

## Solution

### 1. Created Centralized Module
**File:** `scarpe-components/lib/scarpe/components/shoes_sizes.rb`

```ruby
module Scarpe::Components::ShoesSizes
  SIZES = {
    inscription: 10,
    ins: 10,
    para: 12,
    caption: 14,
    tagline: 18,
    subtitle: 26,
    title: 34,
    banner: 48,
  }.freeze

  def self.text_size(sz)
    # Converts symbol/string/numeric to pixel size
  end
end
```

### 2. Updated All Files

#### scarpe-components/lib/scarpe/components/calzini.rb
- Added `require_relative "shoes_sizes"`
- Changed `SIZES = { ... }` to `SIZES = Scarpe::Components::ShoesSizes::SIZES`
- Updated `text_size()` method to delegate to `ShoesSizes.text_size()`

#### lib/scarpe/wv/para.rb
- Changed `SIZES = { ... }` to `SIZES = Scarpe::Components::ShoesSizes::SIZES`
- Removed 7 lines of duplicated size mappings
- Added reference to centralized source

#### scarpe-components/lib/scarpe/components/tiranti.rb
- Updated `para_element()` method to use `Scarpe::Components::ShoesSizes::SIZES`
- Replaced hardcoded values (48, 34, 26) with `sizes[:banner]`, `sizes[:title]`, `sizes[:subtitle]`
- Now automatically stays in sync with canonical sizes

#### spikes/libui/para.rb & spikes/glibui/para.rb
- Added comments referencing the canonical source
- Left duplicate SIZES in place (spike code doesn't load scarpe-components)

### 3. Comprehensive Test Coverage

#### scarpe-components/test/test_shoes_sizes.rb (22 tests)
- Tests for all 8 size names
- Tests for `text_size()` method with symbols, strings, and numbers
- Edge case tests (unknown sizes, invalid types)
- Verifies SIZES hash is frozen
- **Result: 22 runs, 22 assertions, 0 failures, 0 errors**

#### test/test_shoes_sizes_integration.rb (7 tests)
- Integration tests verifying Calzini uses centralized sizes
- Tests that `text_size()` delegation works correctly
- Verifies Calzini and ShoesSizes return identical results
- Tests public API contract
- **Result: 7 runs, 23 assertions, 0 failures, 0 errors**

## Files Changed

### Created (2 files):
1. `scarpe-components/lib/scarpe/components/shoes_sizes.rb` - Centralized size mapping
2. `scarpe-components/test/test_shoes_sizes.rb` - Unit tests
3. `test/test_shoes_sizes_integration.rb` - Integration tests

### Modified (5 files):
1. `scarpe-components/lib/scarpe/components/calzini.rb` - Use centralized SIZES
2. `lib/scarpe/wv/para.rb` - Use centralized SIZES
3. `scarpe-components/lib/scarpe/components/tiranti.rb` - Use centralized size constants
4. `spikes/libui/para.rb` - Added comment referencing canonical source
5. `spikes/glibui/para.rb` - Added comment referencing canonical source

## Test Results

### ShoesSizes Unit Tests
```
22 runs, 22 assertions, 0 failures, 0 errors, 0 skips
```

### ShoesSizes Integration Tests
```
7 runs, 23 assertions, 0 failures, 0 errors, 0 skips
```

**Total: 29 tests, 45 assertions, 100% pass rate**

## Benefits

1. **Single Source of Truth**: All size mappings now come from one location
2. **Easier Maintenance**: Change sizes in one place, affects entire codebase
3. **Consistency**: Impossible for sizes to drift out of sync
4. **Better Documentation**: Clear module with YARD docs explaining the purpose
5. **Type Safety**: Centralized validation and error handling
6. **Testable**: Comprehensive test coverage prevents regressions

## Backward Compatibility

✅ **Fully backward compatible**
- All existing code continues to work
- No API changes
- Calzini's `SIZES` constant remains (as reference to centralized constant)
- All Webview code continues using familiar patterns

## Future Work

The remaining spike files (`spikes/libui/para.rb` and `spikes/glibui/para.rb`) still contain duplicated SIZES hashes. When these experimental display services are developed further, they should be updated to depend on `scarpe-components` and use the centralized mapping.

## Issue Resolution

✅ Resolves https://github.com/scarpe-team/scarpe/issues/505

All requirements from the issue have been met:
- ✅ Single Scarpe Component with size mapping created
- ✅ All production code updated to use it
- ✅ Size information comes from one place, not separate copies
- ✅ Tiranti's different structure (size + HTML tag) handled correctly
