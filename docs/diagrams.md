# TripJio Diagrams

---

## Diagram 1 — System Architecture

```mermaid
graph TD
    FA[Flutter App\nDriver Side] & FB[Flutter App\nLoad Owner Side]

    FA -->|Phone OTP login| FireAuth[Firebase Auth\nBlaze]
    FB -->|Phone OTP login| FireAuth
    FireAuth -->|JWT token| FA & FB

    FA -->|Read/Write trips,\nusers, drivers| SupaDB[(Supabase\nPostgreSQL)]
    FB -->|Read/Write trips,\nload_owners| SupaDB

    FA -->|Upsert GPS location\nevery 3s| SupaRT[Supabase\nRealtime]
    SupaRT -->|Live driver location\nevents| FB

    FA -->|Upload profile photo| SupaST[Supabase\nStorage]
    FB -->|Upload profile photo| SupaST

    SupaDB -->|Edge Function triggers\nnew trip_request| FCM[Firebase FCM]
    FCM -->|Push notification\nnew trip request| FA
    FCM -->|Push notification\ndriver accepted| FB

    FA -->|Show map &\ncalculate route| GMaps[Google Maps SDK\n+ Directions API]
    FB -->|Show map &\ntrack driver| GMaps
```

---

## Diagram 2 — Auth Flow

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant FA as Firebase Auth
    participant SMS as SMS Gateway
    participant SB as Supabase DB

    U->>App: Enter phone number
    App->>FA: verifyPhoneNumber()
    FA->>SMS: Send OTP (DLT via Google)
    SMS-->>U: OTP SMS received
    U->>App: Enter OTP
    App->>FA: signInWithCredential()
    FA-->>App: FirebaseUser (UID + JWT)

    App->>SB: INSERT into users (firebase_uid as PK)

    alt Driver
        App->>SB: INSERT into drivers
        App->>SB: INSERT into vehicles
        App-->>U: Navigate to Driver Home
    else Load Owner
        App->>SB: INSERT into load_owners
        App-->>U: Navigate to Load Owner Home
    end
```

---

## Diagram 3 — Trip Request Flow

```mermaid
sequenceDiagram
    participant LO as Load Owner App
    participant SB as Supabase DB
    participant EF as Supabase Edge Function
    participant FCM as Firebase FCM
    participant DR as Driver App

    LO->>SB: Fetch driver profile (tap pin on map)
    LO->>LO: Fill pickup, dropoff, goods type, weight
    LO->>SB: INSERT trips (status = searching)
    LO->>SB: INSERT trip_requests

    SB->>EF: Trigger on new trip_request
    EF->>FCM: Call FCM API with driver FCM token
    FCM->>DR: Push notification — new trip request
    DR->>DR: Show IncomingLoadScreen (60s timer)

    alt Driver Accepts
        DR->>SB: UPDATE trip_requests status = accepted
        DR->>SB: UPDATE trips status = accepted, driver_id = X
        SB-->>LO: Realtime notify — trip accepted
        LO-->>LO: Navigate to RequestAcceptedScreen
        DR-->>DR: Navigate to TripAcceptedScreen (route to pickup)
    else Driver Rejects or Timer Expires
        DR->>SB: UPDATE trip_requests status = rejected / expired
        SB-->>LO: Realtime notify
        LO-->>LO: Show "Find another driver"
    end
```

---

## Diagram 4 — Live Tracking Flow

```mermaid
sequenceDiagram
    participant DR as Driver App
    participant SB as Supabase DB
    participant RT as Supabase Realtime
    participant LO as Load Owner App

    Note over DR,LO: Trip status = accepted

    DR->>DR: Start GPS stream (geolocator)
    LO->>RT: Subscribe to driver_locations table

    loop Every 3 seconds
        DR->>SB: UPSERT lat, lng, heading → driver_locations
        SB->>RT: Broadcast change event
        RT-->>LO: Location update
        LO->>LO: Move driver marker on Google Map
    end

    DR->>SB: UPDATE trip status = arrived
    SB->>RT: Broadcast status change
    RT-->>LO: Notify arrived
    LO->>LO: Navigate to DriverArrivedScreen

    LO->>SB: Tap "Start Trip" → UPDATE status = in_progress
    DR->>DR: Show TripInProgressScreen (route to dropoff)

    DR->>SB: Tap "Complete Trip" → UPDATE status = completed
    DR->>SB: INCREMENT driver total_trips
    SB->>RT: Broadcast completed
    RT-->>LO: Notify completed
    LO->>LO: Show Trip Summary & Rate Driver
```

---

## Diagram 5 — App Screen Flow

```mermaid
flowchart TD
    Launch([App Launches]) --> AuthCheck{Firebase\nAuth State?}

    AuthCheck -->|Not logged in| Onboarding[Onboarding Screen]
    Onboarding --> PhoneEntry[Phone Entry Screen]
    PhoneEntry --> OTP[OTP Screen]
    OTP --> RoleSelect{Driver or\nLoad Owner?}

    RoleSelect -->|Driver| DProfile[Driver Profile Setup\n+ Photo Upload]
    DProfile --> DVehicle[Vehicle Details]
    DVehicle --> DHome

    RoleSelect -->|Load Owner| LOProfile[Load Owner Profile\n+ Photo Upload]
    LOProfile --> LOHome

    AuthCheck -->|Logged in as Driver| DHome[Driver Home\nGoogle Map]
    AuthCheck -->|Logged in as Load Owner| LOHome[Load Owner Home\nNearby Drivers on Map]

    %% Driver Flow
    DHome -->|Toggle Online| GPS[GPS Broadcasting Starts]
    GPS --> DHome
    DHome -->|FCM Push| Incoming[IncomingLoadScreen\n60s Timer]
    Incoming -->|Accept| TripAccepted[TripAcceptedScreen\nRoute to Pickup]
    TripAccepted -->|Arrive| TripInProgress[TripInProgressScreen\nRoute to Dropoff]
    TripInProgress -->|Complete| Earnings[Earnings Summary]
    Earnings --> DHome

    %% Load Owner Flow
    LOHome -->|Tap Driver Pin| DriverDetails[Driver Profile & Rating]
    DriverDetails -->|Send Request| Waiting[Waiting for Driver Screen]
    Waiting -->|Driver Accepts| ReqAccepted[RequestAcceptedScreen]
    ReqAccepted --> LiveTracking[LiveTrackingScreen\nGoogle Maps]
    LiveTracking -->|Driver Arrives| DriverArrived[DriverArrivedScreen]
    DriverArrived -->|Trip Completes| RateDriver[Rate Driver Screen]
    RateDriver --> LOHome
```
