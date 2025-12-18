# Event Loops

Scarpe's event loop system is a core part of its architecture, handling both UI events and application logic.

## Main Event Loop

The main event loop is responsible for:

1. Processing user input
2. Handling timer events
3. Managing display updates
4. Coordinating between components

## Implementation Details

The event loop is implemented with these key features:

### Event Queue
- Events are queued in order of arrival
- Priority system for critical events
- Efficient processing of batched events

### Handler Registration
```ruby
class EventLoop
  def register_handler(event_type, &block)
    handlers[event_type] << block
  end
end
```

### Event Processing
- Events are processed in a single thread
- Non-blocking operations where possible
- Careful handling of long-running tasks

## Cooperative Multitasking

Scarpe uses cooperative multitasking where:

1. Tasks yield control voluntarily
2. Long operations are broken into smaller chunks
3. The event loop maintains responsiveness

## Best Practices

When working with the event loop:

1. Keep handlers fast and focused
2. Avoid blocking operations
3. Use async operations for long-running tasks
4. Handle errors appropriately

## Integration with Display Service

The event loop coordinates closely with the display service:

- Synchronizes state updates
- Manages display refresh timing
- Handles animation frames
- Coordinates user input
