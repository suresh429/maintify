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
```

> `test/widget_test.dart` contains a pre-existing compile error (references `MyApp` which doesn't exist). This is not introduced by changes — ignore it.

## Architecture

**Maintify** is a Flutter apartment maintenance management app backed by **Firebase (Firestore + Auth)**. Uses Provider + ChangeNotifier for state management, portrait-only orientation.

### Role System

Three roles drive the entire app structure: `superAdmin`, `admin` (apartment president), and `user` (resident). `UserRole` is defined in `lib/core/theme/role_theme.dart` — **not** in `user_model.dart`. Role is determined at login via `AuthProvider`. `DashboardRouter` (`lib/screens/dashboard_router.dart`) watches `AuthProvider` and routes accordingly.

**Test credentials** (password: `123456`, seeded via `DbSeeder` on first launch):
- `superadmin@test.com` → SuperAdmin
- `admin@test.com` → Admin (G. Srikanth, Flat 402, Samhith Residency)
- `user@test.com` → User (Rohit, Flat 101)

**First-login flow:** New users have `isFirstLogin: true` and an auto-generated password. `DashboardRouter` wraps their dashboard in `_FirstLoginWrapper`, which opens a non-dismissible `showChangePasswordSheet(isFirstLogin: true)` via `addPostFrameCallback`. After password change, `isFirstLogin` becomes false in both Firebase Auth and the Firestore user doc.

### Provider Stack

All 8 providers registered at root in `main.dart`:

| Provider | Responsibility |
|---|---|
| `AuthProvider` | Login/logout, current user, role, `changePassword`, `generateForgotPassword` — delegates to `FirebaseAuthService` |
| `ApartmentProvider` | Apartment CRUD, president assignment (batch writes), `pending_*` migration |
| `DashboardProvider` | Aggregated stats — reads from `MockXxx` statics (kept in sync by other providers via `replaceAll()`) |
| `BillProvider` | Bills (apartment-wide) and payments (per-flat), Firestore streams |
| `UserProvider` | Member filtering, search, `createAdmin`, `addMember` — writes to `pending_users` collection |
| `ComplaintProvider` | Complaint lifecycle + message threads |
| `MeetingProvider` | Meeting CRUD, schedules notifications via `NotificationProvider` |
| `NotificationProvider` | In-app notifications, Firestore-backed, `startListening(role)` |

Providers that use Firestore streams call `startListening(...)` from `DashboardRouter` after login. They cache data locally and call `notifyListeners()` on stream updates.

### Data Layer: Firestore + Mock Static Sync

All live data lives in Firestore. Mock statics (`MockUsers`, `MockApartments`, `MockBillData`) exist **only for `DashboardProvider`**, which cannot hold Firestore streams of its own. Every provider's stream listener calls `MockFoo.replaceAll(list)` to keep statics in sync.

**Key Firestore collections:**
- `users/` — real Firebase Auth UID as document ID
- `pending_users/` — admin-created users before their first login (no Auth account yet)
- `apartments/`, `bills/`, `payments/`, `complaints/`, `meetings/`, `notifications/`
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

Login goes through `FirebaseAuthService.signIn()`:
1. Tries normal Firebase Auth sign-in
2. If `user-not-found` / `invalid-credential` → calls `_promotePendingUser()`:
   - Finds user in `pending_users` by email + tempPassword
   - Creates Firebase Auth account → gets real UID
   - Writes `users/{realUid}` doc (drops `tempPassword`, sets `isFirstLogin: true`)
   - **If role == admin**: patches `apartments/{aptId}` with `presidentId: realUid, presidentName: name`
   - Deletes the `pending_users` doc

`UserProvider.createAdmin(...)` and `addMember(...)` write to `pending_users` (not `users`). They return a generated password to show in `AppUtils.showGeneratedCredentials()`. Password generation: `AppUtils.generateAdminPassword(aptName)`, `generateUserPassword(name, flatNo)`. `AppUtils.displayFirstName(fullName)` strips leading initials (e.g. "G. Srikanth" → "Srikanth").

### President Assignment

President data is **denormalized** into the apartment document for consistent reads:

```
apartments/{id}:
  presidentId: <real Firebase UID or null>
  presidentName: <display name>
```

**All screens read `apt.presidentName ?? 'Unassigned'` directly** — never do cross-collection `userProvider.findById(apt.presidentId!)` for display.

`ApartmentProvider.assignPresident(aptId, newPresidentId, newPresidentName, {oldPresidentId})` uses a single `WriteBatch` via `FirestoreService.assignPresidentBatch()` to atomically: promote new president, demote old president, update apartment fields.

**`createApartment()` never accepts `presidentId`** — the initial president is stored as `presidentName` only (null presidentId) because the admin doesn't have a real UID until first login.

**Migration:** `ApartmentProvider.startListening()` detects any apartment with a `pending_*` presidentId and auto-heals it by querying `users/` for the real admin.

### Service Layer (`lib/core/services/`)

| Service | Purpose |
|---|---|
| `FirestoreService` | Singleton — all collection reads/writes. Providers never import `FirebaseFirestore` directly. Includes `updateBill`, `updatePayment`, `deleteBill`, `deleteAllPaymentsForBill`. |
| `FirebaseAuthService` | Wraps `FirebaseAuth`. Handles sign-in, pending-user promotion, password change, reset email. |
| `FcmService` | FCM token registration (saves to `users/{uid}.fcmToken`). |
| `DbSeeder` | Seeds Firestore test data on first launch, guarded by `_meta/seeded`. |

**Hive session persistence:** `AuthProvider` uses a Hive box named `'session'` (opened in `main.dart`) to persist `isLoggedIn` and `role` keys across cold starts. On login these are written; on logout/password-change they are deleted. `AuthProvider` reads this box at startup to restore session state before Firebase's async auth state resolves.

### Screen Layout

```
screens/
├── login_screen.dart              ← AppTextField + Forgot Password bottom sheet
├── dashboard_router.dart          ← Role router + _FirstLoginWrapper + _StreamStarter (manages listener lifecycle) + provider startListening calls
├── splash_screen.dart
├── admin/                         ← 8 screens: dashboard, create-bill, edit-bill-sheet, complaints,
│                                    manage-users, mark-paid, monthly-bill-detail, transfer-president
├── super_admin/                   ← 6 screens: dashboard, apartments, reports, assign-admin,
│                                    assign-president, create-apartment
├── user/                          ← 7 screens: dashboard, bills, monthly-bill-detail,
│                                    payment-history, i-paid, complaints, profile
└── shared/
    ├── chat_screen.dart           ← Complaint message threads
    └── notifications_screen.dart
```

### Design System

- **Theme:** Material 3, Poppins font (via `google_fonts`)
- **Colors:** `lib/core/theme/app_colors.dart`
  - `AppColors.paid` = `#22C55E` — green, **status indicators only** (paid bills, success snackbars)
  - `AppColors.green` = `#C39A51` — golden/amber, **not for payment status**
  - Role gradients: `superAdminGradient` (violet), `adminGradient` (blue), `userGradient` (gold → dark navy)
- **Role theming:** `RoleTheme.of(UserRole.x)` → `.gradient`, `.primary`, `.secondary`
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
