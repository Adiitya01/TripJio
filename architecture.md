# TripJio Architecture Documentation

This document contains the core architectural diagrams and flows for the TripJio application.

## 1. High-Level System Architecture
![System Architecture](./docs/diagrams/1_system_architecture.png)
*This diagram illustrates the overall system architecture, including the Driver App, Load Owner App, Firebase Auth, Supabase Database, Google Maps SDK, and other key components.*

## 2. Authentication Flow
![Auth Flow](./docs/diagrams/2_auth_flow.png)
*Sequence diagram detailing the authentication process involving the User, Flutter App, Firebase Auth (OTP), and Supabase DB.*

## 3. Trip Request Flow
![Trip Request Flow](./docs/diagrams/3_trip_request_flow.png)
*Sequence diagram showing the process of a Load Owner requesting a trip, the Supabase Edge Function triggering FCM notifications, and the Driver accepting the trip.*

## 4. App Launch & Main Flow
![App Launch Flow](./docs/diagrams/4_app_launch_flow.png)
*Flowchart outlining the user journey from app launch, role selection (Driver vs. Load Owner), and the respective home screen actions.*

## 5. Live Tracking Flow
![Live Tracking Flow](./docs/diagrams/5_live_tracking_flow.png)
*Sequence diagram explaining the real-time GPS location updates from the Driver App, stored in Supabase Realtime, and reflected on the Load Owner's map.*
