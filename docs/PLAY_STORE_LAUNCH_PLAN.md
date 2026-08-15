# TripJio — Play Store Launch Plan

**Prepared for:** Trip-Jio Logistics
**Document type:** Pre-Launch Action Plan
**Estimated timeline:** 3 weeks from approval to public launch

---

## 1. Overview

This document outlines all activities required to take TripJio from "development complete" to "live on Google Play Store." Items are categorized by owner (Client / Development / Joint) and grouped by phase.

---

## 2. Phase 1 — Closed Beta (Week 1)

**Goal:** Validate the platform with real users in real conditions before public exposure.

### 2.1 Development Team Tasks

| # | Task | Status |
|---|------|--------|
| 1.1 | Build signed release APK | Ready |
| 1.2 | Side-load APK to test devices | Ready |
| 1.3 | Run automated test suite (63 unit + 30 DB tests) | Ready |
| 1.4 | Run 50-checkpoint manual test plan with 2 phones | Pending execution |
| 1.5 | Monitor Supabase + Firebase logs for unexpected errors | During testing |
| 1.6 | Fix any bugs discovered during Beta | Reactive |

### 2.2 Client Tasks

| # | Task | Status |
|---|------|--------|
| 1.7 | Identify **10–20 trusted Beta testers** (drivers + load owners) | Pending |
| 1.8 | Coordinate Beta tester onboarding (WhatsApp group, instructions) | Pending |
| 1.9 | Collect Beta feedback and prioritize fixes with development team | Pending |

### 2.3 Joint Tasks

| # | Task |
|---|------|
| 1.10 | Define success criteria for Beta (e.g., 50 successful trips, zero data loss incidents) |
| 1.11 | Decide whether to add any quick UX improvements based on Beta feedback before public launch |

---

## 3. Phase 2 — Legal & Compliance (Week 2)

**Goal:** Meet all Indian regulatory and Google Play Store policy requirements.

### 3.1 Legal Documents

| # | Document | Owner | Status |
|---|----------|-------|--------|
| 2.1 | Terms & Conditions — lawyer review | Client | Draft delivered, awaiting legal review |
| 2.2 | Privacy Policy — drafting + lawyer review | Joint | Pending |
| 2.3 | Refund Policy (when payments are added) | Client | Out of Beta scope |
| 2.4 | Grievance Officer appointment (mandatory under IT Act 2000) | Client | Pending |

### 3.2 Required Client Inputs

The client must provide the following details before T&Cs and Privacy Policy can be finalized:

1. **Registered company name** (as on MoA/AoA)
2. **Registered office address**
3. **GSTIN** (if applicable)
4. **Grievance Officer name + email + contact**
5. **Support email and phone number** (will be displayed in app)
6. **Cancellation policy preferences** (free? ₹50 fee? Free during Beta?)
7. **Arbitration city** (Mumbai? Pune?)
8. **Court jurisdiction city**

### 3.3 Government / Regulatory

| # | Item | Owner |
|---|------|-------|
| 2.5 | Verify GST registration is in place | Client |
| 2.6 | Driver background check policy (if any required by transport ministry) | Client / Legal |
| 2.7 | Insurance documentation framework (Goods-in-Transit recommendation) | Client |

---

## 4. Phase 3 — Production Infrastructure (Week 2, parallel)

**Goal:** Move from free-tier development plans to paid production plans.

### 4.1 Service Upgrades (Required)

| Service | Free Tier Limit | Production Plan | Monthly Cost | Owner |
|---------|----------------|------------------|--------------|-------|
| Supabase | Auto-pauses after 1 week idle | Pro | ~₹2,100 / $25 | Client (billing) |
| Firebase Auth (SMS OTP) | 10,000 free/month | Blaze (pay-as-you-go) | ~₹0.80 / SMS | Client (billing) |
| Google Maps API | $200 free/month | Billing enabled | ~₹4,000 / $50 estimated | Client (billing) |
| **Total estimated infrastructure** | | | **~₹6,000 – ₹10,000 / month** | |

### 4.2 Monitoring & Observability

| Tool | Purpose | Cost | Owner |
|------|---------|------|-------|
| Firebase Crashlytics | Crash reporting (already in Firebase) | Free | Development |
| Supabase Logs | Database query monitoring | Included in Pro | Development |
| Google Play Console — Vitals | App performance metrics | Free | Development |

### 4.3 Client Account Setup

| # | Item | Owner | Cost |
|---|------|-------|------|
| 3.1 | Google Play Console developer account | Client | $25 one-time |
| 3.2 | Stripe / Razorpay merchant account (for future payment integration) | Client | Free signup |
| 3.3 | Domain purchase (e.g., tripjio.com) for website + email | Client | ₹1,000/year |

---

## 5. Phase 4 — Play Store Submission (Week 3)

**Goal:** Submit the app to Google Play Store for review.

### 5.1 Required Store Listing Assets

