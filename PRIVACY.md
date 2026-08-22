# PostureAI Privacy Policy

### Updated August 23, 2026

> **Styled version:** This policy is also available as an interactive web page at `privacy.html` in this repository (hosted via GitHub Pages once enabled).

PostureAI's Privacy Policy describes how PostureAI collects, uses, and shares your personal data.

In addition to this Privacy Policy, PostureAI presents a system permission prompt before first using any protected resource — such as your camera, motion sensors, Bluetooth, or Focus status — explaining exactly why that access is needed. You can review or revoke each permission at any time in System Settings → Privacy & Security.

You can familiarize yourself with our privacy practices, accessible via the headings below, and [contact us](https://github.com/jeffrey1024hk-stack/HKICT/issues) if you have any questions.

## At a Glance

-   **We do not receive your personal data.** All posture detection, statistics, and AI processing happen entirely on your Mac.
-   **No accounts, no ads, no trackers.** PostureAI contains no analytics SDKs, crash reporting, advertising networks, or third-party tracking of any kind.
-   **Only two kinds of network connections exist:** checking/downloading app updates from GitHub, and an optional one-time download of open-source AI model weights that you explicitly start. Neither sends your personal information anywhere.

## What Is Personal Data at PostureAI?

At PostureAI, we treat any data that relates to an identified or identifiable individual as "personal data." This includes data that directly identifies you — such as your name — and also data that could reasonably be linked to you, such as your calibration profile or usage statistics.

Because PostureAI was designed so that this data never leaves your Mac, the practical effect is simple: **we cannot access, sell, leak, or share your personal data, because we never have it.**

## Personal Data PostureAI Collects from You

**PostureAI does not transmit any personal data off your Mac.** To power its features, PostureAI processes and stores the following data *locally on your device*:

-   **Camera-Derived Posture Information.** When camera monitoring is enabled, video frames are analyzed in real time on-device using Apple's Vision framework to estimate body pose. Frames are never saved, recorded, or transmitted. Only derived results (for example, whether you are sitting upright) are used.
    
-   **Motion and Fitness Information.** When AirPods monitoring is enabled, head-tilt motion samples from your AirPods Pro/Max are read through Apple's CoreMotion framework and processed on-device. This fitness data is used solely to provide the posture-monitoring feature directly to you. It is not used for advertising, marketing, or use-based data mining, and is never disclosed to third parties.
    
-   **App Usage Information.** If you enable the optional AI insights feature, PostureAI records which application is frontmost and for how long, along with aggregate posture time per app, in `~/Library/Application Support/PostureAI/appUsage.json`. This stays on your device and is used only to personalize insights shown to you.
    
-   **Settings and Calibration Information.** Your preferences, sensitivity thresholds, hotkeys, and calibration profiles are stored in your local app preferences so the app remembers them between launches.
    
-   **Posture Statistics.** Aggregate statistics such as minutes tracked, slouch counts, and streaks are stored locally (`~/Library/Application Support/PostureAI/analytics.json`) and displayed back to you in the Analytics window.
    
-   **Widget Status.** A minimal snapshot of current status (such as whether monitoring is active and minutes today) is shared with the PostureAI widget through macOS's app group container on your device.

You are not required to grant any permission for PostureAI to function partially: camera and AirPods monitoring are independent alternatives, and every permission can be declined or later revoked in System Settings, disabling only the related feature.

## Personal Data PostureAI Receives from Other Sources

None. PostureAI receives no personal data from other individuals, businesses, partners, or any other source.

## PostureAI's Use of Personal Data

**PostureAI processes personal data only on your device, only for purposes you have chosen, and only while the relevant feature is enabled.**

-   **Power Core Features.** Camera pose analysis, AirPods motion analysis, screen blur/warning overlays, and notifications are computed locally in real time.
    
-   **Show You Your Own Data.** Statistics and per-app summaries are rendered locally in the Analytics and Dashboard windows.
    
-   **Personalize Optional AI Insights.** If enabled, aggregated posture and app-usage information is fed to an open-source language model (Phi-3 Mini) running locally via Apple's MLX framework. Prompts built from your data are processed on your hardware and are never uploaded, logged remotely, or visible to anyone else. You can delete the downloaded model — and everything associated with it — at any time from the app's settings.
    

**PostureAI does not build profiles about you for anyone but you, does not use algorithms to make decisions that would significantly affect you, and does not use your data to train any machine-learning models.**

**PostureAI retains local personal data only for as long as you keep the app installed.** Nothing is stored on any server, so there is no server-side retention.

## Network Connections

Direct-distribution builds make exactly two kinds of network connections, neither of which carries your personal data:

-   **Automatic Updates.** Using the open-source Sparkle framework, PostureAI checks at most once per day (or when you choose Check for Updates) against `raw.githubusercontent.com` for new releases, and may download a signed installer from `github.com` if you approve it. Updates are cryptographically signed (EdDSA) and verified before installation.
    
-   **Optional AI Model Download.** If you enable AI insights, open-source model weights are downloaded once — only when you explicitly start it — from `huggingface.co` or its mirror `hf-mirror.com`. This download contains public machine-learning files, not your data.
    

Apps installed from the Mac App Store contain neither mechanism and make **no network connections at all**.

## PostureAI's Sharing of Personal Data

**PostureAI does not share, sell, rent, or trade your personal data with anyone — including "sharing" as defined under California law — because your personal data never reaches us or any server we control.**

The providers named above (GitHub and Hugging Face, when you use updates or the optional model download) act only as conduits for publicly hosted files. Like operators of any website, they may observe standard request metadata (such as your IP address) under their own published policies:

-   GitHub: https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
-   Hugging Face: https://huggingface.co/privacy

Any third party with whom user data might ever be shared in connection with PostureAI is required to provide the same or equal protection of user data as stated in this Privacy Policy and required by the App Store guidelines. We do not permit third parties to use any connection to PostureAI to track you or build profiles about you.

## Protection of Personal Data at PostureAI

At PostureAI, we believe that great privacy rests on keeping data where it belongs: with you. Because all personal data remains inside your user library, it is protected by your macOS account and FileVault encryption. Update packages are EdDSA-signed and verified before installation, and the app requests the minimum permissions required for each feature.

## Children and Personal Data

PostureAI understands the importance of safeguarding children's personal data, which we consider to be that of an individual under the age of 13 or the equivalent minimum age specified by law in your jurisdiction. PostureAI collects no personal data from anyone — child or adult — contains no chat or social features, and links only to this project's own documentation.

If you believe a child's personal data has somehow been associated with PostureAI, contact us and we will address it promptly.

## Transfer of Personal Data Between Countries

PostureAI operates no servers and transfers no personal data between countries. The only network connections described above involve publicly hosted files served by GitHub's or Hugging Face's global infrastructure; any handling of standard request metadata by those providers occurs under their respective privacy policies.

## Changes to This Privacy Policy

When we make material changes to this Privacy Policy, we will update the date above and announce the change in the app's release notes.

## Privacy Questions

If you have questions about PostureAI's privacy practices, open an issue at:

https://github.com/jeffrey1024hk-stack/HKICT/issues

---

*PostureAI is developed by some chill developers.*
