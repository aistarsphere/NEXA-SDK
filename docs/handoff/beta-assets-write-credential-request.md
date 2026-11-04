# Request: narrowly scoped Beta `assets:write` credential

Status: **ready to send, not sent.** Use the existing secure provisioning process. **Never paste a key into chat, logs, commits or screenshots.**

## What and why
Photo, file and camera tools upload a file with `POST /nexa/api/v1/sdk/conversations/{id}/assets`. With the current dev credential this returns **403** (no `assets:write`; known since 2026-10-28). Everything up to the picker works on the Nubia; the upload step cannot be verified.

## Scope requested
* Application: the Beta mobile app id only (the same one in the local secrets file).
* Capability: `assets:write` (uploads to the caller's own conversations) and, if separate, read of those assets. **Nothing else**: no `tools:use` widening, no admin, no other applications, no production data access.
* Lifetime: short (days). Revoke after the verification below.
* Environment: Beta/dev gateway, not production tenants.

## Delivery
Through the existing provisioning process to the owner. The owner places it in the local secrets file only (`~/.nexa/nexa_dev.json`, loaded with `--dart-define-from-file`); it is never committed, logged, echoed or pasted. The app does not accept a key typed into the UI.

## Verification (what we will do with it)
1. Upload one small PNG (< 1 MB) from the photo tool: expect `201` and an `asset_id`; the agent describes the image.
2. Upload one small text file: expect `201`.
3. Confirm 403 for an unrelated scope is unchanged (no widening).
4. Report results; owner/AWS revokes the credential.

No production configuration or server behaviour change is requested.
