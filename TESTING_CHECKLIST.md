# TripJio — Beta Testing Checklist

Run the app with: `flutter run -d chrome`

---

## 🔐 1. AUTH FLOW

| # | Test | Expected |
|---|------|----------|
| 1.1 | Open app fresh (not logged in) | Splash → Onboarding screen |
| 1.2 | Open app already logged in | Splash → Driver or Load Owner home (no onboarding) |
| 1.3 | Enter phone number | OTP screen appears |
| 1.4 | Enter correct OTP | Goes to User Type selection |
| 1.5 | Select "Driver" | Goes to Driver Profile screen |
| 1.6 | Select "Load Owner" | Goes to Load Owner Profile screen |
| 1.7 | Fill Driver profile + vehicle → Complete Setup | Goes to Location Permission → Driver Home |
| 1.8 | Fill Load Owner profile → Continue | Goes to Location Permission → Load Owner Home |
| 1.9 | Check Supabase → Table Editor → `users` table | New row should appear |
| 1.10 | Check Supabase → `vehicles` table (driver only) | New row should appear |
| 1.11 | Log out from Profile | Goes to Onboarding, SharedPrefs cleared |

---

## 🚛 2. DRIVER FLOW

| # | Test | Expected |
|---|------|----------|
| 2.1 | Open Driver Home | Sees "Find Loads" and "My Trips" tabs |
| 2.2 | Toggle "Go Online" switch | Banner turns green, status = Online |
| 2.3 | Toggle online | Supabase `drivers.is_online` updates to `true` |
| 2.4 | Go Online → GPS updates | Supabase `drivers.latitude/longitude` updates every 10s |
| 2.5 | Receive a load request (send from Load Owner side) | IncomingLoadScreen pops up automatically |
| 2.6 | IncomingLoadScreen shows real data | Pickup, drop, weight, fare, load owner name are real |
| 2.7 | Tap "Reject" on incoming request | Screen closes, request status = rejected in Supabase |
| 2.8 | Tap "Accept" on incoming request | Goes to TripAcceptedScreen with real trip data |
| 2.9 | TripAcceptedScreen shows real pickup/drop | Addresses from the actual request |
| 2.10 | TripAcceptedScreen shows fare | e.g. "₹ 320" based on distance + weight |
| 2.11 | Tap "Start Trip" | Goes to TripInProgressScreen, trip created in Supabase |
| 2.12 | TripInProgressScreen shows real map | Google Maps with pickup + drop markers |
| 2.13 | TripInProgressScreen shows real distance & ETA | Updates as driver moves |
| 2.14 | Tap "I've Reached Pickup" | Trip status → completed in Supabase, back to Home |
| 2.15 | Check "My Trips" tab after completion | Shows completed trip (real data) |
| 2.16 | Driver profile shows real name + phone | Not "Suresh Patil" hardcoded |

---

## 📦 3. LOAD OWNER FLOW

| # | Test | Expected |
|---|------|----------|
| 3.1 | Open Load Owner Home | Google Maps with truck markers |
| 3.2 | Map shows nearby online drivers | Markers from Supabase (not hardcoded) |
| 3.3 | Tap a driver marker | Driver details bottom sheet opens |
| 3.4 | Tap "List view" | DriversListScreen with real drivers from Supabase |
| 3.5 | Tap "Send Request" on a driver | SendRequestScreen opens |
| 3.6 | SendRequestScreen shows fare + ETA | e.g. "₹ 280 · 12 min · 5.0 km" in blue banner |
| 3.7 | Fill pickup/drop/weight → Send Request | WaitingForDriverScreen opens |
| 3.8 | WaitingForDriverScreen shows 2-min countdown | Real timer, not mock |
| 3.9 | Driver accepts on their device | WaitingForDriver auto-navigates to RequestAcceptedScreen |
| 3.10 | Driver rejects | Shows "Driver rejected" snackbar, returns to map |
| 3.11 | Tap "Cancel Request" on waiting screen | Request cancelled in Supabase |
| 3.12 | RequestAcceptedScreen → Track Driver | LiveTrackingScreen opens |
| 3.13 | LiveTrackingScreen shows real Google Map | Driver's real GPS marker visible |
| 3.14 | Driver marker moves as driver moves | Supabase Realtime updates |
| 3.15 | Driver within 100m of pickup | Auto-navigates to DriverArrivedScreen |
| 3.16 | DriverArrivedScreen "Complete Trip" | Trip marked completed in Supabase |

---

## 🔔 4. NOTIFICATIONS

| # | Test | Expected |
|---|------|----------|
| 4.1 | Load Owner sends request to Driver | Driver sees local notification "New Load Request!" |
| 4.2 | Driver accepts request | Load Owner sees "Request Accepted!" notification |
| 4.3 | Driver arrives at pickup (100m) | Load Owner sees "Driver Arrived!" notification |
| 4.4 | Trip completed | Both see "Trip Completed!" notification |

---

## 📐 5. CALCULATIONS

| # | Test | Expected |
|---|------|----------|
| 5.1 | SendRequestScreen fare for Mini Truck, 5km | ₹ ~110 (50 base + 12×5) |
| 5.2 | SendRequestScreen fare for HCV, 10km | ₹ ~270 (50 base + 22×10) |
| 5.3 | ETA for 5km | ~12 min (5 ÷ 25 × 60 × 1.2) |
| 5.4 | Distance label for <1km | Shows in meters e.g. "850 m" |
| 5.5 | Distance label for >1km | Shows in km e.g. "2.4 km" |

---

## 🗺️ 6. SUPABASE DATABASE

Check these in Supabase Table Editor after testing:

| Table | What to verify |
|-------|---------------|
| `users` | Row created after signup |
| `drivers` | Row created after driver signup, is_online toggles |
| `vehicles` | Row with unique UUID id |
| `requests` | Row created when Load Owner sends request, status updates |
| `trips` | Row created when Driver starts trip, status → completed |

---

## ⚠️ KNOWN LIMITATIONS (Not Beta Blockers)

- Google Maps may not load on Chrome without a valid Maps API key
- Firebase Phone Auth OTP doesn't work on web without a valid web appId
- Background GPS only works on Android (not web)
- Driver profile photo upload not yet implemented
- Rating/review after trip not yet implemented
- Load Owner past trips screen not yet implemented

---

## 🚀 HOW TO RUN

```powershell
# Enable Developer Mode first (one time)
start ms-settings:developers

# Run the app
flutter run -d chrome

# Or build for web
flutter build web
```
