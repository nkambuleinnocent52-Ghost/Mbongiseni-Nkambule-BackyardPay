# BackyardPay 1.0.4 (build 5): available rooms

The landlord now sees a room-by-room availability grid on the property details and tenant-onboarding pages. The grid names the actual room numbers and shows available/unavailable counts, rather than only a total occupancy figure.

The onboarding room-number text box is replaced with a required **Available room** dropdown containing only eligible room numbers. Changing the move-in date recalculates the choices. A full property has no selectable room and displays an explanation. If a refreshed tenancy record takes the selected room, the selection is cleared and must be made again. The client checks availability again before submitting; the existing database command remains the authoritative check and serialises competing room assignments using the property lock.

Availability follows the existing server rule for a new open-ended tenancy: a room is blocked by a recorded tenancy unless that tenancy's actual handover was before the chosen start date. Planned lease expiry does not free it. Dates are inclusive, so a handover on 7 November makes the room available from 8 November. Historical occupants are counted by room, and records from another property cannot block a room. Past rent debt does not itself occupy a room after actual handover.

Full property availability is landlord-only. Tenant-scoped data must not be used to infer which other rooms are empty, since tenant RLS intentionally hides other tenants' records. Property details no longer show misleading availability inferred from a tenant's partial view. Empty-property deletion remains available only when no tenancy history exists, matching server protection of historical records.

This release keeps security-deposit/prorated-rent previews, reports, private documents and existing accounts/data. No database or Auth/SMTP changes are required for this update on the already activated 1.0.3 backend. Upload the latest **BackyardPay-Netlify-web.zip** to the existing Netlify project, then refresh. Keep ordinary browser/Windows protection enabled.

Validation covers exact available numbers, planned expiry versus actual handover, the inclusive handover date, another property's records, duplicate historical room records, no-room cases, dropdown choices and invalidation when another tenancy takes the selected room. Existing browser tests cover property creation, registration, prorated payment, review, receipt, tenant report/landlord reply and session recovery. These are isolated local checks, not a claim that the owner has already published this release.
