# Lacci: The Shoes4 Compatibility Layer

## Overview

Lacci (Italian for "laces") serves as the compatibility layer between Shoes4 applications and Scarpe's display services. Think of it as the translator that allows your classic Shoes4 code to work seamlessly with modern display backends.

## Core Concepts

### 1. Event Handling and Drawing Model

Lacci implements the Shoes4 drawing model, which includes:
- Slot-based layout system (stacks, flows)
- Event propagation
- Drawing context inheritance
- Margin and positioning calculations

### 2. Display Service Abstraction

Lacci abstracts away the details of different display services (like Webview or Qt) by:
- Translating Shoes4 drawing commands into display-agnostic operations
- Managing widget lifecycles
- Handling parent-child relationships between elements
- Coordinating style inheritance

### 3. Test Infrastructure

The test infrastructure in Lacci uses Niente (Italian for "nothing"), a null display service that:
- Allows testing without a real display backend
- Verifies drawing operations and event handling
- Supports multiple simultaneous Shoes apps in test environments
- Provides fast, reliable test execution

## Key Components

### MarginHelper
Handles margin calculations with support for:
- Numeric values
- Array-based margins
- Hash-based margins
- String-based margin definitions

### FontHelper
Manages font parsing and styling with support for:
- Font families
- Font sizes
- Font weights
- Font variants
- Font styles

### DrawContext
Manages the drawing context inheritance system:
- Style propagation (fill, stroke, etc.)
- Context stacking
- Property overrides

## Usage Examples

```ruby
# Basic Shoes4 App
Shoes.app do
  stack do
    para "Hello from Lacci!"
    button "Click me" do
      alert "Button clicked!"
    end
  end
end
```

## Error Handling

Lacci provides rich error handling through the `Shoes::Errors` module:
- `InvalidAttributeValueError`
- `BadArgumentListError`
- `UnsupportedFeatureError`
- `MultipleDrawablesFoundError`
- `NoDrawablesFoundError`

## Display Service Requirements

For a display service to be compatible with Lacci, it must:
1. Implement the basic drawing primitives
2. Support parent-child relationships
3. Handle event propagation
4. Manage drawing contexts
5. Support style inheritance

## Testing

Lacci uses a comprehensive test suite with:
- Unit tests for helpers and utilities
- Integration tests for drawing operations
- Feature tests for end-to-end functionality
- Niente-based tests for display service compatibility

## Future Development

Areas for future enhancement include:
- Additional drawing primitives
- Enhanced animation support
- Improved error reporting
- Extended display service capabilities

## Contributing

When contributing to Lacci:
1. Ensure tests pass with Niente
2. Maintain backward compatibility
3. Follow the existing error handling patterns
4. Document new features and changes

## Related Components

- Scarpe: The main project
- Niente: The null display service for testing
- Display Services: Various backend implementations
