# WaterFix — On-Demand Water Tanker Marketplace (`waterfix-mobile`)

## 1. Project Identity & Configuration
- **Product Name:** WaterFix
- **Internal Project ID:** `waterfix-mobile` (`name: waterfix_mobile` in `pubspec.yaml`)
- **Android Application ID:** `com.waterfix.app` (`APP/android/app/build.gradle.kts`)
- **Frontend:** Flutter + Dart (Riverpod state management, Dio HTTP client, Geolocator GPS, custom-painted vector tanker graphics matching `WaterFix-UI-Screens.pdf`)
- **Backend:** Node.js + Express.js (`APP/backend`)
- **Database:** MongoDB Community Edition running locally on `mongodb://127.0.0.1:27017/waterfix_db`
- **Cost & Licensing:** 100% Free & Open Source (`PKR 0`). Zero paid APIs, zero paid SMS/OTP providers, zero paid map tile keys, and zero external paid AI services.

---

## 2. Prerequisites & Local Environment Setup (Windows)

### Required Tools
1. **Flutter SDK:** Flutter `3.47.x` (Dart `3.13.x`) on `stable` channel.
2. **Android SDK:** Android SDK Platform & Build-Tools `36.0.0` + JDK 17+ (bundled with Android Studio).
3. **Node.js & npm:** Node.js `v20+` or `v24+` and `npm`.
4. **MongoDB Community Edition:** Installed locally as the `MongoDB` Windows Service listening on `127.0.0.1:27017`.

### Environment Variables (`APP/backend/.env`)
```env
PORT=5000
MONGODB_URI=mongodb://127.0.0.1:27017/waterfix_db
JWT_ACCESS_SECRET=waterfix_local_dev_access_secret_key_2026_secure
JWT_REFRESH_SECRET=waterfix_local_dev_refresh_secret_key_2026_secure
JWT_ACCESS_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d
COMMISSION_RATE=0.10
ADMIN_SETTLEMENT_KEY=waterfix_admin_settlement_secret_2026
NODE_ENV=development
```

---

## 3. Starting the Backend & Database Commands

Open PowerShell in `APP/backend`:

```powershell
cd "APP/backend"
npm install

# Optional: Safe development reset (clears all collections so marketplace starts with 0 suppliers)
npm run reset-db

# Start the Express API server on http://0.0.0.0:5000
npm start

# Run Backend Automated Test Suite (Jest + Supertest)
npm test
```

> **Note:** The backend never erases the database automatically at startup. Only `npm run reset-db` clears development records.

---

## 4. Running the Flutter Mobile App & Connecting Devices

Open PowerShell in `APP`:

```powershell
cd "APP"
flutter pub get

# Run static analysis and widget/unit tests
flutter analyze
flutter test

# Run on connected Android Emulator or device
flutter run
```

### Backend URL Configuration (Emulator vs. Physical Android Phone)
- **Android Emulator:** Automatically uses `http://10.0.2.2:5000/api` (which routes to `127.0.0.1:5000` on your Windows laptop).
- **Windows / Web:** Automatically uses `http://127.0.0.1:5000/api`.
- **Physical Android Phone:** `localhost` on a physical phone refers to the phone itself, **not** your laptop. Connect your phone and laptop to the same Wi-Fi network, find your laptop's LAN IPv4 address (`ipconfig`), and either:
  1. Pass `--dart-define=API_BASE_URL=http://<YOUR_LAPTOP_IP>:5000/api` when running/building, **or**
  2. Open the app → **Profile / Account → Help and support** and enter `http://<YOUR_LAPTOP_IP>:5000/api`.

---

## 5. Building the Android APK

### Debug APK
```powershell
cd "APP"
flutter build apk --debug
```
Output path: `APP/build/app/outputs/flutter-apk/app-debug.apk`

### Creating a Signed Release APK Later
1. Generate a signing keystore outside the git repository:
   `keytool -genkey -v -keystore ~/waterfix-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `APP/android/key.properties` (and add `key.properties` and `*.jks` to `.gitignore` — **never commit signing keys or passwords**).
3. Reference `key.properties` in `APP/android/app/build.gradle.kts` under `signingConfigs` and run `flutter build apk --release`.

---

## 6. REST API Reference (`http://localhost:5000/api`)

