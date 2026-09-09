# Apartment / Site Manager App — Mobile Plan

A mobile-first phone app built for **one user**: the apartment / site manager.
Not a portal for tenants, landlords, or accountants — a pocket operations tool
that the manager carries on-site every day.

## 1. Objectives

- Give the manager every site operation in their pocket.
- Cut the chaos of calls, WhatsApp threads, and sticky notes into one workflow.
- Drive maintenance, inspections, and tenant requests to completion and track them.
- Flag rent arrears, lease expiries, and unit status at a glance.
- Work offline on-site, sync when back online.
- One building or a portfolio — same tool.

## 2. Who This Is For

- **Primary:** Apartment / site manager (building management, leasing office).
- **Secondary:** On-site maintenance staff they dispatch to (lightweight, read/update work orders).
- No landlord portal, no tenant self-service, no finance suite in v1.

## 3. Core Modules (manager-first)

### Dashboard & Site Overview
- Units, occupancy, vacancies, rent status at a glance.
- Active work orders and overdue items.
- Today's task list and notifications.

### Units & Tenants (view + act, not full CRM)
- Unit list: status (vacant/occupied/maintenance), floor, specs, photos.
- Tenant quick-view: lease dates, rent paid/owed, contact.
- Move-in / move-out checklists and condition reports with photos.

### Maintenance & Work Orders (the heart of the app)
- Receive tenant requests (category, priority, photo, description).
- Create, assign, and dispatch work orders to maintenance staff.
- Track status: open → in progress → completed (with photo proof).
- Log costs and log preventive maintenance schedules.

### Inspections & Condition Reports
- Scheduled inspection rounds with digital checklists.
- Photo-based condition reports per unit.
- Flag issues straight into work orders.

### Rent Status (read-only, no gateway)
- Live arrears, paid, due lists per unit.
- Lease expiry alerts and reminders.
- Rent *collection* stays in their existing financial tool v1.

### Communication
- One-to-one chat with tenants and staff.
- Push notifications: new requests, overdue work, lease expiry, inspection due.

## 4. Key Design Goals

- **Mobile-first, thumb-friendly.** Large tap targets, big status chips, swipe to act.
- **Offline-first.** Log work, snap photos, tick checklists with no signal; sync later.
- **Photo-forward.** Every work order and inspection end with photo proof.
- **Dead simple to start.** < 3 taps from request to a dispatched job.

## 5. Tech Direction

- **Client:** React Native / Expo or Flutter (iOS + Android from one codebase).
- **Backend:** TypeScript (NestJS) or Python (FastAPI) REST. PostgreSQL, Redis, S3 for photos.
- **Auth:** JWT + role guard (Manager > Staff).
- **Push:** FCM/APNs. Photos via S3 with offline queue and retry.
- **Integrate, don't build:** chat, push, photo upload. Keep payments out of v1.

### Core Data Entities
`Manager/StaffUser` · `Property` → `Unit` · `Tenant` (light) ·
`WorkOrder` ↔ `MaintenanceRequest` · `Inspection` → `ConditionReport` ·
`Document` · `AuditLog`

## 6. Rollout Plan (MVP first)

**Phase 1 — the killer slice (vertical):**
Sign in → see unit list + dashboard → tenant request comes in → create/dispatch
work order → staff marks in progress → completes with photo → manager sees it done.

**Phase 2:** Offline-first work, inspection rounds + condition reports,
Notifications, rent/lease status view, staff management.

**Phase 3 (later):** Tenant self-service portal, online rent collection,
reports/analytics, multi-building portfolio view.

Deliver Phase 1 before anything else. A work order closed with a photo, start
to finish, on the phone — that's the product.

## 7. Compliance Basics

- Data protection (GDPR/CCPA) and photo/tenant-data retention.
- Launch in one market first; keep jurisdiction-specific rules out of v1.