# TripJio — Manual Test Plan

> **Run this AFTER** the automated tests (`run_tests.ps1` + `supabase_test_suite.sql`) pass.
>
> These tests verify behaviors that can't be automated: Realtime, GPS, multi-device, UI flows.
>
> **Setup:** You need **2 devices** (or 2 browser windows) — one as Driver, one as Load Owner.

---

## 🟢 SECTION A — AUTH & SIGNUP

| # | Test | Steps | Expected |
|---|------|-------|----------|
| A.1 | New driver signup | Phone → OTP → Driver → Profile → Vehicle → Complete | Lands on Driver Home; row appears in `users`, `drivers`, `vehicles` |
| A.2 | New load owner signup | Phone → OTP → Load Owner → Profile → Continue | Lands on Load Owner Home; row in `users` |
| A.3 | Invalid vehicle plate | Try `INVALID123` as vehicle number | Red snackbar: "Invalid plate format" |
| A.4 | Duplicate vehicle plate | Try to register a 2nd driver with same plate | "This vehicle number is already registered" |
| A.5 | Multi-device | Sign in same account on Phone 2 | Phone 1 logged out on next launch |
| A.6 | Logout | Profile → Log Out | Returns to onboarding, `active_sessions` row removed |
| A.7 | Resume after kill | Sign in → kill app → reopen | Goes directly to home (not onboarding) |

---

## 🚛 SECTION B — DRIVER FLOW

| # | Test | Steps | Expected |
|---|------|-------|----------|
| B.1 | Go online (with GPS) | Toggle "Go Online" | Banner turns green; `drivers.is_online=true`, `latitude/longitude` populated |
| B.2 | Heartbeat | Stay online 2 min, don't move | `drivers.updated_at` refreshes every ~60s in DB |
| B.3 | Receive request | Load owner sends → Driver | IncomingLoadScreen pops up automatically with real pickup/drop/weight |
| B.4 | Accept request | Tap Accept | Goes to TripAcceptedScreen with real data; `requests.status=accepted`, `drivers.is_busy=true`, new row in `trips` |
| B.5 | Reject request | Tap Reject | `requests.status=rejected`; load owner sees "rejected" snackbar |
| B.6 | Start trip | Tap Start Trip | TripInProgressScreen with real map + GPS; `trips.status=in_progress` |
| B.7 | Complete trip | Tap "I've Reached Pickup" | `trips.status=completed`, `drivers.is_busy=false`, `total_trips +=1` |
| B.8 | Toggle offline mid-trip | Accept trip → try Go Offline | Toggle reverts back to ON automatically |
| B.9 | Trips history | Open My Trips tab | Shows the trips you just completed (real data from DB) |
| B.10 | Profile shows real data | Open settings | Your real name, phone, city (not "Suresh Patil") |

---

## 📦 SECTION C — LOAD OWNER FLOW

| # | Test | Steps | Expected |
|---|------|-------|----------|
| C.1 | See nearby drivers | Open home → location prompt → allow | Real online drivers appear as markers on the map |
| C.2 | "Find a Driver" button | Tap big navy button | Animates to closest driver + opens SendRequestScreen |
| C.3 | List view | Tap "List view" link | Driver list with real names from DB |
| C.4 | Vehicle filter | Tap "LCV" chip | Only LCV drivers shown |
| C.5 | Send request | Fill drop, weight, send | WaitingForDriverScreen with 2-min countdown; row in `requests` |
| C.6 | Fare visible | On SendRequestScreen | Banner shows real estimated fare in ₹ |
| C.7 | Cancel pending request | Tap "Cancel Request" | Returns to map; `requests.status=cancelled` |
| C.8 | Driver accepts → tracking | Wait for driver to accept | Auto-navigates to RequestAcceptedScreen |
| C.9 | Live tracking | Open tracking screen | Driver marker on real Google Map; updates as driver moves |
| C.10 | Driver arrives | Driver gets within 100m of pickup | Auto-navigates to DriverArrivedScreen |
| C.11 | Phone call button | Tap green phone icon | Opens system dialer |

---

