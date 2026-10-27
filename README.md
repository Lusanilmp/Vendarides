## Connected Supabase project
VendaRides has been connected to project `xzveiqkhiwddxmouknqx`. The database schema, RLS policies and booking RPCs were applied to this project on 27 October 2026. **Do not run `sql/001_schema.sql` again on this project** because its policies/functions have already been installed.

### Remaining steps
1. Configure Supabase Auth site URL and redirect URLs for your actual Netlify domain.
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
- Admin dashboard, secure document verification/upload, actual driver and passenger contact exchange, WhatsApp deep links, real-time location tracking, parcel acceptance/delivery, payment collection, push notifications, in-app messages, realtime booking subscriptions, route-specific fare management, full Tshivenda translations, regulatory approvals, full automated tests.
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
