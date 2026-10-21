# PhantOS Privacy Policy

Last updated: October 21, 2026

PhantOS does not collect, store or share any personal data. It has no accounts, no analytics, no advertising and no tracking, and it sends nothing to its developer.

## What stays on your device

Everything you do in PhantOS stays on your iPhone or iPad: the Linux filesystem, your files, your shell history and your settings. Deleting the app deletes all of it.

## Network access

PhantOS connects to the internet only when you run a program that does, such as `apk add` to install packages or `curl` and `ssh`. Those connections go wherever you point them, for example Alpine Linux's package servers. Their own privacy policies apply to them.

## Location

iOS asks for permission before PhantOS can use your location. It is only read when a program you run opens `/dev/location`, and it is never sent anywhere by PhantOS itself. You can turn it off at any time in Settings.

## Local network

iOS asks for permission before PhantOS can reach devices on your local network, which commands such as `ping` and connections to `localhost` need.

## Clipboard

PhantOS reads or writes the clipboard only when you paste, or when a program you run uses `/dev/clipboard`.

## Contact

Questions about this policy: [open an issue](https://github.com/giossaurus/phantos/issues) on GitHub.