## ⚡ SECTION D — REALTIME & EDGE CASES

| # | Test | Steps | Expected |
|---|------|-------|----------|
| D.1 | Rate limit | Send 12 requests in 60s | 11th + 12th show "Slow down — wait a moment" |
| D.2 | Stale driver hides | Open driver, kill app, wait 4 min | Driver disappears from load owner's map |
| D.3 | Stale driver auto-offline | Wait 30+ min after killing | `drivers.is_online=false` in DB |
| D.4 | Heartbeat reappear | Reopen driver app while it's stale (< 30min) | Reappears on load owner's map |
| D.5 | Validation: negative weight | Try weight = -100 in send request | Red snackbar "Weight must be 1 to 50000 kg" |
| D.6 | Validation: huge weight | Try 99999 kg | Same rejection |
| D.7 | Cancel after accept (race) | Cancel exactly when driver accepts | "Driver just accepted — going to tracking" |
| D.8 | Driver receives notification | When request comes in | Local notification fires (if permission granted) |
| D.9 | App resume refresh | Background app 2 min → return | Data refreshes, no stale state |
| D.10 | Offline browser | Disable network, try Send Request | Error snackbar (no crash) |

---

## 🔐 SECTION E — SECURITY

| # | Test | Steps | Expected |
|---|------|-------|----------|
| E.1 | Cross-user trip complete | Use cURL to call `complete_trip` for another driver's trip | RPC returns "Not authorized" |
| E.2 | Cross-user cancel | Same for cancel | "Not authorized" |
| E.3 | PII not leaked | Inspect `fetch_nearby_drivers` response | No `phone`, no `license_number` in output |
| E.4 | RLS check | As anon user, try to SELECT * from `users` | Either blocked or returns no rows |
| E.5 | SQL injection | Try `'; DROP TABLE users;--` in goods description | Sanitized — saved as plain text |

---

## 📊 SECTION F — PERFORMANCE

| # | Test | Steps | Expected |
|---|------|-------|----------|
| F.1 | Nearby query speed | Open Load Owner home, watch DevTools Network | Query under 200ms |
| F.2 | Map loads quickly | Time from home open to map render | Under 2s |
| F.3 | Realtime latency | Driver accepts → time to load owner navigation | Under 1s |
| F.4 | App cold start | Kill + relaunch app | Splash to home in under 3s |

---

## 🎯 GO/NO-GO CHECKLIST

Before going live, ALL of these must be ✅:

- [ ] All 50+ items in this manual plan pass
- [ ] `supabase_test_suite.sql` shows 100% pass rate
- [ ] `flutter test test/unit/` passes
- [ ] `flutter analyze` shows zero errors
- [ ] `flutter build apk --release` succeeds
- [ ] At least 1 full end-to-end test on real phones (not just browser)
- [ ] Terms & Conditions reviewed by legal/lawyer
- [ ] Privacy Policy drafted and linked in app
- [ ] Firebase project on **paid plan** (free tier has SMS limits)
- [ ] Supabase project on **Pro plan** (free tier auto-pauses)
- [ ] Google Maps API key has billing enabled
- [ ] Production firebase_options.dart has correct `appId` for each platform
- [ ] OneDrive sync disabled or project moved out of OneDrive
- [ ] APK signed with proper release keystore

---

## 🚨 IF SOMETHING FAILS

| Symptom | First thing to check |
|---------|---------------------|
| Request not reaching driver | Driver on home screen + online? Supabase Realtime enabled? |
| Driver not showing on map | `drivers.is_online=true`? `updated_at` fresh? |
| Maps not loading | Google Maps API key + billing? |
| OTP not arriving | Firebase Auth quota? Test phone number? |
| Slow queries | Are all SQL migrations applied? Check indexes |
| Auto-logout on app open | `active_sessions` mismatch — sign in again |

---

## 🎉 IF EVERYTHING PASSES

You're ready for **Closed Beta** — invite 10-20 real drivers + load owners to test on the field. After 1-2 weeks of real-world feedback, you'll be ready for public launch.

**Estimated time to run this full plan:** 90 minutes with 2 phones.
