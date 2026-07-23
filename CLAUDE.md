# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app
flutter run

# Build
flutter build apk
flutter build ios

# Lint
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Get dependencies
flutter pub get

# Deploy Cloud Functions
firebase deploy --only functions

# Install Cloud Functions dependencies
cd functions && npm install
```

> `test/widget_test.dart` contains a pre-existing compile error (references `MyApp` which doesn't exist). This is not introduced by changes — ignore it.

## Architecture

**Maintify** is a Flutter apartment maintenance management app backed by **Firebase (Firestore + Auth)**. Uses Provider + ChangeNotifier for state management, portrait-only orientation.

### Role System

Three roles drive the entire app structure: `superAdmin`, `admin` (apartment president), and `user` (resident). `UserRole` is defined in `lib/core/theme/role_theme.dart` — **not** in `user_model.dart`. Role is determined at login via `AuthProvider`. `DashboardRouter` (`lib/screens/dashboard_router.dart`) watches `AuthProvider` and routes accordingly.

**Test credentials** (seeded via `DbSeeder` on first launch):
- `superadmin@test.com` / `super@123` → SuperAdmin (only seeded account — no mock apartments/users/bills)

**First-login flow:** New users have `isFirstLogin: true` and an auto-generated password. `DashboardRouter` wraps their dashboard in `_FirstLoginWrapper`, which opens a non-dismissible `showChangePasswordSheet(isFirstLogin: true)` via `addPostFrameCallback`. After password change, `isFirstLogin` becomes false in both Firebase Auth and the Firestore user doc.

### Provider Stack

All 10 providers registered at root in `main.dart`. Provider files live in `lib/` root (e.g. `lib/auth_provider.dart`) except `ThemeProvider` which is at `lib/providers/theme_provider.dart`:

| Provider | Responsibility |
|---|---|
| `AuthProvider` | Login/logout, current user, role, `changePassword`, `generateForgotPassword` — delegates to `FirebaseAuthService` |
| `ApartmentProvider` | Apartment CRUD, president assignment (batch writes), `pending_*` migration |
| `DashboardProvider` | Aggregated stats — reads from `MockXxx` statics (kept in sync by other providers via `replaceAll()`) |
| `BillProvider` | Bills (apartment-wide) and payments (per-flat), Firestore streams |
| `UserProvider` | Member filtering/search (`searchUsers`, `residentsForApartment`, `membersForApartment`), `toggleUserStatus`, `updatePresidentRoles` |
| `ComplaintProvider` | Complaint lifecycle + message threads |
| `MeetingProvider` | Meeting CRUD, schedules notifications via `NotificationProvider` |
| `NotificationProvider` | In-app notifications, Firestore-backed, `startListening(role)` |
| `RegistrationProvider` | Self-registration: president self-creates apartment or activates super-admin-created one; resident direct signup with email verification |
| `ThemeProvider` | Dark/light mode toggle; persists `isDarkMode` flag to Hive `'session'` box under key `isDarkMode` |

Providers that use Firestore streams call `startListening(...)` from `DashboardRouter` after login. They cache data locally and call `notifyListeners()` on stream updates.

### Data Layer: Firestore + Mock Static Sync

All live data lives in Firestore. Mock statics (`MockUsers`, `MockApartments`, `MockBillData`) exist **only for `DashboardProvider`**, which cannot hold Firestore streams of its own. Every provider's stream listener calls `MockFoo.replaceAll(list)` to keep statics in sync.

**Models** live in `lib/models/`. Key ones: `user_model.dart`, `bill_model.dart`, `apartment_model.dart` (now has `type`, `address`, `towerCount`, `towerNames`, `presidentFlat` fields), `flat_model.dart` (see below).

**Key Firestore collections:**
- `users/` — real Firebase Auth UID as document ID
- `apartments/`, `bills/`, `payments/`, `complaints/`, `meetings/`, `notifications/`
- `flats/` — individual flat docs, auto-generated at apartment creation. Doc ID: `${aptId}_${flatNumber}`. Fields: `flatNumber`, `tower` (null for non-gated), `status` (`available`|`occupied`), `residentId`, `residentType` (`President`|`Resident`|null), `apartmentId`.
- `_meta/seeded` — guards `DbSeeder` from re-running

**`DashboardProvider` important note:** Its stats getters read from `MockXxx` statics only. This is intentional — it's kept accurate because `UserProvider`, `ApartmentProvider`, and `BillProvider` all call `replaceAll()` in their stream listeners.

**Bill logic:** `BillModel` is apartment-wide; `BillPayment` is per-flat. Creating a bill auto-generates a `BillPayment` for each flat. Bills now contain multiple `BillCategory` items with per-category split types. `BillModel.perFlatShare` sums contributions across all categories. `BillModel.eligibleCount` = total flats minus `excludedUserIds`. Excluded residents pay ₹0 and don't count toward splits.

### Bill Model: Multi-Category Architecture

`BillModel` contains a `categories` list of `BillCategory` objects. Each category has a split type:

| Type | Behavior |
|---|---|
| `common` | `totalAmount` split equally across all eligible flats |
| `hybrid` | `defaultAmount` per flat, with per-user overrides via `userOverrides` map |
| `individual` | Fully custom — only `userOverrides` entries owe anything |

`BillCategory.amountForUser(userId, eligibleCount)` returns the computed amount for a resident. Predefined category names: Maintenance, Water, Lift, Security, Parking, Amenities, Garbage, Other.

**Bill editing:** `showEditBillSheet(context, bill, residents)` opens a `DraggableScrollableSheet` (initial size 0.92) from `lib/screens/admin/edit_bill_sheet.dart`. Admins can modify items, split types, per-resident overrides, excluded residents, and due date. On save, only **unpaid** `BillPayment` records are updated — paid records remain untouched. Entry point: edit button in `monthly_bill_detail_screen.dart`.

**`BillProvider` key methods:** `adminEditBill(billId, categories, dueDate, residents, excludedUserIds)`, `adminDeleteBill(billId)`.

**`MonthlyBillSummary`** (in `bill_provider.dart`): Aggregates all bills in a month for an apartment. Exposes `totalAmount`, `perFlatShare`, `fullyPaidFlats`, `pendingFlats`, `overallStatus`, and helpers `isUserFullyPaid(userId)`, `userPaidDate(userId)`.

### Authentication & User Creation Flow

Login goes through `FirebaseAuthService.signIn()` → standard Firebase Auth. On success, `AuthProvider` writes a unique `sessionId` (timestamp-based) to `users/{uid}.activeSessionId` in Firestore and stores it locally in Hive (`session_{uid}`). A real-time listener (`_startSessionListener`) watches for changes — if another device logs in and overwrites the Firestore sessionId, this device is force-logged out and `sessionExpired` is set to `true`. `LoginScreen` reads this flag to show a one-time "signed out from another device" banner, then calls `clearSessionExpired()`.

`AppUtils.displayFirstName(fullName)` strips leading initials (e.g. "G. Srikanth" → "Srikanth").

**Self-registration flows** (via `RegistrationProvider`, unified entry point `lib/screens/auth/registration_screen.dart`):

`RegistrationScreen` has a segmented button (President / Resident) that switches form fields in-place.

- **President — self-creation (primary path):** New president creates the apartment themselves. Form collects personal info + apartment details (name, type, address, total flats, flat number). Types: `Apartment`, `Villa`, `Gated Community`. Gated Community additionally captures tower count and names (A–Z). On submit: `RegistrationProvider.selfRegisterPresident()` → checks for duplicate apartment → generates collision-safe 8-char code (4 letters from apartment name + 4 random digits) → calls `FirebaseAuthService.selfRegisterPresident()` (creates Auth account + apartment doc + user doc atomically) → auto-generates all `flats/` docs via `generateFlatsForApartment()` (president flat marked `occupied`). Then shows email verification bottom sheet — after verification resolves, shows success sheet with apartment code.

- **President — activation (secondary path):** For apartments pre-created by a super admin (`status: 'waiting_for_president'`). President enters apartment code + their email (must match `apt.presidentEmail`) via `president_signup_screen.dart`. Calls `RegistrationProvider.registerPresident()` → activates apartment → updates president flat's `residentId` in `flats/` → notifies superAdmins.

- **Resident — direct registration:** Resident enters apartment code + flat number. `RegistrationProvider.registerResident()` → validates apartment is `active` → looks up flat in `flats/` collection (must exist and be `available`) → checks email + phone uniqueness → calls `FirebaseAuthService.registerResident()` (creates Auth account + users doc + marks flat `occupied` atomically) → shows email verification bottom sheet → on verify, logs in and shows success sheet. **No pending queue** — residents get immediate access after email verification.

**Email verification:** Both president (self-creation) and resident flows show a non-dismissible bottom sheet after account creation. `RegistrationProvider.checkEmailVerified()` reloads the Auth user and checks `emailVerified`. `resendVerificationEmail()` resends. `abortRegistration()` signs out and cancels, returning to login.

### President Assignment

President data is **denormalized** into the apartment document for consistent reads:

```
apartments/{id}:
  presidentId: <real Firebase UID or null>
  presidentName: <display name>
