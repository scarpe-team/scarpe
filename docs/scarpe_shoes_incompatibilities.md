# Scarpe/Shoes Incompatibilities

This document outlines the known incompatibilities between Scarpe and the original Shoes implementation.

## API Differences

1. **Method Names**
   - Some methods have been renamed for clarity
   - Deprecated Shoes methods are not supported
   - New methods added for modern features

2. **Parameters**
   - Some parameter orders have changed
   - Additional options are available
   - Some legacy options are not supported

## Behavioral Changes

Key behavioral differences include:

1. **Event Handling**
   - More consistent event model
   - Better async support
   - Different timing guarantees

2. **Layout System**
   - More predictable layout behavior
   - Enhanced flexibility
   - Some legacy layouts may render differently

## Unsupported Features

Some Shoes features are not supported in Scarpe:

1. **Legacy Components**
   - Certain deprecated widgets
   - Old animation system
   - Legacy drawing methods

2. **Platform-Specific Features**
   - Some OS-specific capabilities
   - Direct hardware access
   - Legacy system integration

## Modernization Changes

Intentional changes for modern development:

1. **Architecture**
   - Separate display service
   - Modern component model
   - Enhanced state management

2. **Development Experience**
   - Better debugging tools
   - Modern testing support
   - Improved error messages

## Migration Guide

When moving from Shoes to Scarpe:

1. Review API changes
2. Update event handlers
3. Test layouts thoroughly
4. Use modern alternatives for legacy features
