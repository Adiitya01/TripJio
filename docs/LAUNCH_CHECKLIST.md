# TripJio — Pre-Launch Yes/No Decision Audit

> **Purpose:** Every screen where user can say "yes/no/cancel" — does the app handle BOTH paths correctly?
> Status legend: ✅ Handled · ⚠️ Partial · ❌ Broken/Missing

---

## 🚀 1. APP LAUNCH

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 1.1 | Is user logged in? | Go to Home (Driver/Load Owner) | Go to Onboarding | ✅ |
| 1.2 | Has session expired (multi-device)? | Sign out + go to Onboarding | Stay logged in | ✅ |
| 1.3 | Is OS notification permission granted? | FCM token saved | Skip silently — app still works | ✅ |
| 1.4 | Has user seen welcome dialog? | Skip | Show once on first home open | ✅ |

---

## 📲 2. ONBOARDING & ROLE SELECTION

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 2.1 | User taps "Get Started" | → Phone Entry | (stays on onboarding) | ✅ |
| 2.2 | User picks Driver | → Driver Profile | — | ✅ |
| 2.3 | User picks Load Owner | → Load Owner Profile | — | ✅ |
| 2.4 | User taps back on User Type | → OTP screen | — | ✅ |

---

## 📞 3. PHONE ENTRY SCREEN

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 3.1 | Phone number is 10 digits valid | "Send OTP" enabled | Button disabled (greyed) | ✅ |
| 3.2 | T&C checkbox ticked | "Send OTP" enabled | Button disabled | ✅ |
| 3.3 | User taps Send OTP — network OK | OTP sent, navigate to OTP screen | — | ✅ |
| 3.4 | User taps Send OTP — network fails | — | Red snackbar with error | ✅ |
| 3.5 | User taps Send OTP — invalid number | — | Firebase rejects, error shown | ✅ |
| 3.6 | User taps Send OTP — quota exceeded | — | "Too many requests" error | ✅ |
| 3.7 | User taps back | Returns to Onboarding | — | ✅ |

---

## 🔢 4. OTP SCREEN

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 4.1 | All 6 digits entered | Auto-verify triggers | Verify button disabled | ✅ |
| 4.2 | OTP correct | → User Type screen | — | ✅ |
| 4.3 | OTP wrong | — | Red snackbar, can retry | ✅ |
| 4.4 | OTP expired (>60s) | — | "OTP expired" error | ✅ |
| 4.5 | Resend timer running | Resend button disabled | — | ✅ |
| 4.6 | User taps Resend (after 60s) | New OTP sent | — | ✅ |
| 4.7 | User taps back | Returns to Phone Entry | — | ✅ |
| 4.8 | User force-closes during verification | — | Re-enters phone next launch | ✅ |

---

## 👤 5. DRIVER PROFILE / LOAD OWNER PROFILE SCREEN

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 5.1 | All required fields filled | "Next/Continue" enabled | Button disabled (greyed) | ✅ |
| 5.2 | User taps Continue — save to DB OK | → Next screen | — | ✅ |
| 5.3 | User taps Continue — save fails (network) | — | Red snackbar | ✅ |
| 5.4 | User taps back | Returns to User Type | — | ✅ |

---

## 🚛 6. VEHICLE DETAILS SCREEN (Driver only)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 6.1 | Vehicle number filled | Validate format | Button disabled | ✅ |
| 6.2 | Vehicle number invalid format | — | "Invalid plate format" snackbar | ✅ |
| 6.3 | Duplicate vehicle plate | — | "Already registered" error | ✅ |
| 6.4 | Duplicate license number | — | "Already registered" error | ✅ |
| 6.5 | User taps Complete Setup — saves | → LocationPermissionScreen | — | ✅ |
| 6.6 | User taps back | Returns to Driver Profile | — | ✅ |

---

