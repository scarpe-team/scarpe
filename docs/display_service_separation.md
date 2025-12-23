---
layout: default
title: Display Service Separation
---

# Display Service Separation

The display service in Scarpe is separated from the main application to provide better isolation and flexibility. This design choice allows for:

1. Clear separation between the application logic and display logic
2. Ability to swap out display implementations
3. Better testing capabilities through isolation
4. Reduced coupling between components

## Architecture

The display service runs as a separate process from the main Scarpe application. Communication happens through a well-defined protocol that includes:

- Event messages for user interactions
- Display update commands
- State synchronization messages

## Benefits

This separation provides several key benefits:

1. **Security**: The display service can run with different permissions
2. **Stability**: Issues in the display layer won't crash the main application
3. **Flexibility**: Different display implementations can be used without changing the core application
4. **Testing**: Components can be tested in isolation

## Implementation Details

The display service communicates with the main application through a message-passing interface. This allows for:

- Asynchronous updates
- Clean separation of concerns
- Easy testing and mocking
- Future extensibility