```

**All screens read `apt.presidentName ?? 'Unassigned'` directly** — never do cross-collection `userProvider.findById(apt.presidentId!)` for display.

`ApartmentProvider.assignPresident(aptId, newPresidentId, newPresidentName, {oldPresidentId})` uses a single `WriteBatch` via `FirestoreService.assignPresidentBatch()` to atomically: promote new president, demote old president, update apartment fields.

**`createApartment()` never accepts `presidentId`** — the initial president is stored as `presidentName` only (null presidentId) because the president doesn't have a real UID until they complete the president signup flow.

**Migration:** `ApartmentProvider.startListening()` detects any apartment with a `pending_*` presidentId and auto-heals it by querying `users/` for the real admin.

### Service Layer (`lib/core/services/`)

| Service | Purpose |
|---|---|
| `FirestoreService` | Singleton — all collection reads/writes. Providers never import `FirebaseFirestore` directly. Includes `updateBill`, `updatePayment`, `deleteBill`, `deleteAllPaymentsForBill`. |
| `FirebaseAuthService` | Wraps `FirebaseAuth`. Handles sign-in, password change, reset email, `registerPresident`, `registerResident`. |
| `FcmService` | FCM token registration (saves to `users/{uid}.fcmToken`). Uses `flutter_local_notifications` to display foreground messages. Uses `navigatorKey` for out-of-tree navigation on notification tap. |
| `DbSeeder` | Seeds Firestore test data on first launch, guarded by `_meta/seeded`. |

**`AppUtils`** (`lib/core/utils/app_utils.dart`): Static helpers — `formatCurrency`, `formatDate`, `formatMonthYear`, `formatDateTime`, `timeAgo`, `showSnackBar` (accepts optional `color` override), `displayFirstName`, `showConfirmDialog`. `showConfirmDialog` renders a bottom-sheet style confirmation with customizable `confirmColor`.

**`navigatorKey`** (`lib/core/navigation_key.dart`): App-wide `GlobalKey<NavigatorState>` registered in `main.dart`. Required for `FcmService` to navigate when no `BuildContext` is available.

**Hive session persistence:** `AuthProvider` uses a Hive box named `'session'` (opened in `main.dart`) to persist `isLoggedIn`, `role`, and `session_{uid}` keys across cold starts. On login these are written; on logout they are deleted. `tryRestoreSession()` (called from `SplashScreen`) re-hydrates `_currentUser` from Firestore and re-starts the session listener.

### Screen Layout

```
screens/
├── login_screen.dart              ← AppTextField + Forgot Password bottom sheet
├── dashboard_router.dart          ← Role router + _FirstLoginWrapper + _StreamStarter (manages listener lifecycle) + provider startListening calls
├── splash_screen.dart
├── auth/
│   ├── registration_screen.dart   ← Unified signup: segmented button switches President / Resident form fields; handles email verification bottom sheet + success sheet
│   └── president_signup_screen.dart ← Activation-only path for super-admin-created apartments (apartment code + email validation)
├── admin/                         ← 9 screens: dashboard, create-bill, edit-bill-sheet, complaints,
│                                    manage-users, mark-paid, monthly-bill-detail, transfer-president,
│                                    admin-profile
├── super_admin/                   ← 6 screens: dashboard, apartments, reports, assign-admin,
│                                    assign-president, create-apartment
├── user/                          ← 7 screens: dashboard, bills, monthly-bill-detail,
│                                    payment-history, i-paid, complaints, profile
└── shared/
    ├── chat_screen.dart           ← Complaint message threads
    ├── notifications_screen.dart
    └── fcm_debug_screen.dart      ← Dev tool: shows device FCM token + test triggers for all 9 notification types
