# BLASTI

BLASTI is a responsive passenger reservation app for a simulated Sousse pilot. It includes a Vite/React web app, an Expo mobile app in `mobile/`, and a Supabase/PostgreSQL backend.

## Secure setup

The applications require Supabase for account creation, sign-in, persistent reservations, operator accounts, and driver alerts. Without Supabase credentials the web app is a read-only local preview; the mobile app shows the account form but will not create fake accounts or accept fake logins.

1. Create a Supabase project and configure email/password authentication. Keep email confirmation enabled for production and set the project password policy/rate limits in Supabase Auth.
2. Copy `.env.example` to `.env.local` at the repository root and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to the project URL and publishable/anon key.
3. Apply every SQL migration in `supabase/migrations/` in filename order: `202611220001_blasti.sql` through `202611220005_repair_auth_profiles.sql`. Migration 002 installs the Auth-user trigger that creates the corresponding `public.profiles` row; migration 005 repairs profiles for accounts created before that trigger was installed.
4. For mobile, copy `mobile/.env.example` to `mobile/.env` and set `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY` to the same project values.
5. Start the web app with `npm install` and `npm run dev`. Start mobile from `mobile/` with `npm install` and `npm start`.

Never put a Supabase service-role key in either app or any `VITE_`/`EXPO_PUBLIC_` variable. The browser and mobile apps use only the publishable/anon key; row-level security and database functions enforce access.

Passenger sign-up creates a passenger account. Chauffeur accounts are not self-promotable: a trusted administrator must create/verify the Auth user, assign the `operator` role in `public.profiles`, and assign an active vehicle (`public.vehicles.operator_id`). Routes and pilot stations are seeded by migrations. Once provisioned, chauffeurs can create departures in the app. User roles cannot be changed through the client.

The database validates profile names, seat selections, route inputs, departure times, and fares. Fares are constrained to `0–2.50 DT` both in the user interface and PostgreSQL. Reservation writes, cancellation, and waitlist entry use authenticated database functions. Booking rows remain in Supabase after logout and are available again to the same account. Each confirmed reservation creates a persisted notification for the assigned chauffeur; it is delivered in-app in real time while online and remains in the database if the chauffeur is offline.

## Local preview and caveats

Bab Bhar destinations, schedule examples, coordinates, and fares are illustrative. They are not verified transport services. Local preview data is stored in browser/mobile storage, but it does not provide authentication or cross-device bookings. For actual use, configure Supabase and provision verified operators and vehicles. Notifications are in-app/database notifications, not SMS or operating-system push notifications.

Remote Unsplash images require an internet connection; the core screens do not depend on them.
