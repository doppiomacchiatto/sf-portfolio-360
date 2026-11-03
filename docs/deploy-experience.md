# Experience Deploy

`scripts/deploy-experience.sh` deploys the Experience Cloud metadata in `experiences/` to a target org. It's self-sufficient against a fresh scratch org or a partially-provisioned one — each step checks the target org's state and skips if already satisfied.

Usage: `./scripts/deploy-experience.sh [org-alias] [site-username]`
- `org-alias` defaults to `pm-scratch`
- `site-username` defaults to the target org's own username (via `sf org display user`)

## What it does

1. **VRM Administrator profile** — queries the target org for the `VRM Administrator` profile (referenced by the Network metadata's member list) and deploys it from `force-app/main/default/profiles/` if missing.
2. **Site admin placeholder** — detects the committed `changeme@domain` placeholder in `experiences/main/default/sites/titan.site-meta.xml` and runs `configure-site-username.sh` against the resolved site username.
3. **Experience Cloud site creation** — checks for an existing `Site`/`CustomSite` record; if none exists, runs `sf community create` (Build Your Own LWR template, `AUTHENTICATED`) and polls until the async job completes. A brand-new org has no Network/CustomSite yet, and a metadata deploy can't bootstrap them from nothing.
4. **Network name resolution** — queries for whatever Network name is actually bound to the site. `sf community create` names the Network after the site, which may not match the committed `networks/*.network-meta.xml` filename (e.g. committed file is `titanx`, but the org's Network is `titan`). Deploys the Network XML under the resolved name.
5. **Bundle + Config + CustomSite** — deploys the Experience Bundle, DigitalExperienceConfig, and CustomSite together in a final pass.

## Known issue fixed along the way

`experiences/main/default/sites/titan.site-meta.xml`'s `urlPathPrefix` was `titanxvforcesite`, while the Network's prefix was `titanx`. Salesforce requires a `ChatterNetwork` site and its Network to share the same URL path prefix — mismatched values fail deploy with:

```
The ChatterNetwork site and the corresponding Network must have the same URL path prefix.
```

Fixed by aligning the CustomSite's prefix to `titanx`.

## Verified

Full clean run against `pm-scratch`: 37/37 components deployed. Re-running against an already-deployed org correctly skips the profile, site-username, and site-creation steps (idempotent).
