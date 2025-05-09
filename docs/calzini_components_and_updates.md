# Calzini Components and Updates

Calzini is Scarpe's component system, providing a modern approach to UI components while maintaining Shoes compatibility.

## Component Structure

Components in Calzini follow this structure:

1. **Base Components**
   - Built-in widgets (Button, EditLine, etc.)
   - Layout components (Stack, Flow)
   - Custom components

2. **Component Lifecycle**
```ruby
class CalziniComponent
  def initialize
    setup_state
    register_handlers
  end

  def update
    calculate_layout
    trigger_display_update
  end
end
```

## State Management

Components manage state through:

1. **Internal State**
   - Local component state
   - Cached calculations
   - Temporary values

2. **External State**
   - Props from parent components
   - Global application state
   - Shared resources

## Update Mechanism

Updates in Calzini happen through:

1. **Change Detection**
   - State changes trigger updates
   - Props changes propagate
   - Layout changes cascade

2. **Update Process**
   - Changes are batched
   - Updates are scheduled
   - Display is refreshed efficiently

## Best Practices

When working with Calzini components:

1. Keep components focused and small
2. Use proper state management
3. Optimize update triggers
4. Handle errors gracefully

## Shoes Compatibility

Calzini maintains compatibility with Shoes:

- Similar API structure
- Familiar component names
- Compatible event handling
- Consistent behavior
