# Dashboard auth — Caddy + htpasswd recipe

Scope: Kozuma Lab (10 people or fewer). HTTP Basic auth in front of the
dashboard via Caddy is the right granularity for this size — cheap to
set up, identity flows into `enqueued_by` provenance, no SSO machinery.

Upgrade path (when Lab grows or SSO is preferred): GitHub OAuth via
`oauth2-proxy` slots in front of Caddy without touching the dashboard
itself.

## Why now

The dashboard was read-only until the Web UI enqueue / promote / cancel
endpoints landed. Those endpoints mutate filesystem state and can submit
GPU jobs. Past this point, "LAN binding + no auth" is not sufficient
anymore — any host on the LAN can enqueue.

The dashboard backend itself does NOT validate credentials. The Caddy
front-end enforces auth, then forwards the authenticated username via a
header that the dashboard reads into `enqueued_by`.

## Caddy v2 — `/etc/caddy/Caddyfile`

```caddyfile
suzume.lan {
    # Bcrypt-hashed passwords; generate with:
    #   caddy hash-password --plaintext '<password>'
    # or
    #   htpasswd -nbB anko '<password>'      # outputs `anko:$2y$...`
    basicauth /* {
        anko       $2a$14$REPLACE_WITH_HASH
        member_b   $2a$14$REPLACE_WITH_HASH
        member_c   $2a$14$REPLACE_WITH_HASH
    }

    # Reverse to the dashboard. In production (post `bun run build`)
    # Caddy proxies directly to Julia on :8090. In dev mode, target
    # Vite on :9876 — both behave the same as far as the upstream
    # header is concerned.
    reverse_proxy localhost:8090 {
        header_up X-Authenticated-User {http.auth.user.id}
    }

    tls internal     # Caddy's local CA; or `tls anko@example.com` for ACME
}
```

The load-bearing line is `header_up X-Authenticated-User {http.auth.user.id}` —
without it, Caddy strips Basic auth before forwarding and the dashboard
sees no identity. Falls back to `dashboard:<session_id>` in that case
(harmless but uninformative).

## Where the username shows up

After Caddy is in place, every Web UI mutation records the operator:

```toml
# runs/<cid>/state.toml
[provenance]
enqueued_by = "anko"            # not "dashboard:abc12345"
```

```
# runs/<cid>/.reason or state.toml
kill_reason = "cancelled by operator (anko)"
```

The autopilot's `why <cid>` CLI surface and the queue panel both show
this naturally — no further wiring needed.

## Generating htpasswd entries

```bash
# One-off for each member
caddy hash-password --plaintext 'their-password' --algorithm bcrypt

# Or via Apache htpasswd (same bcrypt scheme)
htpasswd -nbB anko 'their-password'
```

Copy the resulting bcrypt hash into the Caddyfile under `basicauth`.

Password rotation is the operator's call. For a lab of ~10 the
overhead is low; just re-issue and re-deploy.

## Verifying the chain

```bash
# 1. Direct (no auth, no header) — provenance falls back to session_id
curl -s -X POST \
  http://10.255.255.254:8090/api/queue/enqueue \
  -H 'Content-Type: application/json' \
  -d '{"preview":true,"yaml":"..."}'

# 2. Through Caddy with Basic auth — provenance = username
curl -s -X POST \
  https://suzume.lan/api/queue/enqueue \
  -u anko:<password> \
  -H 'Content-Type: application/json' \
  -d '{"preview":true,"yaml":"..."}'
# After commit: state.toml.provenance.enqueued_by = "anko"
```

The 2nd curl is the production path; the 1st should be blocked at the
LAN boundary (firewall + bind-to-localhost-only) once Caddy is live.

## Trust model — explicit

- The dashboard trusts the `X-Authenticated-User` header **only** when
  upstream is your Caddy. There is no signature check.
- Direct access to `:8090` bypasses Caddy and bypasses auth. Therefore
  once Caddy is in front, the Julia backend must NOT listen on the
  public interface.

### Locking the backend to loopback

`serve_dashboard` accepts a `bind` kwarg (or `SPINORBEC_DASHBOARD_BIND`
env override). Default is `"0.0.0.0"` (preserves dev workflow). For
production behind Caddy:

```bash
# Either kwarg form (interactive / scripts)
julia --project=. -e 'using SpinorBEC; serve_dashboard(8090; bind="127.0.0.1")'

# Or env form (systemd unit / cron)
SPINORBEC_DASHBOARD_BIND=127.0.0.1 \
  julia --project=. -e 'using SpinorBEC; serve_dashboard(8090)'
```

