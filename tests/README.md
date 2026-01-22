# FIS Mod Unit Tests

This directory contains unit tests for the Fresh Invoice System (FIS) mod for Farming Simulator 25.

## Prerequisites

- Lua 5.1 or later
- LuaRocks package manager
- Busted testing framework

## Installation

### On Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install lua5.1 luarocks
sudo luarocks install busted
```

### On macOS:
```bash
brew install lua luarocks
sudo luarocks install busted
```

### On Windows:
Download and install Lua from https://luabinaries.sourceforge.net/
Then install LuaRocks and busted.

## Running Tests

From the repository root directory:

```bash
# Run all tests
busted tests/

# Run a specific test file
busted tests/FIS_Invoice_spec.lua

# Run tests with verbose output
busted -v tests/

# Run tests with coverage
busted -c tests/
```

## Test Structure

- `test_helper.lua` - Mock objects and helper functions for testing
- `FIS_Invoice_spec.lua` - Tests for the Invoice class
- `FIS_CreateInvoiceEvent_spec.lua` - Tests for the CreateInvoiceEvent
- `FIS_CreateInvoiceDialog_spec.lua` - Tests for the dialog callback functionality

## Test Coverage

The test suite covers:

1. **Invoice Creation and Validation**
   - Invoice instantiation with default values
   - Amount calculation from line items
   - State management (Open, Paid, Declined)
   - Edge cases (empty items, nil values, decimals)

2. **Event System**
   - Event creation and serialization
   - Stream reading/writing
   - Permission validation
   - Server-side event execution
   - Rejection of invalid events

3. **Dialog Callback System**
   - Callback registration
   - Send button validation logic
   - Line item management
   - Total calculation
   - Error handling

## Writing New Tests

When adding new tests:

1. Use `describe()` blocks to group related tests
2. Use `before_each()` to set up test fixtures
3. Use `it()` for individual test cases
4. Use assertions: `assert.equals()`, `assert.is_true()`, etc.
5. Mock external dependencies using the test helper

Example:
```lua
local helper = require("tests.test_helper")

describe("MyFeature", function()
    before_each(function()
        helper.setupMocks()
        -- Setup code
    end)
    
    it("should do something", function()
        -- Test code
        assert.equals(expected, actual)
    end)
end)
```

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: |
    sudo apt-get install -y lua5.1 luarocks
    sudo luarocks install busted
    busted tests/
```

## Troubleshooting

**Issue**: `module 'tests.test_helper' not found`
**Solution**: Make sure you're running busted from the repository root directory.

**Issue**: Tests fail with "attempt to call global X"
**Solution**: Check that all required game engine functions are mocked in `test_helper.lua`.

**Issue**: Busted not found
**Solution**: Make sure busted is installed: `sudo luarocks install busted`

## Contributing

When adding new features:
1. Write tests first (TDD approach)
2. Ensure all tests pass
3. Maintain test coverage above 80%
4. Document any new test utilities in this README
