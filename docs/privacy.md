---
title: Harness Builder Privacy Policy
---

# Harness Builder Privacy Policy

Effective 25 November 2026

Harness Builder is an iPhone and iPad app for mapping wiring harnesses. This page explains what the app does with your information. The short version: your work stays on your device, there are no accounts, no ads and no tracking, and the only time anything leaves your device is when you choose to use the optional AI assistant with your own Anthropic key.

## What the app stores on your device

Your harnesses, plugs, pins, wire details, notes and settings are saved in the app's private storage on your device. This includes an unsaved-plug draft and a single undo point for the last assistant change. We do not receive any of it. We have no servers, no accounts and no analytics. Deleting the app deletes this data from your device.

If you export a PDF, PNG, SVG, CSV or backup file, or share it from the share sheet, that file goes wherever you send it. That is your choice and is not visible to us.

## The optional AI assistant

The assistant is off until you add your own Anthropic API key in Settings. Without a key, the app sends nothing anywhere.

When you have added a key and you send a message in the assistant:

- The app sends your message, the contents of the harness you have open (its plugs, pins, wire colors, functions, gauges, notes and connections), your recent messages in that conversation, and the names of plugs on your other harnesses to Anthropic's API at api.anthropic.com. Your other harnesses' pin details are not sent.
- The request uses your own key, so Anthropic bills your Anthropic account. We never see your key, your messages or the replies.
- Anthropic processes the request under its own terms and privacy policy: <https://www.anthropic.com/legal/privacy>. We do not control how Anthropic handles it.
- The assistant only proposes changes. Nothing changes in your harness until you review and apply it, and you can undo the last applied change.
- The conversation itself is kept only while the app is running and is not saved to your device.

The first time you send a message, the app asks you to confirm that you understand this.

## Your API key

Your key is stored in the iOS Keychain, on this device only. It is not synced to iCloud, not included in backups or exports, and never sent anywhere except to Anthropic when you use the assistant. You can replace or remove it at any time in Settings, under Build with AI. Because iOS can keep Keychain items after an app is deleted, please remove your key in Settings first if you plan to delete the app and want it gone.

## What we do not do

We do not collect personal information, track you across other apps or websites, show ads, sell or share data, or build profiles.

## Children

Harness Builder is a general-purpose tool and is not directed at children under 13.

## Changes

If this policy changes, the new version will be posted on this page with a new effective date.

## Contact

Questions about this policy: open an issue at <https://github.com/asherdowd/harness-builder/issues>.
