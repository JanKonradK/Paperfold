# Android developer verification — what it means for Paperfold

Milestone 0 action from `plan.md` Section 2.4. Checked on 2026-08-10 against
Google's own documentation, not against the Book's Story README.

## The claim in the plan

The Book's Story README says:

> Starting in September 2026, Android will require all apps to be registered by
> verified developers in order to be installed on certified Android devices.

## What Google actually says

The claim is correct in direction. It is too wide in scope.

| Item | Google's statement |
|---|---|
| Enforcement start | 30 September 2026 |
| First-wave countries | Brazil, Indonesia, Singapore, Thailand |
| Global expansion | 2027, for all apps on certified Android devices |
| Scope | Apps from participating stores, and sideloaded apps |
| Escape route | ADB install and an "advanced flow" for experienced users |
| Verification opened | March 2026, through Play Console and Android Developer Console |

## What this means for Paperfold

1. **Poland and the European Union are not in the first wave.** The 30 September
   2026 date does not block a Polish release.
2. **2027 is the real date for this project.** Global expansion applies to all
   apps on certified devices. Paperfold must be registered before then.
3. **Registration does not need Google Play.** A developer who distributes
   outside Play registers through the Android Developer Console.
4. **Sideloading continues.** ADB installs and the advanced flow stay available.
   Direct APK distribution to power users is not dead.

## Required data for registration

Legal name, address, email address, and telephone number. An organization also
needs a D-U-N-S number. Google can ask for a government identity document.

## Action

- No action is needed for Milestone 0. The gate is clear.
- Register before the 2027 global expansion. Add this to Milestone 9.
- Check the country list again before the first public release. Google can add
  countries to the first wave.

## Sources

- <https://developer.android.com/developer-verification>
- <https://developer.android.com/developer-verification/guides/faq>
- <https://android-developers.googleblog.com/2026/06/android-developer-verification.html>
- <https://support.google.com/android-developer-console/answer/16561738>