```

### Design System

- **Theme:** Material 3, Poppins font (via `google_fonts`)
- **Colors:** `lib/core/theme/app_colors.dart`
  - `AppColors.paid` = `#22C55E` — green, **status indicators only** (paid bills, success snackbars)
  - `AppColors.green` = `#C39A51` — golden/amber, **not for payment status**
  - Role gradients: `superAdminGradient` (violet), `adminGradient` (blue), `userGradient` (gold → dark navy)
  - Dark mode palette: `darkBackground` (`#0F172A`), `darkSurface` (`#1E293B`), `darkSurfaceVariant` (`#263045`), `darkBorder` (`#334155`), `darkTextPrimary` (`#F1F5F9`), `darkTextSecondary` (`#94A3B8`)
- **Role theming:** `RoleTheme.of(UserRole.x)` → `.gradient`, `.primary`, `.secondary`
- **Text styles:** `AppTextStyles` in `lib/core/theme/app_text_styles.dart` — use `AppTextStyles.heading1/2/3()`, `.subheading()`, `.bodyLarge/Medium/Small()`, `.label()`, `.caption()`, `.amount()`, `.buttonText()`. All accept an optional `color` override.
- **Spacing/constants:** `AppConstants` in `lib/core/constants/app_constants.dart`

### Widget Library (`lib/widgets/`)