| Asset | Specification | Owner | Status |
|-------|--------------|-------|--------|
| App icon | 512×512 PNG | Client design | Pending |
| Feature graphic | 1024×500 PNG | Client design | Pending |
| Screenshots — Phone | 4 to 8, at least 1080px wide | Joint | Pending |
| Promo video (optional) | YouTube link | Client | Optional |
| Short description | 80 characters | Joint | Pending |
| Long description | 4000 characters | Joint | Pending |
| App category | "Maps & Navigation" or "Business" | Joint | Pending |

### 5.2 Required Forms in Play Console

| Form | What it asks | Owner |
|------|-------------|-------|
| Data Safety | What data we collect (location, phone, FCM token) and why | Development |
| Content Rating | Questionnaire about app content | Joint |
| Target Audience | Age groups (18+ for our app) | Client |
| Privacy Policy URL | Link to hosted Privacy Policy | Client |
| Government App Declaration | We are not | Client |
| Ads Declaration | We don't show ads in app | Client |
| Background Location Justification | "Required to track trip progress for load owners' safety and on-time delivery" | Development |
| Foreground Service Justification | "Background GPS during active trip" | Development |

### 5.3 Technical Submission

| # | Task | Owner |
|---|------|-------|
| 4.1 | Create release keystore (.jks file) | Development |
| 4.2 | Sign Android App Bundle (AAB) — Play Store's required format | Development |
| 4.3 | Upload AAB to Play Console — Internal Testing track first | Development |
| 4.4 | Add internal testers (Client + Dev team) | Joint |
| 4.5 | After internal validation, promote to Closed Testing | Joint |
| 4.6 | After Closed Testing, promote to Production | Joint |
| 4.7 | Google review process | 2–7 days |

---

## 6. Phase 5 — Public Launch (End of Week 3)

| # | Task | Owner |
|---|------|-------|
| 5.1 | Final smoke test on production APK from Play Store | Joint |
| 5.2 | Announce launch (social media, WhatsApp, etc.) | Client |
| 5.3 | Monitor for 48 hours intensively (crashes, errors, support requests) | Joint |
| 5.4 | Have a rollback plan ready (Play Console supports staged rollouts) | Development |

---

## 7. Estimated Costs Summary

| Category | One-Time | Recurring (Monthly) |
|----------|----------|----------------------|
| Play Console account | ₹2,100 ($25) | — |
| Domain purchase | ₹1,000 | — |
| Lawyer review of T&Cs + Privacy Policy | ₹8,000 – ₹15,000 | — |
| Logo + Play Store graphics design | ₹3,000 – ₹10,000 (or in-house) | — |
| **One-Time Subtotal** | **₹14,100 – ₹28,100** | — |
| Supabase Pro | — | ₹2,100 |
| Firebase Auth (SMS) | — | ₹2,000 (estimated, depends on signups) |
| Google Maps API | — | ₹4,000 (estimated) |
| **Recurring Subtotal** | — | **₹8,100 / month** |

> Costs scale with user growth — heavy SMS or Maps usage will increase Firebase/Google bills.

---

## 8. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Google rejects app (background location justification weak) | Medium | High | Detailed justification document drafted with technical & business reasoning |
| Beta finds critical bug | Medium | High | 1-week buffer in timeline, dev team on standby |
| Driver onboarding slower than expected | Medium | Medium | Pre-recruit Beta testers via client's network |
| SMS costs spike (real users) | Low | Medium | Set Firebase budget alerts at ₹5,000/month |
| Supabase outage during launch | Low | High | 99.9% SLA on Pro; monitor status.supabase.com |

---

## 9. Decision Points for Client

Before proceeding with Phase 2, the client must confirm:

1. ✅ **Approval to proceed** with the 3-week timeline
2. ✅ **Approval of estimated costs** (one-time + recurring)
3. ✅ **Provision of inputs** listed in Section 3.2 (within Week 1)
4. ✅ **Identification of Beta testers** (within Week 1)
5. ✅ **Brand assets** (logo, color guidelines if specific)

---

## 10. Final Go/No-Go Checklist (End of Week 3)

```
[ ]  All 50+ manual tests passing on real phones
[ ]  All 63 unit tests passing
[ ]  All 30+ database tests passing
[ ]  Static analysis clean
[ ]  Privacy Policy finalized + hosted
[ ]  Terms & Conditions finalized + hosted
[ ]  Grievance Officer appointed and contact info live
[ ]  Supabase on Pro plan
[ ]  Firebase on Blaze plan
[ ]  Google Maps billing enabled
[ ]  Release keystore generated and securely stored
[ ]  AAB uploaded to Play Console
[ ]  Data Safety form completed
[ ]  Content rating completed
[ ]  Background location justification accepted by Google
[ ]  App approved by Google Play review team
[ ]  Internal Testing track passes
[ ]  Closed Testing track passes (small group)
```

When all 18 boxes are checked → ready for public launch. 🚀

---

## 11. Communication Plan

| Cadence | Format | Participants |
|---------|--------|--------------|
| Daily during Phase 1 | WhatsApp updates | Client + Dev |
| Weekly during Phase 2 & 3 | Status report email | Client + Dev |
| Pre-launch day | Final go/no-go call | Client + Dev |
| Launch day + 48 hours | Real-time monitoring channel | Client + Dev |

---

**Document prepared by:** Development Team
**Date:** [Insert date]
**Version:** 1.0
