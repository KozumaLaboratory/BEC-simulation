# Dashboard auth

Scope: Kozuma Lab @ Science Tokyo (isct.ac.jp Google Workspace).

**Recommended: Google Workspace OAuth** with the `hd=isct.ac.jp`
parameter. Provider-side enforcement of the institutional domain
collapses "lab membership" to "valid isct.ac.jp Google account" — no
allow-list to maintain, no password handling, automatic lifecycle
tracking, provenance is the user's institutional email.

**Fallback: Caddy + htpasswd Basic auth.** Documented below for sites
without Google Workspace, or as a transient setup while the OAuth app
is being approved. Same dashboard-side wiring works for both.

The dashboard-side code does NOT validate credentials. The front-end
proxy (Caddy + oauth2-proxy, or Caddy alone) enforces auth, then
forwards the authenticated identity via a header the dashboard reads
into `enqueued_by`.

## Why now

The dashboard was read-only until the Web UI enqueue / promote / cancel
endpoints landed. Those endpoints mutate filesystem state and can submit
GPU jobs. Past this point, "LAN binding + no auth" is not sufficient
anymore — any host on the LAN can enqueue.

## Recommended: Google Workspace OAuth (hd=isct.ac.jp)

Two layers of domain restriction (defense in depth):

1. **Provider-side**: pass `hd=isct.ac.jp` to the Google authorization
   URL. Google's consent screen refuses any sign-in from outside the
   isct.ac.jp Workspace tenant — `gmail.com` and other domains never
   reach the redirect.
2. **Proxy-side**: oauth2-proxy `--email-domain=isct.ac.jp` re-verifies
   the token's email after callback. Redundant when (1) is honored but
   cheap and catches misconfiguration.

### 1. Google Cloud Console — OAuth 2.0 Client

- Create / pick a Google Cloud project under your institutional account.
- APIs & Services → Credentials → **Create credentials → OAuth client ID**.
- Application type: **Web application**.
- Authorized redirect URI: `https://suzume.lan/oauth2/callback`.
- Note the **Client ID** and **Client secret**.

If the OAuth consent screen is set to "Internal" (Workspace-scoped),
the `hd` enforcement is implicit. "External" mode requires the explicit
`hd=` parameter on every auth request — set it via oauth2-proxy below.

### 2. oauth2-proxy config

`/etc/oauth2-proxy/oauth2-proxy.cfg`:

```
provider                = "google"
client_id               = "<google_client_id>"
client_secret           = "<google_client_secret>"

# Two-layer domain enforcement:
email_domains           = ["isct.ac.jp"]   # post-callback verification
# `hd` is sent automatically when the consent screen is "Internal".
# For "External" consent, pin it explicitly:
google_admin_email      = ""               # leave empty for hd-only enforcement
# Some oauth2-proxy versions accept `--google-target-aud`; the
# canonical knob is the consent-screen tenancy setting above.

cookie_secret           = "<32-byte-base64>"   # openssl rand -base64 32
cookie_domains          = ["suzume.lan"]
cookie_secure           = true

http_address            = "127.0.0.1:4180"
reverse_proxy           = true

# Forward identity to upstream. X-Auth-Request-Email gives the full
# isct.ac.jp address; the dashboard reads it as enqueued_by.
set_xauthrequest        = true
pass_user_headers       = true
pass_access_token       = false

upstreams               = ["http://127.0.0.1:8090"]
```

systemd unit `/etc/systemd/system/oauth2-proxy.service`:

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

### 3. Caddyfile

```caddyfile
suzume.lan {
    # oauth2-proxy's own routes.
    handle /oauth2/* {
        reverse_proxy localhost:4180
    }

    # Everything else: require auth via forward_auth, then proxy.
    handle {
        forward_auth localhost:4180 {
            uri /oauth2/auth
            # oauth2-proxy emits X-Auth-Request-Email and X-Auth-Request-User
            # on the auth response; copy them to the upstream request.
            copy_headers X-Auth-Request-Email X-Auth-Request-User
        }
        reverse_proxy localhost:8090
    }

    tls internal
}
```

The dashboard accepts `X-Auth-Request-Email` with top priority, so
`enqueued_by` becomes the institutional address (`anko@isct.ac.jp`) —
the most natural identity for `autopilot why <cid>` to surface.

### 4. TLS — mkcert for `suzume.lan`

Google requires HTTPS on the redirect URI; `http://localhost` is the
only exception and won't work for `suzume.lan`. Caddy's `tls internal`
issues a cert from a local CA, which browsers warn about by default —
fix once per device with mkcert:

```bash
# On suzume (run once)
sudo apt install mkcert libnss3-tools          # or: brew install mkcert nss
mkcert -install                                  # installs the local CA

# Copy mkcert's root CA to each lab device that needs to reach the
# dashboard, then run `mkcert -install` there too. Browsers then trust
# `tls internal` certs without warning.
```

Alternative: use Caddy's automatic Let's Encrypt issuance if `suzume.lan`
resolves publicly — but for an internal hostname, mkcert is simpler and
the certs don't expire (mkcert default is 10 years).

### 5. Verifying the full chain

```bash
# Browser flow:
#   1. visit https://suzume.lan/ → redirected to accounts.google.com
#   2. Workspace consent screen (only isct.ac.jp accounts pass)
#   3. callback → back to dashboard
#   4. enqueue from Sheet 06 → state.toml.enqueued_by = "anko@isct.ac.jp"

# Programmatic: oauth2-proxy supports cookie-based session reuse for
# scripts run from a browser-authenticated environment. For headless
# CI / cron, use Caddy basicauth on a separate /api/admin/* path or
# bind to localhost-only and call directly.
```

### When to skip Google Workspace OAuth

- Science Tokyo isn't using Google Workspace (verify before deploying)
- Need to grant access to people without isct.ac.jp accounts (visiting
  collaborators on personal Gmail / GitHub) → fall through to the
  Basic auth recipe below for those guest accounts on a separate
  hostname, or add their personal addresses to `email_domains`

## Fallback: Caddy + htpasswd Basic auth

For sites without Google Workspace, or as a one-hour transient setup
while the OAuth client is being approved. Identity flows the same way:
Caddy basicauth username → `X-Authenticated-User` → dashboard's
`enqueued_by`.

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

## Alternative provider: GitHub OAuth

If Google Workspace is unavailable but lab members all have GitHub
accounts, swap the oauth2-proxy provider:

```
provider      = "github"
github_users  = ["anko-handle", "member_b-handle", ...]
client_id     = "<github_client_id>"
client_secret = "<github_client_secret>"
```

Caddyfile and dashboard wiring are identical. `X-Auth-Request-User`
carries the GitHub username; `enqueued_by` becomes `<github-handle>`
(no email suffix, since GitHub OAuth doesn't surface a verified email
by default). The institutional-domain assertion (Google's `hd`) is
lost — replace it with the explicit `github_users` allow-list.

Pros over Google: works without an institutional Workspace. Cons:
allow-list to maintain by hand; identity is "GitHub handle" not
"institutional email", which is less natural for `autopilot why` audit
trails.

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
