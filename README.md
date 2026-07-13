# claude-counter-menu-bar

A small native macOS menu-bar companion that displays Claude usage limits behind a lightweight robot icon. It leaves the official Claude Desktop application untouched, so Claude Code and Cowork retain their normal integrity checks.

Each available limit includes a compact live countdown, for example `5-hour: 12% · resets in 2h 18m`. Hovering the row shows the absolute local reset date and time.

> This is an unofficial companion and is not affiliated with or endorsed by Anthropic.

## Enterprise accounts

- Seat-based Enterprise organizations show every rolling quota returned by Claude, including session, weekly, model, OAuth-app, Design, and Cowork buckets.
- Metered Enterprise organizations may not have 5-hour or weekly allowances. When available, the app shows monthly spend versus the configured cap and a blocked state instead.
- The app tracks whichever organization is active in its Claude session. Use **Manage Claude Session…** to switch organizations, then select **Refresh**. Organization metadata is not displayed in the menu.
- Use **Enterprise SSO…**, enter the work email at Claude's login page, and choose **Continue with SSO**. Identity-provider popup windows share the companion's isolated WebKit session. An organization's IdP can still prohibit embedded browsers; that policy is controlled by the enterprise administrator and cannot be bypassed by this app.

## Privacy

- Connects only to `https://claude.ai` through a persistent WebKit session.
- Does not read Claude Desktop files, browser cookies, conversations, prompts, uploads, or projects.
- Does not use an API key, analytics, Firebase, or third-party servers.
- Stores its Claude login in the standard persistent WebKit website data store. Use **Clear Companion Login** to remove it.

## Use

1. Launch **Claude Usage**.
2. Select its robot icon in the macOS menu bar.
3. Personal account: choose **Sign In to Claude…** and continue with email.
4. Enterprise account: choose **Enterprise SSO…**, enter your work email, and select **Continue with SSO**. No magic-link email is required when SSO is enforced.
5. Personal email fallback: copy the secure login link address and choose **Open Email Login Link from Clipboard** so it opens in the companion's session.
6. Complete any identity-provider popup. The sign-in windows close after usage is loaded, and usage refreshes automatically every minute.

Login links are sensitive and normally work once. If one has already been opened, request a fresh email before copying it.

## Build

Requirements: macOS 13 or newer, Apple Silicon, and Xcode Command Line Tools.

```sh
./build.sh
```

The ad-hoc signed application and distributable ZIP are written to `build/`.

## Releases

The repository includes a tag-driven GitHub Actions workflow that builds a DMG, generates a SHA-256 checksum, and publishes both to GitHub Releases. See [DISTRIBUTION.md](DISTRIBUTION.md) for unsigned testing and Apple Developer ID notarization setup.
