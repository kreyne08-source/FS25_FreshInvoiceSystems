# Fresh Invoice System - Debugging and Logging Guide

This document describes the logging and debugging capabilities added to the Fresh Invoice System mod.

## Overview

Comprehensive logging has been added throughout the Send Invoice flow to help diagnose issues and track the invoice creation process.

## Log Levels

The mod uses the FS25 `Logging` API with three levels:
- `Logging.info()` - Informational messages about normal operations
- `Logging.warning()` - Warning messages about potential issues
- `Logging.error()` - Error messages about failures

## Send Invoice Flow Logging

### 1. Opening Create Invoice Dialog

**Location:** `FIS_InGameMenuInvoices:onClickNewInvoice()`

```
[FIS] onClickNewInvoice called
[FIS] onClickNewInvoice: farmId=X
[FIS] onClickNewInvoice: setting callback and showing dialog
```

Warnings:
- `[FIS] onClickNewInvoice: farmId is nil or spectator` - Player is not in a valid farm
- `[FIS] onClickNewInvoice: no finance permission` - Player lacks permissions
- `[FIS] onClickNewInvoice: FIS_CreateInvoiceDialog not found in g_gui.guis` - Dialog initialization failed

### 2. Dialog Opens

**Location:** `FIS_CreateInvoiceDialog:onOpen()`

```
[FIS] CreateInvoiceDialog:onOpen() - callback set: true
[FIS] CreateInvoiceDialog:onOpen() - sendButton disabled: false
```

Warnings:
- `[FIS] CreateInvoiceDialog:onOpen() - sendButton is nil!` - UI element not initialized

### 3. Send Button Clicked

**Location:** `FIS_CreateInvoiceDialog:onClickSend()`

```
[FIS] onClickSend() called
[FIS] onClickSend: myFarm=X
[FIS] onClickSend: toFarmId=Y
[FIS] onClickSend: category=service
[FIS] onClickSend: desc=Test invoice description
[FIS] onClickSend: 2 line items
[FIS] onClickSend: total=1500.00
[FIS] onClickSend: calling callback function
```

Warnings/Errors:
- `[FIS] onClickSend: myFarm is nil` - Could not determine player's farm
- `[FIS] onClickSend: no finance permission for farm X` - Permission denied
- `[FIS] onClickSend: toFarmId is 0` - No recipient farm selected
- `[FIS] onClickSend: description is empty` - Missing description
- `[FIS] onClickSend: no line items` - No items in invoice
- `[FIS] onClickSend: total is 0` - Invoice total is zero
- `[FIS] onClickSend: callbackFunc is nil - callback was never set!` - Callback not registered

### 4. Callback Handler

**Location:** `FIS_InGameMenuInvoices:onInvoiceCreated()`

```
[FIS] onInvoiceCreated called: toFarmId=Y, category=service, desc=Test invoice, lineItems=2
[FIS] onInvoiceCreated: farmId=X
[FIS] onInvoiceCreated: calling g_fis_invoiceManager:createInvoice
```

Warnings/Errors:
- `[FIS] onInvoiceCreated: farmId is nil or spectator` - Invalid farm
- `[FIS] onInvoiceCreated: g_fis_invoiceManager is nil!` - Invoice manager not initialized

### 5. Invoice Manager

**Location:** `FIS_InvoiceManager:createInvoice()`

```
[FIS] createInvoice client->server event (if on client)
[FIS] createInvoice server from=X to=Y (if on server)
[FIS] invoice streamed in id=123 from=X to=Y amount=1500.00
```

### 6. Event Processing

**Location:** `FIS_CreateInvoiceEvent:run()`

```
[WARN] CreateInvoiceEvent rejected: invalid sender farmId=X
```

## Finding Logs

### In-Game Console
Logs appear in the game's console (F1 key by default in FS25).

### Log Files
Check the game's log file, typically located at:
- **Windows:** `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\log.txt`
- **Linux:** `~/.config/FarmingSimulator2025/log.txt`
- **Mac:** `~/Library/Application Support/FarmingSimulator2025/log.txt`

Search for `[FIS]` to find all mod-related messages.

## Debugging Common Issues

### Issue: Button does nothing when clicked
**Look for:** Missing `[FIS] onClickSend() called` message
**Cause:** Button click handler not registered or button profile issue
**Solution:** Check button XML configuration and profile definition

### Issue: Callback not called
**Look for:** `[FIS] onClickSend: callbackFunc is nil`
**Cause:** Dialog callback not set when opening
**Solution:** Verify `onClickNewInvoice()` calls `setCallback()` before `showDialog()`

### Issue: Invoice not created
**Look for:** Warnings in validation steps
**Cause:** Failed validation (permissions, empty fields, etc.)
**Solution:** Check specific warning message and address the validation issue

### Issue: Permission errors
**Look for:** `no finance permission` warnings
**Cause:** Player lacks farm management or finance permissions
**Solution:** Grant appropriate permissions in multiplayer settings

## Testing with Logs

When testing the Send Invoice feature:

1. Open the invoices menu - should see dialog opening log
2. Fill in invoice details
3. Click Send - should see complete flow logged:
   - `onClickSend()` called
   - All validation steps logged
   - Callback invoked
   - Invoice created on server
   - Invoice streamed to clients

Any missing log entry indicates where the flow broke.

## Disabling Logs (Not Recommended)

To reduce log verbosity (not recommended for debugging):
- Comment out specific `Logging.info()` calls in the source files
- Keep warning and error messages for troubleshooting

## Additional Debug Tools

The mod includes `FIS_Debug.lua` with a `FIS_Debug.log()` function for additional debug output. By default it's disabled. To enable:

```lua
FIS_Debug.enabled = true
```

## Contributing Debug Information

When reporting issues, please include:
1. Full log excerpt showing the Send Invoice flow
2. Game version (FS25)
3. Multiplayer or single player mode
4. Farm ID and permissions status
5. Steps to reproduce

This helps maintainers diagnose issues quickly.