After this, `ss -tln` shows `127.0.0.1:8090` (not `0.0.0.0:*`) and any
non-Caddy attempt to reach the port is refused at the socket layer.

## Upgrade trigger → GitHub OAuth via oauth2-proxy

Swap `basicauth` for `oauth2-proxy` in front of Caddy when any of:

- the lab exceeds ~10 active members and password rotation is annoying,
- guest accounts (e.g. visiting collaborators) need short-lived access,
- audit beyond `enqueued_by` is desired (oauth2-proxy emits structured
  access logs with GitHub username + IP per request).

**The dashboard-side code does not change** — `oauth2-proxy` sets the
same `X-Forwarded-User` header (the dashboard already accepts
`X-Authenticated-User` / `X-Forwarded-User` / `Remote-User`
interchangeably).

### 1. GitHub OAuth app

Create at
<https://github.com/settings/applications/new>:

  - Application name: `Kozuma Lab dashboard`
  - Homepage URL: `https://suzume.lan/`
  - Authorization callback URL:
    `https://suzume.lan/oauth2/callback`

Note the Client ID + Client Secret.

### 2. oauth2-proxy systemd unit

`/etc/oauth2-proxy/oauth2-proxy.cfg`:

```
provider = "github"
client_id     = "<github_client_id>"
client_secret = "<github_client_secret>"

# Restrict access — only these GitHub usernames may sign in.
github_users  = ["anko", "member_b", "member_c"]
# Alternative: github_org / github_team for whole-org access.

cookie_secret = "<32-byte-random>"   # `openssl rand -base64 32`
cookie_domains = ["suzume.lan"]
cookie_secure  = true

# Listen on localhost; Caddy reverse-proxies to this port.
http_address  = "127.0.0.1:4180"
reverse_proxy = true

# Forward identity to upstream as a header.
set_xauthrequest = true
pass_user_headers = true
pass_access_token = false
email_domains = ["*"]                # required even with github_users
upstreams     = ["http://127.0.0.1:8090"]
```

`/etc/systemd/system/oauth2-proxy.service`:

```ini
[Unit]
Description=oauth2-proxy in front of dashboard
After=network.target

[Service]
ExecStart=/usr/bin/oauth2-proxy --config=/etc/oauth2-proxy/oauth2-proxy.cfg
Restart=on-failure
User=oauth2-proxy

[Install]
WantedBy=multi-user.target
```

### 3. Caddyfile — replace `basicauth` block

```caddyfile
suzume.lan {
    # oauth2-proxy handles the /oauth2/* routes itself.
    handle /oauth2/* {
        reverse_proxy localhost:4180
    }

    # Everything else: require auth via forward_auth.
    handle {
        forward_auth localhost:4180 {
            uri /oauth2/auth
            copy_headers X-Auth-Request-User>X-Authenticated-User
        }
        reverse_proxy localhost:8090 {
            header_up X-Authenticated-User {http.reverse_proxy.header.X-Authenticated-User}
        }
    }

    tls internal
}
```

The `copy_headers` line is the bridge: oauth2-proxy emits
`X-Auth-Request-User` (its native header), Caddy renames it to
`X-Authenticated-User` (the name the dashboard reads). Switching from
Basic auth to OAuth is therefore one Caddy reload — no Julia change.

### 4. Verifying the OAuth chain

```bash
# Browser flow:
#   1. visit https://suzume.lan/ → redirected to GitHub
#   2. authorize → callback → back to dashboard
#   3. enqueue from Sheet 06 → state.toml.enqueued_by = "<github-username>"

# Programmatic flow uses a long-lived oauth2-proxy cookie or PAT;
# document the chosen method when this is rolled out.
```

## Pitfalls

- **Vite dev mode**: Vite's reverse-proxy by default forwards request
  headers, so the dev URL (`:9876`) behind Caddy works the same way as
  production. If you see `enqueued_by = "dashboard:..."` despite Caddy
  being in front, check Vite's proxy config didn't strip headers.
- **Stale browser auth cache**: changing the htpasswd file requires
  closing the browser tab (or visiting `https://logout@suzume.lan/`).
- **Caddy reloads**: `caddy reload` after editing the Caddyfile;
  `caddy fmt --overwrite /etc/caddy/Caddyfile` to validate syntax.
