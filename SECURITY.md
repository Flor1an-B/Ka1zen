# Security Policy

## Supported versions

Only the latest released version of Ka1zen receives security fixes.

| Version | Supported |
|---|---|
| 0.3.x | ✅ |
| < 0.3 | ❌ |

## Reporting a vulnerability

If you believe you have found a security issue in Ka1zen — whether in the app itself, in the API Relay proxy, in the way documents are handled for RAG, or anywhere else — please report it **privately**.

**Do not open a public GitHub issue.** Instead:

📧 **florian.bertaux@gmail.com**

Please include:

- A clear description of the vulnerability and its impact.
- Reproduction steps (minimal if possible).
- The Ka1zen version (see **Ka1zen → About**) and your macOS version (`sw_vers -productVersion`).
- Any relevant log output, stack traces or proof-of-concept.

You will receive an acknowledgement within **72 hours**. I'll keep you informed as the fix progresses and credit you in the release notes once the patch ships, unless you prefer to remain anonymous.

## Scope

Ka1zen runs local inference and may expose an HTTP proxy on your machine. The following are in scope:

- Remote-code-execution, sandbox-escape or privilege-escalation issues in the app.
- Authentication bypasses in the API Relay server.
- Unintended data exfiltration (anything Ka1zen sends over the network that the user did not explicitly configure).
- Path-traversal or malicious-file issues in document ingestion / RAG.

Out of scope:

- Findings that require physical access to an unlocked Mac.
- Social-engineering vectors (e.g. tricking a user into running `xattr -cr`).
- Vulnerabilities in third-party dependencies that are already tracked upstream (MLX, mflux, GRDB, SwiftNIO…).