## 📍 7. LOCATION PERMISSION SCREEN ⚠️ CRITICAL

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 7.1 | Location services enabled on phone | Request permission | "Enable Location Services" snackbar | ✅ FIXED |
| 7.2 | User taps Allow on OS dialog | Get initial GPS → Home | — | ✅ FIXED |
| 7.3 | User taps Deny on OS dialog | — | "Tap Allow to continue" snackbar, BLOCKS proceeding | ✅ FIXED |
| 7.4 | User taps "Don't ask again" (permanent deny) | — | Dialog with "Open Settings" button | ✅ FIXED |
| 7.5 | GPS times out (no signal indoors) | Save userType, continue | — | ✅ FIXED |
| 7.6 | User taps back from this screen | — | ❌ NO BACK BUTTON — could be issue | ⚠️ Verify |

> 🔥 **This was the Latur/Pune bug area.** Now fully blocks the user from proceeding without granting permission.

---

## 🏠 8. LOAD OWNER HOME SCREEN ⚠️ CRITICAL

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 8.1 | Has real GPS location | Map centers on user, drivers shown | ⚠️ Orange warning banner shown | ✅ FIXED |
| 8.2 | User taps "Find a Driver" with location | → SendRequestScreen | — | ✅ |
| 8.3 | User taps "Find a Driver" without location | Button disabled "Enable Location to Find Drivers" | — | ✅ FIXED |
| 8.4 | User taps "Find a Driver" — no drivers nearby | Button disabled "No drivers available" | — | ✅ |
| 8.5 | User taps Recenter button | Animate to user GPS | If no GPS → trigger fresh fetch | ✅ |
| 8.6 | User taps menu icon | → AccountSettings | — | ✅ |
| 8.7 | User taps notification icon | Currently empty | ⚠️ Does nothing | ⚠️ Defer |
| 8.8 | Driver marker tapped on map | → Show driver sheet | — | ✅ |

---

## 📦 9. SEND REQUEST SCREEN

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 9.1 | Pickup field filled | Allow send | Snackbar "Pickup required" | ✅ |
| 9.2 | Weight in valid range (1-50000) | Allow send | Snackbar with limit | ✅ |
| 9.3 | Notes ≤ 1000 chars | Allow send | Snackbar | ✅ |
| 9.4 | User taps Send Request — driver available | → WaitingForDriver | — | ✅ |
| 9.5 | User taps Send Request — driver became busy | — | "Driver no longer available" | ✅ |
| 9.6 | User taps Send Request — rate limit | — | "Slow down" snackbar | ✅ |
| 9.7 | User taps back | Returns to home | — | ✅ |

---

## ⏳ 10. WAITING FOR DRIVER SCREEN (Load Owner)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 10.1 | Driver accepts | Auto → RequestAccepted | — | ✅ |
| 10.2 | Driver rejects | — | Snackbar "Driver rejected" → back | ✅ |
| 10.3 | 2-min timer expires | Auto-cancel + back | — | ✅ |
| 10.4 | User taps Cancel Request | Server cancels | — | ✅ |
| 10.5 | User taps Cancel — driver just accepted (race) | — | "Going to tracking" snackbar | ✅ |
| 10.6 | User taps X (close) icon | Same as Cancel | — | ✅ |
| 10.7 | User taps system back button | Same as Cancel | — | ✅ |

> ⚠️ **Recommendation:** Add confirmation dialog for Cancel Request? Currently cancels immediately. (Defer)

---

## 📥 11. INCOMING LOAD SCREEN (Driver)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 11.1 | Driver taps Accept — request still pending | Atomic create trip → TripAccepted | — | ✅ |
| 11.2 | Driver taps Accept — already accepted by another | — | "Request no longer pending" | ✅ |
| 11.3 | Driver taps Accept — expired | — | "Request expired" | ✅ |
| 11.4 | Driver taps Reject | Mark rejected → back | — | ✅ |
| 11.5 | 2-min timer expires | Auto-back (treated as ignored) | — | ✅ |
| 11.6 | Driver taps system back button | ⚠️ Goes back without rejecting | — | ⚠️ MINOR |

