# App Store Connect: PhantOS 1.0.0

Field by field, in the order App Store Connect asks. Store text is given in English (U.S.) and Portuguese (Brazil).

## 1. New app

| Field | Value |
| --- | --- |
| Platforms | iOS |
| Name | PhantOS |
| Primary language | English (U.S.) |
| Bundle ID | com.giossaurus.phantos |
| SKU | phantos |
| User access | Full access |

The bundle ID appears in the list after Xcode registers it: open `PhantOS.xcodeproj`, check that your team is selected under Signing & Capabilities for the `PhantOS` and `PhantOSFileProvider` targets, and build once for a device.

## 2. App information

| Field | Value |
| --- | --- |
| Subtitle (en) | Linux shell for iPhone & iPad |
| Subtitle (pt-BR) | Shell Linux no iPhone e iPad |
| Primary category | Developer Tools |
| Secondary category | Utilities |
| Content rights | Yes, it contains third-party content (open-source software from Alpine Linux, installed by the user), and you have the rights to use it under their open-source licenses |
| Age rating | See section 5 |

## 3. Pricing and availability

Free, all countries. Nothing else is required.

## 4. App privacy

| Field | Value |
| --- | --- |
| Privacy policy URL | https://github.com/giossaurus/phantos/blob/master/PRIVACY.md |
| Data collection | No, we do not collect data from this app |

The privacy and support pages exist on `master` only after the PhantOS pull request is merged. Merge it before you submit.

## 5. Age rating

Answer the questionnaire truthfully. PhantOS has no violence, sexual content, gambling, contests, messaging, user profiles or ads. The one question that needs thought is web access: PhantOS has no web browser, but programs a user installs (`curl`, `lynx`) can download anything from the internet. Apple treats unrestricted web access as a reason for an 18+ rating. Answering "No" is defensible for a terminal without a browser; answering "Yes" is the safe choice if you would rather not argue it in review.

## 6. Version 1.0.0

| Field | Value |
| --- | --- |
| Support URL | https://github.com/giossaurus/phantos/blob/master/SUPPORT.md |
| Marketing URL | https://github.com/giossaurus/phantos |
| Copyright | 2026 Giovanni Lopes Oliveira Castro Della Dea |
| Version | 1.0.0 |

### Promotional text

**en**

A real Linux shell in your pocket: zsh, Neovim and thousands of Alpine packages, in a terminal with tabs and Liquid Glass.

**pt-BR**

Um shell Linux de verdade no bolso: zsh, Neovim e milhares de pacotes do Alpine, num terminal com abas e Liquid Glass.

### Description

**en**

PhantOS runs Alpine Linux on your iPhone and iPad. Install software with apk, write code in Neovim, use git and ssh, run Python scripts, all on device, without a server.

THE TERMINAL
• Sharp, fast text from the Ghostty terminal engine
• Tabs, each with its own shell. Tap + to open one, hold a tab to rename or close it
• Liquid Glass tabs and extra keys: Tab, Control, Escape and arrows above the keyboard
• Hardware keyboard shortcuts: ⌘T, ⌘W, ⌘1 to ⌘9

THE SHELL
• zsh with Oh My Zsh and Powerlevel10k, set up to start fast
• Neovim as the editor, with yank and paste through the iOS clipboard
• Alpine Linux packages with apk: Python, Node.js, git, gcc, ssh and more

MAKE IT YOURS
• Themes: PhantOS, Dracula, Catppuccin, Cursor Dark and more, in light and dark
• Choose any monospaced font and size
• Your files show up in the Files app

PhantOS emulates an x86 processor, so programs run slower than on a computer. It is free and open source under the GPLv3, based on iSH. Source code: github.com/giossaurus/phantos

**pt-BR**

O PhantOS roda o Alpine Linux no seu iPhone e iPad. Instale programas com o apk, escreva código no Neovim, use git e ssh, rode scripts Python, tudo no aparelho, sem servidor.

O TERMINAL
• Texto nítido e rápido, com o motor de terminal do Ghostty
• Abas, cada uma com seu próprio shell. Toque em + para abrir, segure uma aba para renomear ou fechar
• Abas e teclas extras em Liquid Glass: Tab, Control, Escape e setas acima do teclado
• Atalhos de teclado físico: ⌘T, ⌘W, ⌘1 a ⌘9

