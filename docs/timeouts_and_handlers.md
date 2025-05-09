# Timeouts and Handlers

This document explains how Scarpe manages timeouts and event handlers within its cooperative evented approach.

## Timeout Management

Scarpe implements timeouts with these key considerations:

1. **Cooperative Nature**
   - Timeouts don't interrupt execution
   - They're processed when the event loop is ready
   - Timing is approximate, not exact

2. **Implementation**
```ruby
def after(milliseconds, &block)
  register_timeout(Time.now + (milliseconds / 1000.0), block)
end
```

## Event Handlers

Event handlers in Scarpe follow these principles:

1. **Registration**
   - Handlers are registered with specific events
   - Multiple handlers can exist per event
   - Order of execution is preserved

2. **Execution**
   - Handlers run in the main event loop
   - They should be non-blocking when possible
   - Long operations should be broken up

## Restrictions

The cooperative approach has some important restrictions:

1. **No Preemption**
   - Long-running handlers block other events
   - Timeouts may be delayed
   - UI updates wait for handlers to complete

2. **Best Practices**
   - Keep handlers short
   - Use async for long operations
   - Break up complex tasks

## Error Handling

Handlers include error management:

1. **Exception Catching**
   - Errors don't crash the event loop
   - Exceptions are logged appropriately
   - Error handlers can be registered

2. **Recovery**
   - System can recover from handler errors
   - State remains consistent
   - Other handlers continue to work
