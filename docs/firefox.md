# Firefox

The kit may install a sanitized `user.js` and optional extension policy.

It must not copy:

- profiles
- cookies
- passwords
- history
- Sync state
- extension storage
- account files

Extension policies should use public extension IDs and should remain removable by the user unless there is a clear reason otherwise.