O SHELL
• zsh com Oh My Zsh e Powerlevel10k, configurado para abrir rápido
• Neovim como editor, copiando e colando pela área de transferência do iOS
• Pacotes do Alpine Linux com o apk: Python, Node.js, git, gcc, ssh e muito mais

DO SEU JEITO
• Temas: PhantOS, Dracula, Catppuccin, Cursor Dark e outros, no claro e no escuro
• Qualquer fonte monoespaçada, em qualquer tamanho
• Seus arquivos aparecem no app Arquivos

O PhantOS emula um processador x86, então os programas rodam mais devagar que num computador. É livre e de código aberto, sob a GPLv3, baseado no iSH. Código-fonte: github.com/giossaurus/phantos

### Keywords

**en:** `terminal,linux,shell,ssh,zsh,alpine,neovim,vim,command line,unix,bash,git,python,cli,tabs`

**pt-BR:** `terminal,linux,shell,ssh,zsh,alpine,neovim,vim,linha de comando,unix,bash,git,python,abas`

Other apps' names (Ghostty, iSH, Termius) stay out of the keywords: guideline 2.3.7 rejects them.

### Screenshots

The app runs on iPhone and iPad, so App Store Connect asks for both:

| Device | Size (portrait) | How many |
| --- | --- | --- |
| iPhone 6.9" | 1320 × 2868 | 3 to 10 |
| iPad 13" | 2064 × 2752 | 3 to 10 |

The iPhone 17 Pro Max and iPhone 18 Pro Max simulators produce the iPhone size, and the iPad Pro 13-inch (M5) simulator produces the iPad size. Good shots: the first session with the banner, two tabs, Neovim editing a file, the themes list, `apk add` running.

## 7. Build

1. In Xcode, choose **Any iOS Device (arm64)** and run **Product > Archive**.
2. In the Organizer, **Distribute App > App Store Connect > Upload**.
3. Back in App Store Connect, pick the build under the version.

`tests/app-store-readiness.bash` checks a built app for the privacy manifests, the version and the bundled root. Raise `CURRENT_PROJECT_VERSION` (the build number, now 813) before each new upload.

### Export compliance

App Store Connect asks whether the app uses encryption. PhantOS itself implements none. It uses HTTPS through iOS, and programs in Linux (ssh, OpenSSL) use standard, published algorithms. That falls under the exemption for standard encryption, so the usual answer is: uses encryption, yes; qualifies for an exemption, yes. This is a legal declaration, so make it yourself. Once decided, adding `ITSAppUsesNonExemptEncryption = NO` to `app/Info.plist` stops the question on every upload.

## 8. App Review information

| Field | Value |
| --- | --- |
| Sign-in required | No |
| Contact | your name, phone and email |

### Notes for the reviewer

```text
PhantOS is a terminal app that runs Alpine Linux inside an x86 emulator on the device. It is derived from iSH, the open-source Linux shell already on the App Store, and adds a new terminal engine, tabs, themes and a preconfigured zsh and Neovim.

How to try it:
1. The app opens to a zsh shell. Type: apk add python3
2. Type: python3 -c "print('hello')"
3. Tap + at the top to open a second tab. Hold a tab to rename or close it.
4. Type: nvim notes.txt to edit a file. Type :q to quit.

Code: every program runs inside the emulator as x86 instructions, interpreted on device. PhantOS downloads no native code and does not change its own behavior; users choose what to install with apk, as in iSH.

Location: iOS asks first. Location is read only when a program the user runs opens /dev/location. The background location mode lets such a program keep receiving updates while the app is in the background.

Local network: used by ping and by connections to localhost, after the iOS prompt.

Source code: https://github.com/giossaurus/phantos (GPLv3). The iSH copyright holders allow App Store distribution of derived apps in LICENSE.IOS.
```

## Before you press Submit

- [ ] The PhantOS pull request is merged, so the privacy and support URLs work
- [ ] The build passes `tests/app-store-readiness.bash`
- [ ] Screenshots for iPhone 6.9" and iPad 13"
- [ ] Age rating and export compliance answered
- [ ] Reviewer notes pasted
