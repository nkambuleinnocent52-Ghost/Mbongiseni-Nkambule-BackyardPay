# BackyardPay 1.0.5 — landlord assigns the room

The landlord creates the actual rental using an available room, move-in date and agreed property charges. The tenant uses that rental’s private JOIN- invitation once to create their login. Registration no longer asks for a room or accepts a public property code. Future logins use email and password.

The Supabase signup trigger also enforces this rule: invalid, reused, ended-rental invitations and room metadata cannot create a tenant account. Claiming an invitation links the existing rental without changing its room, start date, rent, deposit or payment history. Existing accounts keep working. The landlord can copy the private invitation from the unlinked tenant’s rental details. Invitations must be shared privately; SMS is not sent automatically.

## Update the deployed app

1. Open `downloads/BackyardPay-Invitation-Update.sql`, copy its SQL into the existing Supabase SQL Editor and run it. This requires the existing research/deposit setup used by version 1.0.3 or 1.0.4; do not reset the database or Auth.
2. Download `downloads/BackyardPay-Netlify-web.zip` and upload it to the existing Netlify project. Refresh the application.
3. As landlord, add the tenant record using an available room, open their rental and copy their private invitation. The tenant enters this invitation during registration, with no room selection.

The new registration screen checks that the backend update exists before submitting a tenant signup. The old web app’s public-code signup will be rejected after the SQL update; deploy the new ZIP immediately afterwards. Other existing logins continue normally.

## Verification

Database checks cover public-code rejection, room tampering, invitation reuse, preserved rental charges/history and scoped tenant access. Flutter tests cover registration metadata, rejection before network calls, the room-free registration screen and existing rental functionality. Browser verification uses simulated Supabase transport; production database activation and real account creation must be checked after applying the SQL.

[Recorded check results](Netlify-1.0.5-checks.md).
