## Connected Supabase project
VendaRides has been connected to project `xzveiqkhiwddxmouknqx`. The database schema, RLS policies and booking RPCs were applied to this project on 27 October 2026. **Do not run `sql/001_schema.sql` again on this project** because its policies/functions have already been installed.

### Remaining steps
1. Supabase Auth Site URL is `https://vendarides.netlify.app/`. Allowed return URLs are that root URL, `https://vendarides.netlify.app/?auth=confirm`, and `https://vendarides.netlify.app/#account`. Keep these settings aligned with `EMAIL_CONFIRMATION_URL` in `JavaScript.js`.
2. Deploy this folder to Netlify and test sign-up, email verification, profile creation, ride requests, driver approval, trip publishing, booking request, acceptance, cancellation, and review with separate test users.
3. Complete administrator verification and transport/legal compliance before allowing paid trips.
4. Do not approve a driver or vehicle without checks.

# VendaRides • RI SHUMELA VENDA

Mobile-first HTML/CSS/vanilla JavaScript PWA with Supabase Auth, PostgreSQL-backed trips, booking requests, parcel requests, driver/vehicle onboarding, emergency contacts, incident reporting and an earnings estimator.

## Quick start
1. Create a Supabase project.
2. Run `sql/001_schema.sql` in the SQL Editor. Review every policy before using real data.
3. Enable email authentication and configure your production Site URL / redirect URLs in Supabase Auth.
4. Edit `config.js` with **only** the public Supabase URL and publishable key. Never use a service-role or secret key in browser code.
5. Serve locally with `python3 -m http.server 8080` and visit `http://localhost:8080`. PWA installation requires HTTPS or a supported localhost environment.
6. Deploy the entire folder to Netlify (the included `netlify.toml` has static hosting settings). Update Auth redirect URLs to your deployed domain.

## Important status
This is a **functional foundation**, not a legally or operationally certified production transport marketplace. Live database flows need your Supabase project and testing. No driver can publish trips until an administrator has manually verified the driver and vehicle. Admin verification UI is not included. Use the Supabase Dashboard to review and set `driver_profiles.verified` and `vehicles.approved` only after real checks and approvals.

## What works after setup
- Sign up, email confirmation, login, password recovery, profiles
- Search published trips from Supabase, create booking requests, accept/decline/cancel and complete bookings with database RPCs
- Post and close ride requests, post parcel requests
- Driver application and vehicle submission (pending verification)
- Trip publishing for approved drivers and approved vehicles
- Trip reviews for completed bookings
- Emergency contacts, incident reporting, current-location share using native share/maps
- PWA manifest, offline fallback, responsive layout, fare and earnings estimator

## Not yet implemented
- Secure document verification/upload, real-time location tracking, parcel acceptance/delivery, payment collection, route-specific fare management, full Tshivenda translations, regulatory approvals, and full automated browser coverage. Background push awaits credential activation.
- Current pricing RPC uses standard full-route fares; it does not distinguish shorter trips or provide gate detour quotes.
- Fuel/toll/maintenance figures in the calculator are editable **examples**, not current verified prices.
- Driver onboarding is gated for safety. Do not approve a driver without appropriate compliance checks.

## Testing checklist
- Create two accounts; confirm email, login and profile updates.
- Verify one driver and vehicle manually after compliance review.
- Publish a future trip; search with another account; request seats.
- Accept booking; verify available seats decrease; cancel confirmed booking; verify seats are restored.
- Test concurrent accept requests and row access restrictions in your own Supabase environment.
- Test Android install, iOS Add to Home Screen, and offline fallback.
- Complete legal, security, privacy and transport compliance review before launch.

© 2026 VendaRides • Developed by Apex Technical Solutions.


## Opening the website locally (important)
The previous build used absolute / paths, so double-clicking index.html showed an unstyled page. All site asset paths are now relative. For full JavaScript functionality, serve the site over HTTP because browser security blocks ES module imports on file://. On Windows double-click START-WEBSITE.bat (requires Python), or run `python -m http.server 8000` inside this directory and visit http://localhost:8000. For production upload the CONTENTS of this folder to Netlify. Do not upload the parent folder as publish root. External Supabase JS dependency requires internet.


