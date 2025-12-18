# Shoes and Display Events

This document covers how Scarpe handles events and display updates in relation to the original Shoes implementation.

## Event Handling

Scarpe implements event handling in a way that maintains compatibility with Shoes while providing modern features:

1. **Event Types**
   - Mouse events (click, hover, etc.)
   - Keyboard events
   - Window events
   - Custom events

2. **Event Flow**
   - Events are captured in the display service
   - Processed through the event loop
   - Dispatched to appropriate handlers

## Synchronous vs Asynchronous

Scarpe supports both synchronous and asynchronous event handling:

### Synchronous Events
- Direct user interactions
- Immediate UI updates
- Traditional Shoes-style callbacks

### Asynchronous Events
- Background operations
- Network requests
- Long-running computations

## Display Updates

Display updates in Scarpe follow a specific pattern:

1. State changes trigger update events
2. Updates are batched when possible
3. Changes are applied atomically
4. The display service reflects changes efficiently

## Compatibility Notes

While maintaining compatibility with Shoes, Scarpe introduces some modern improvements:

- Better event queueing
- More efficient update batching
- Enhanced error handling
- Improved async support