| Method | Endpoint | Auth / Role | Description |
|---|---|---|---|
| `POST` | `/api/auth/register` | Public | Register Customer or Supplier (normalizes email & `+92` phone) |
| `POST` | `/api/auth/login` | Public | Login with single `identifier` (email or phone) + `password` |
| `POST` | `/api/auth/refresh` | Public | Refresh expired access token using `refreshToken` |
| `POST` | `/api/auth/logout` | Public/Auth | Revoke session token |
| `GET` | `/api/auth/me` | Authenticated | Get current user profile, supplier profile, and saved addresses |
| `PUT` | `/api/auth/me` | Authenticated | Update user profile or recurring delivery schedule preferences |
| `GET/POST` | `/api/addresses` | Authenticated | List or create saved delivery addresses |
| `DELETE` | `/api/addresses/:id` | Authenticated | Delete a saved delivery address |
| `GET/PUT` | `/api/suppliers/me` | `supplier` | View or update supplier dashboard profile & availability |
| `POST` | `/api/suppliers/listings` | `supplier` | Publish tanker listing (`1000`–`5000` L or custom) |
| `PUT/DELETE` | `/api/suppliers/listings/:id` | `supplier` | Update price/availability or remove listing |
| `GET` | `/api/suppliers/discover` | Public/Auth | Discover & rank eligible nearby suppliers (`best_match`, `cheapest`, `fastest`, `best_rated`) |
| `GET` | `/api/suppliers/:supplierId` | Public/Auth | Get supplier public profile, active tanker sizes, and customer reviews |
| `POST` | `/api/bookings` | `customer` | Create booking with idempotency key & stale-price check |
| `GET` | `/api/bookings` | Authenticated | List customer bookings or supplier orders |
| `POST` | `/api/bookings/:id/status` | Authenticated | Transition state (`requested -> accepted -> dispatched -> delivered` or `cancelled`) |
| `GET` | `/api/bookings/:id/tracking` | Participant | Get real-time GPS tracking state (`latitude`, `longitude`, `updatedAt`, `trackingActive`) |
| `PUT/POST` | `/api/bookings/:id/tracking` | Assigned `supplier` | Publish live supplier GPS coordinates during active delivery |
| `POST` | `/api/bookings/:id/tracking/stop` | Assigned `supplier` | Stop live GPS tracking for an order |
| `GET` | `/api/bookings/:id/tracking/stream` | Participant | Server-Sent Events (SSE) real-time stream for order location & status updates |
| `GET` | `/api/bookings/:id/alternatives` | `customer` | Find ranked alternative suppliers after supplier cancellation |
| `POST` | `/api/reviews` | `customer` | Submit 1–5 star rating, tags, and comment for a completed booking |
| `GET` | `/api/wallet` | `supplier` | Get gross earnings, 10% commission charged, outstanding balance, and ledger |
| `POST` | `/api/wallet/settle` | Admin Key | Record authorized manual commission settlement |
| `GET` | `/api/notifications` | Authenticated | List in-app notifications & unread count |
| `POST` | `/api/notifications/read-all` | Authenticated | Mark all notifications as read |

---

## 7. Known Prototype Limitations
1. **Phone/Password Without SMS OTP:** To maintain the PKR 0 budget requirement, phone/password registration and login do not send paid SMS OTP messages and therefore do not verify SIM ownership.
2. **Foreground GPS Tracking:** Live tanker GPS tracking uses `geolocator` while the supplier's WaterFix app is open in the foreground during active deliveries (`accepted`, `dispatched`, `arriving`), streaming real GPS coordinates via the Express backend to `flutter_map`.
3. **Manual Commission Settlement:** Customer payments are Cash on Delivery (paid directly to the supplier). WaterFix records a 10% commission in the auditable ledger upon delivery completion, and settlements are recorded via an administrator-authorized manual settlement workflow.