Always check before building a new component:

| Widget | Purpose |
|---|---|
| `AppTextField` | **Universal form field** — `OutlineInputBorder` + floating label. Use for ALL form inputs. Accepts `focusColor` for role-specific border color. |
| `showChangePasswordSheet(context)` | Bottom sheet for changing password. `isFirstLogin: true` makes it non-dismissible. |
| `CommonButton` | Gradient primary button with loading state |
| `DashboardCard` | Stat summary card |
| `BillCard` | Bill display card |
| `StatusChip` | Paid/Pending/Overdue chip |
| `UserTile` | Member list item |
| `ApartmentHeader` | Apartment info banner (shows presidentName) |
| `MaintifyLogo` | App logo widget |
| `ShimmerLoading` | Loading skeleton |
| `BottomSheetContainer` | Standard bottom sheet wrapper |
| `PillFilterBar` | Horizontal filter pill row |
| `ChatBubble` / `ChatInputField` | Complaint chat UI |
| `ScheduleMeetingSheet` | Bottom sheet for scheduling meetings |
| `LogoutSheet` | Confirmation bottom sheet for logout |
| `EmptyState` | Empty-state placeholder with icon, title, subtitle, and optional action button |

### Bottom Sheet Rules

All bottom sheets must use:
```dart
showModalBottomSheet(
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SingleChildScrollView(...),
  ),
);
```
Use `Column(mainAxisSize: MainAxisSize.min)` to avoid full-height expansion.

### Change Password Entry Points

- **Admin:** AppBar settings icon (`Icons.settings_outlined`) → `showChangePasswordSheet(context)`
- **User:** Profile screen "More" menu → "Change Password" tile → `showChangePasswordSheet(context)`
- **First login:** `_FirstLoginWrapper` in `DashboardRouter` opens automatically with `isFirstLogin: true`

## Backend: Firebase Cloud Functions (`functions/`)

Node.js v2 functions in `functions/index.js`. Deploy with `firebase deploy --only functions`. Firebase project: `tivastraapp` (see `.firebaserc`).

### Cloud Function Triggers

| Function | Trigger | Action |
|---|---|---|
| `onApartmentCreated` | `apartments/{aptId}` onCreate | Gmail SMTP welcome email to designated president with apartment code |
| `onPresidentRegistered` | `apartments/{aptId}` onUpdate | FCM to all superAdmins when status changes `waiting_for_president` → `active` |
| `onResidentApproved` | `users/{userId}` onCreate (role=`user`) | Gmail SMTP approval email to resident |
| `onPresidentTransferred` | `apartments/{aptId}` onUpdate | FCM to old + new president when `presidentId` changes between two real UIDs |
| `onBillCreated` | `bills/{billId}` onCreate | FCM to all residents in the apartment |
| `onMeetingCreated` | `meetings/{meetingId}` onCreate | FCM to all residents |
| `onComplaintCreated` | `complaints/{complaintId}` onCreate | FCM to apartment admin |
| `onComplaintMessage` | `complaints/{id}/messages/{msgId}` onCreate | FCM to the other party (admin reply → resident; resident message → admin) |
| `onPaymentUpdated` | `payments/{paymentId}` onUpdate | Case A: resident submits → FCM + in-app notification to admin. Case B: admin verifies → FCM + in-app notification to resident |

### Email Service

`functions/services/mailService.js` — exports `sendEmail({ to, subject, html })` using Nodemailer with Gmail SMTP. HTML templates in `functions/templates/welcome_email.js` and `functions/templates/resident_approved_email.js`. Both email functions in `index.js` use idempotency guards (`welcomeEmailSentAt`, `approvalEmailSentAt`) written back to Firestore to prevent duplicate sends on function retry. The Nodemailer transporter is created lazily inside `sendEmail()` — secrets are unavailable at module init time.

### Firebase Secrets (Gmail SMTP credentials)

Credentials are stored in Firebase Secret Manager — never in code. Set them once:
```bash
firebase functions:secrets:set GMAIL_EMAIL
firebase functions:secrets:set GMAIL_APP_PASSWORD
```

### FCM Helpers

- `getTokensForApartment(aptId, role)` — queries users by `apartmentId` + `role`, returns `fcmToken` array
- `getTokensForRole(role)` — same but across all apartments (used for `superAdmin`)
- `sendMulticast(tokens, title, body, data)` — wraps `admin.messaging().sendEachForMulticast()`; FCM `data` payload values must be strings; uses `fcm_fallback_notification_channel` on Android

### In-App Notifications

`writeNotification(title, body, type, targetRole)` writes to the `notifications` Firestore collection. `NotificationProvider` streams pick these up automatically. Only called by `onPaymentUpdated` (Cases A and B).
