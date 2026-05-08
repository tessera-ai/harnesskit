# Security Policy

HarnessKit processes sensitive health data on-device. We take security seriously.

## Scope

This policy covers the HarnessKit SDK (`packages/HarnessKit/`), the Forge demo app (`apps/Forge/`), and the dashboard (`apps/dashboard/`).

## Reporting a vulnerability

**Do not file a public issue or pull request for security vulnerabilities.**

Instead, report privately:

1. Open a GitHub Security Advisory via **Security > Report a vulnerability** on the repository.
2. Include:
   - A description of the vulnerability
   - Steps to reproduce
   - Affected versions/commit range
   - Potential impact (data exposure, privilege escalation, etc.)

We will acknowledge your report within **48 hours** and aim to provide a substantive response within **5 business days**.

## What to report

We are especially interested in:

- Any path where user health data (HealthKit metrics, workout data) could leave the device unintentionally
- Cloud fallback leakage — cases where data is sent to cloud providers that should remain on-device
- Permission bypass — circumventing HealthKit authorization
- Trace data exposure — structured traces containing PII

## Disclosure policy

- We follow **coordinated disclosure**.
- We will not publicly disclose a vulnerability until a fix is available.
- We request that reporters allow us **90 days** to address the issue before public disclosure.
- We will credit reporters in the advisory unless they request anonymity.

## Security architecture

- User health data is processed on-device via Apple Foundation Models. It is never stored server-side.
- Cloud fallback sends only the **prompt** and **model configuration** — never raw health data. Verify this invariant holds when modifying the fallback path.
- The SDK is designed to be compliant with App Store guideline 5.1.3(i) by construction. Changes that introduce server-side health data storage or processing violate this invariant.

## Supported versions

| Version | Supported |
|---|---|
| `main` branch | Yes |
| Pre-release tags | Best effort |

This project has not yet made a stable release. Security support applies to the `main` branch only.