> ⚠️ **Recommendation:** Treat back button as Reject. (Minor — current behavior is "ignore request" which is OK).

---

## ✅ 12. TRIP ACCEPTED SCREEN (Driver)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 12.1 | Driver taps Start Trip | Mark in_progress → TripInProgress | — | ✅ |
| 12.2 | Driver taps Cancel | Cancel trip → back to home | — | ✅ |
| 12.3 | Driver taps back system button | ⚠️ Goes back to home without cancelling | — | ⚠️ MINOR |

> ⚠️ **Recommendation:** Confirm before cancelling. (Already wired but verify message text).

---

## 🚗 13. TRIP IN PROGRESS SCREEN (Driver)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 13.1 | Driver taps "I've Reached Pickup" | Confirmation dialog → mark completed → home | — | ✅ |
| 13.2 | Driver taps Cancel in dialog | Stay on screen | — | ✅ |
| 13.3 | Driver taps Complete in dialog | Mark completed | — | ✅ |
| 13.4 | Driver taps system back button | ⚠️ Could exit screen without completing | — | ⚠️ VERIFY |
| 13.5 | GPS dies mid-trip | Last known shown, ETA stops updating | — | ⚠️ Acceptable |

> ⚠️ **Recommendation:** Block system back button on this screen until trip is complete or cancelled.

---

## 📍 14. LIVE TRACKING SCREEN (Load Owner)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 14.1 | Driver within 100m of pickup | Auto → DriverArrivedScreen | — | ✅ |
| 14.2 | Load owner taps Cancel Trip icon | Confirmation dialog | — | ✅ |
| 14.3 | Cancel confirmed | Mark cancelled → home | — | ✅ |
| 14.4 | Cancel rejected (Keep Trip) | Stay on tracking | — | ✅ |
| 14.5 | Load owner taps Call button | Opens system dialer with driver's phone | If no phone → silent (do nothing) | ⚠️ MINOR |
| 14.6 | Load owner taps back | Returns to RequestAccepted | — | ✅ |

---

## 📍 15. DRIVER ARRIVED SCREEN (Load Owner)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 15.1 | Driver completes trip externally | Auto → TripCompletedScreen (3s polling) | — | ✅ FIXED |
| 15.2 | Load owner taps Call button | Opens dialer | If no phone → silent | ⚠️ MINOR |
| 15.3 | Load owner taps "Awaiting Trip End" | Snackbar "Waiting for driver..." | — | ✅ |
| 15.4 | Load owner taps back | ⚠️ Returns to tracking — but trip is already over | — | ⚠️ VERIFY |

---

## 🎉 16. TRIP COMPLETED SCREEN (Load Owner)

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 16.1 | Load owner taps "Back to Home" | Clears stack → HomeScreen | — | ✅ |
| 16.2 | Load owner taps back | Same as Back to Home | — | ✅ |

---

## 🏠 17. DRIVER HOME SCREEN

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 17.1 | Driver toggles "Go Online" | Push GPS + set online | — | ✅ |
| 17.2 | Driver toggles "Go Offline" | Set offline | If active trip → blocked + toggle reverts | ✅ |
| 17.3 | Driver receives incoming request | Auto-show IncomingLoadScreen | If app backgrounded → won't show | ⚠️ Known (need server push) |
| 17.4 | Driver swipes My Trips tab | Show trip history | If empty → empty state | ✅ |
| 17.5 | Driver taps a past trip | ⚠️ Does nothing (no detail view) | — | ⚠️ Defer |
| 17.6 | Pull down on My Trips | Refresh from server | — | ✅ |
| 17.7 | Active trip resumed on app reopen | Auto-navigate to TripInProgress | — | ✅ |
| 17.8 | Driver taps menu/settings | → AccountSettings | — | ✅ |

---

