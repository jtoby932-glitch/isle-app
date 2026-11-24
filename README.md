# Isle

A week planner and habit tracker for iPhone, with a companion called Pip who grows an island from what you get done. SwiftUI + SwiftData, iOS 17+, fully offline, no account, no paywall.

## Get the app

Every push to `main` builds on GitHub's Macs (`.github/workflows/build.yml`):

- **Isle.ipa** (unsigned) is attached to a new release under **Releases**, and also saved as the `Isle-ipa` artifact. Install it with Sideloadly or AltStore, which sign it with your Apple ID.
- **Unit tests** run on an iOS simulator in a separate job.
- If the build fails, the log is pushed to the `ci-logs` branch (`errors.txt` has just the errors).

On a Mac: open `Isle.xcodeproj` in Xcode 16+, choose your team under Signing, pick your iPhone and press Run.

The project file is generated. After adding or removing Swift files run `python3 tools/gen_xcodeproj.py`. `python3 tools/make_icon.py` redraws the app icon.

## What's where

| Part | Files |
|---|---|
| Design tokens, buttons, cards | `Isle/Design/Theme.swift`, `Isle/Design/Components.swift` |
| Pip (drawn in code, animated) | `Isle/Design/Pip.swift` |
| Data model | `Isle/Models/Models.swift` |
| Days, quick-add parser, planner, rewards | `Isle/Domain/` |
| Sound (synthesised, no audio files) and haptics | `Isle/Services/Synth.swift`, `Isle/Services/Feedback.swift` |
| Calendar (read only), notifications | `Isle/Services/CalendarService.swift`, `Isle/Services/NotificationService.swift` |
| Screens | `Isle/Features/` — Today, Week, Quick add, Edit task, Habits, Sunday planning, Isle, Check-in, Focus, Day complete, Shell Shop, Search, Settings, Sounds & haptics, Onboarding |

## How it works

- **Planning:** tasks live on a day (or in the Inbox). Each day has a capacity (7h weekdays, 5h weekends by default). Tasks, timed habits and calendar events count towards it; going over makes the day stormy, and Fix it moves the smallest tasks to the lightest later days.
- **Habits** have weekly targets, so missing a day never breaks anything. Streaks count weeks on target. Holiday pause freezes the rest of the week.
- **Battery check-in** each morning: Low moves big tasks later and swaps habits for their low-battery version (double shells); Empty moves every task.
- **Shells** come from ticking things off (10, or 20 for big or priority tasks), Focus sessions (20) and planning your week (20). Spend them in the Shell Shop on Pip outfits, colours and isle decor. Nothing costs real money.
- **Sound:** every sound is built from one five-note scale, so overlapping sounds harmonise. Three packs: Wood, Glass, Soft. Follows the silent switch.

## Not in this version

- **Home screen widgets and the Focus Live Activity** need an app extension and an App Group, which free sideloading accounts often can't sign. Left out so the app always installs.
- **iCloud sync** needs a CloudKit entitlement for the same reason. Everything is stored on the phone.
