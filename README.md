# claude-counter-menu-bar

A small native macOS menu-bar companion that displays Claude usage limits behind a lightweight robot icon. It leaves the official Claude Desktop application untouched, so Claude Code and Cowork retain their normal integrity checks.

> This is an unofficial companion and is not affiliated with or endorsed by Anthropic.

## Enterprise accounts

- Seat-based Enterprise organizations show every rolling quota returned by Claude, including session, weekly, model, OAuth-app, Design, and Cowork buckets.
- Metered Enterprise organizations may not have 5-hour or weekly allowances. When available, the app shows monthly spend versus the configured cap and a blocked state instead.
- The app tracks whichever organization is active in its Claude session. Use **Manage Claude Session…** to switch organizations, then select **Refresh**. Organization metadata is not displayed in the menu.
- SSO redirects are allowed inside the companion, but an organization's identity provider can prohibit embedded browsers. That policy is controlled by the enterprise administrator and cannot be bypassed by this app.

## Privacy

- Connects only to `https://claude.ai` through a persistent WebKit session.
- Does not read Claude Desktop files, browser cookies, conversations, prompts, uploads, or projects.
- Does not use an API key, analytics, Firebase, or third-party servers.
- Stores its Claude login in the standard persistent WebKit website data store. Use **Clear Companion Login** to remove it.

## Use

1. Launch **Claude Usage**.
2. Select its robot icon in the macOS menu bar.
3. Choose **Sign In with Email…**, enter the email address attached to your Claude account, and select **Continue with email**. Google OAuth may reject embedded app windows.
4. In the secure email, copy the login link address instead of opening it in your regular browser.
5. From the menu-bar app, choose **Open Login Link from Clipboard**. The link opens in the companion's own session.
6. Close the sign-in window. Usage refreshes automatically every minute.

Login links are sensitive and normally work once. If one has already been opened, request a fresh email before copying it.

## Build

Requirements: macOS 13 or newer, Apple Silicon, and Xcode Command Line Tools.

```sh
./build.sh
```

The ad-hoc signed application and distributable ZIP are written to `build/`.

## Releases

The repository includes a tag-driven GitHub Actions workflow that builds a DMG, generates a SHA-256 checksum, and publishes both to GitHub Releases. See [DISTRIBUTION.md](DISTRIBUTION.md) for unsigned testing and Apple Developer ID notarization setup.