## October 2026 dashboard and email design update

- Dashboard is now a dedicated full-screen application mode at `/#account`, separate from the marketing landing sections.
- Signing in opens the dashboard. Verified returning sessions also open the dashboard.
- The dashboard contains navigation, Font Awesome icons, guided onboarding and a back-to-top control.
- Upload the complete updated folder to Netlify to deploy. Service-worker cache updated to v2.
- **Email branding requires a manual Supabase dashboard step:** Open Authentication > Email Templates > Confirm signup, switch to the HTML/source editor, and paste the entire contents of `confirmation-email.html`. Save, then send a test signup to an address you control. This file is NOT automatically activated in Supabase.
- In Authentication > URL Configuration, set Site URL to `https://vendarides.netlify.app` and allow `https://vendarides.netlify.app/**` as a redirect.
- Test both desktop and mobile. Hard-refresh if an installed PWA still shows the older version.
- This is not an audited production release; driver verification, privacy/terms, booking lifecycle and security still require testing.


## Administrator console (new)

- Visit `/admin.html` or use the low-visibility **Staff access** footer link.
- Admin sign-in uses the existing Supabase email/password authentication. No public admin signup exists.
- Backend admin permissions are enforced using trusted Supabase `auth.users.raw_app_meta_data.vendarides_role = "admin"`. Do **not** set this in user metadata or client JavaScript.
- Database migration: `sql/002_admin.sql` (already applied to the connected VendaRides Supabase project).
- To designate the FIRST administrator, identify the verified account email in Supabase Authentication → Users, and grant the role via a trusted database/admin operation. Do not guess an account or promote everyone. Example for a **verified, exact email** (replace placeholder):

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb) || '{"vendarides_role":"admin"}'::jsonb
where email = 'EXACT-ADMIN-EMAIL-HERE';
```

- After the grant, sign out and sign in again to refresh the JWT.
- The console reviews drivers, vehicles, trips, bookings, and incident reports; it can approve/revoke drivers and vehicles and writes an audit log.
- Driver/vehicle verification requires manual review of applicable licences, roadworthiness, insurance, and operating permits. The console does not yet provide secure document uploads or an automated verification service.
- No service-role or secret keys belong in the website files.

## Authentication regression checks
Run `node --test auth-flow.test.cjs`. These mocked checks cover confirmation callbacks, expired links, local sign-out, signup redirect options, login, existing sessions, and preserving the password-reset route. They do not verify email delivery.

For a live check, register with an inbox permitted by the configured email provider, open the new confirmation email, verify the existing sign-in form appears with “Email confirmed”, then sign in and verify the dashboard and sign-out. Custom HOSTAFRICA SMTP is configured for vendarides@xabahygienesolutions.co.za. Previously issued links may contain the old localhost destination; use a fresh confirmation email for testing.

## Community, photos and journey communication (November 2026)
- Private JPEG photo storage, user-controlled community profiles, driver/vehicle cards and pickup recognition prompts.
- Only accepted-booking participants can chat. Phone and WhatsApp details are shared explicitly by the owner in chat.
- RLS-protected notifications, watched routes, driver request alerts and pickup-status updates. Accepted matching bookings close open ride requests.
- Realtime subscriptions for trips, bookings, requests, notifications and messages. Departure reminders are deduplicated.
- Background Web Push worker and service worker handlers are implemented but remain disabled pending approval of the private Netlify credential transfer. `PUSH_DELIVERY_READY` is false and the worker RPC grants to anon are revoked. To activate, install the prepared environment variables privately, grant the worker token gateway execute to anon only, set the readiness flag true and redeploy. Never publish the private VAPID key or worker token.
- Browser-supported install prompts open from the Install button. iPhone installation still follows the browser's Add to Home Screen flow.
- `npm test` runs the frontend/security-helper regressions. `community-db.test.sql` runs rollback-only RLS/lifecycle checks with existing fixture identities. It must be run as the database administrator and never partially committed.
- `npm run build` creates a static allowlisted dist directory, excluding backend code, tests, SQL, and dependencies.
