# Advanced FPS Blocker

**Advanced FPS Blocker** is an AMX Mod X plugin designed for Counter-Strike 1.6 Hide and Seek (HNS) servers. It monitors client FPS-related settings and attempts to enforce server-defined limits.

### Features

- **FPS Limiter** — Monitors `fps_max` and attempts to set it to `100` when the value exceeds the configured limit or is set to `0`.
- **Developer Check** — Monitors the `developer` cvar and attempts to enforce `developer 0`.
- **Client Command Verification** — Uses a `setinfo` challenge to check whether clients accept server-issued commands.
- **Map Change Protection** — Delays checks for 15 seconds after a map change.
- **Connection Protection** — Provides a grace period for newly connected players.
- **Anti-Flood Protection** — Uses configurable check intervals to reduce server load and prevent message spam.
- **CromChat Integration** — Displays colored notifications when invalid settings are detected.
- **Optional Automatic Kick** — Can kick players after repeated failed client command verification attempts.
- **Steam & Non-Steam Support** — Does not require a valid SteamID.
- **Configurable Settings** — Supports CVAR configuration through `advanced_fps_blocker.cfg`.