## ⚙️ 18. ACCOUNT SETTINGS SCREEN

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 18.1 | User taps Notifications | ⚠️ Does nothing | — | ⚠️ Defer |
| 18.2 | User taps Help & Support | ⚠️ Does nothing | — | ⚠️ Defer |
| 18.3 | User taps Privacy Policy | ⚠️ Does nothing | — | ❌ Must add link |
| 18.4 | User taps T&C | ⚠️ Does nothing | — | ❌ Must add link |
| 18.5 | User taps About | Show about dialog | — | ✅ |
| 18.6 | User taps Log Out | Confirmation → sign out | If cancel → stay | ✅ |
| 18.7 | User taps Delete Account | Double confirmation → delete | If cancel → stay | ✅ |
| 18.8 | Delete Account — Firebase requires recent login | Falls back to signing out | — | ✅ |

---

## 🌐 19. SYSTEM-LEVEL EVENTS

| # | Decision | Yes Path | No Path | Status |
|---|----------|----------|---------|--------|
| 19.1 | Device goes offline | Banner shown at top | When restored → banner hides | ✅ |
| 19.2 | App backgrounded > 5 min while driver online | Auto-set offline (Uber-style) | When resumed → user toggles online again | ✅ |
| 19.3 | App resumed | Refresh token + invalidate stale providers | — | ✅ |
| 19.4 | User signs in on another device | This device auto-logged-out on next launch | — | ✅ |
| 19.5 | Battery very low | Continues working | — | ✅ |

---

## 🔥 PRE-LAUNCH BLOCKERS (Must Fix Before Public Launch)

| Priority | Item | Notes |
|----------|------|-------|
| 🔴 P0 | **Privacy Policy URL** in settings | Required by Play Store. Currently does nothing. |
| 🔴 P0 | **Terms & Conditions URL** in settings | Required by Play Store. Currently does nothing. |
| 🟡 P1 | Block back button during in-progress trip (driver) | Could accidentally exit |
| 🟡 P1 | Server-sent push notifications (FCM) | Driver misses requests when backgrounded |
| 🟢 P2 | Notification settings page (actual content) | Currently placeholder |
| 🟢 P2 | Help & Support content | Currently placeholder |
| 🟢 P2 | Tap past trip → detail view | Not implemented |
| 🟢 P2 | Phone call button error handling | Silent fail if no phone |

---

## ✅ READY FOR BETA TESTING

All Yes/No decision points either:
- ✅ Handle both paths gracefully
- ⚠️ Have an acceptable workaround
- ❌ Are documented as known issues for post-Beta

**Tomorrow's 2-phone test can proceed with confidence.**

The Latur/Pune fallback bug is now fixed — if a user denies location, they cannot proceed past the permission screen, and even if somehow they do, the map shows a clear warning and disables the "Find Driver" button.

---

## 📋 Final Pre-Launch Smoke Tests (Friend's Phone)

Do these IN ORDER on the new APK:

```
[ ] 1. Install APK fresh
[ ] 2. Tap through onboarding → Phone Entry
[ ] 3. Enter phone number → OTP arrives
[ ] 4. Enter wrong OTP → see error
[ ] 5. Enter correct OTP → choose role
[ ] 6. Complete profile → arrive at Location Permission
[ ] 7. Tap "Allow Location Access" → tap DENY in OS dialog
       → app should NOT proceed (orange snackbar)
[ ] 8. Tap "Allow Location Access" again → tap ALLOW
       → should fetch GPS → proceed to Home
[ ] 9. Home screen shows YOUR CITY on map (not Pune!)
[ ] 10. Profile menu → see correct name + role
[ ] 11. Try Logout → see confirmation dialog
[ ] 12. Try Delete Account → see double confirmation
       → tap Cancel both times to keep account
[ ] 13. (For Driver) Toggle Go Online → pulsing dot
[ ] 14. (For Load Owner) Tap "Find a Driver" — should work
[ ] 15. Full request → accept → tracking → completion flow
```

When all 15 boxes are checked → **ready to share with more testers**.

---

**Last updated:** Pre-Beta Launch
**Version:** 1.0.0+1 with Latur/Pune fix
