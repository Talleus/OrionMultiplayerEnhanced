# Networking

The mod uses host-authoritative TCP; the default port is **27015/TCP**. Everyone should use the same release. This preview retains legacy wire protocol version `4` and wire compatibility label `0.4.5`; the public package version is `0.5.0-preview.1`.

Start with a trusted LAN/private VPN. The host must have a room running. Use the host's reachable IP: `127.0.0.1` only reaches the same computer; `0.0.0.0` is not a client destination. Keep firewall access scoped to the intended private network.

The project does not configure routers, provide a relay, or promise a hardened public server. Host-side command handling validates connection identity, roles, request size, and rate. That is not a full security audit.

`tools/mp_bot.py` is a local protocol test client. It joins, acknowledges world initialization, sends chat/typing, and requests commands. It has no graphical client or full simulation. Bot success alone does not prove real multiplayer rendering/gameplay.
