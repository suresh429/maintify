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

**Maintify** is a Flutter apartment maintenance management app. **No backend — mock data only.** Uses Provider + ChangeNotifier for state management, portrait-only orientation.

### Role System

Three roles drive the entire app structure: `superAdmin`, `admin` (apartment president), and `user` (resident). Role is determined at login via `AuthProvider`. `DashboardRouter` (`lib/screens/dashboard_router.dart`) watches `AuthProvider` and routes accordingly.

**Mock credentials** (password: `123456`):
- `superadmin@test.com` → SuperAdmin
- `admin@test.com` → Admin (G. Srikanth, Flat 402, Samhith Residency)
- `user@test.com` → User (Rohit, Flat 101)

**First-login flow:** New users (created via admin/super-admin) have `isFirstLogin: true` and an auto-generated password. `DashboardRouter` wraps their dashboard in `_FirstLoginWrapper`, which opens a non-dismissible `showChangePasswordSheet(isFirstLogin: true)` via `addPostFrameCallback`. After password change, `isFirstLogin` becomes false and the wrapper is removed.

### Provider Stack

All 6 providers registered at root in `main.dart`:

| Provider | Responsibility |
|---|---|
| `AuthProvider` | Login/logout, current user, role, `changePassword`, `generateForgotPassword` |
| `ApartmentProvider` | Apartment CRUD, president assignment |
| `DashboardProvider` | Aggregated stats for admin/superadmin dashboards |
| `BillProvider` | Bills (apartment-wide) and payments (per-flat) |
| `UserProvider` | Member filtering, search, `createAdmin`, `addMember` |
| `ComplaintProvider` | Complaint lifecycle + message threads |

Providers simulate network delays (typically 400–1200ms) and expose `isLoading`/`initialized` flags for shimmer states.

### Data Layer

Mock data lives as static lists in model files. **No persistence — resets on restart.**

- `lib/models/user_model.dart` — `MockUsers`: 11 users (1 super-admin, 1 admin, 9 residents), all in `apt1`
- `lib/models/apartment_model.dart` — `MockApartments`: 1 apartment — "Samhith Residency", Hyderabad, 10 flats, `presidentId: 'u2'`
- `lib/models/bill_model.dart` — `MockBillData` (4 bills), `MockPayments`
- `lib/models/complaint_model.dart` — `MockComplaints`

Cross-provider consistency: mutations call both the provider's `_list` AND the static `MockFoo.all` so that other providers reading the static stay in sync (e.g. `MockUsers.all.add(newUser)` in `addMember`).

**Bill logic:** `BillModel` is apartment-wide; `BillPayment` is per-flat. `perFlatShare = totalAmount / totalFlats`. Creating a bill auto-generates a `BillPayment` for each flat.

**Flat capacity:** `UserProvider.memberCountForApartment(aptId)` is checked against `ApartmentModel.totalFlats` before adding members. The UI hides the Add button when full.

### Authentication & Password System

- `UserModel` stores `password` (plain text for mock), `isFirstLogin`
- `AuthProvider.login()` does live lookup via `MockUsers.findByEmail` + password match
- `AuthProvider.changePassword({currentPassword, newPassword})` — validates current, updates both `_currentUser` and `MockUsers.all`
- `AuthProvider.generateForgotPassword(email)` — generates a new password and updates `MockUsers`; shown to super-admin/admin in a credentials dialog
- `UserProvider.createAdmin(...)` → returns `({String id, String password})` with auto-generated password, sets `isFirstLogin: true`
- `UserProvider.addMember(...)` → returns `String` (password), sets `isFirstLogin: true`
- Password generation lives in `AppUtils`: `generateAdminPassword(aptName)` → `"Adm@Samh1th#X9"`, `generateUserPassword(name, flatNo)` → `"Usr@Rav102#K7"`
- After creation, `AppUtils.showGeneratedCredentials(context, {...})` shows a dialog with Copy Password button

### Screen Layout

```
screens/
├── login_screen.dart          ← AppTextField fields + Forgot Password bottom sheet
├── dashboard_router.dart      ← Role router + _FirstLoginWrapper
├── admin/                     ← 7 screens (dashboard, bills, complaints, users, mark-paid, monthly-bill-detail, transfer-president)
├── super_admin/               ← 6 screens (dashboard, apartments, reports, assign-admin, assign-president, create-apartment)
├── user/                      ← 6 screens (bills, payments, complaints, profile)
└── shared/
    └── chat_screen.dart       ← Complaint message threads
```

### Design System

- **Theme:** Material 3, Poppins font (via `google_fonts`)
- **Colors:** `lib/core/theme/app_colors.dart`
  - `AppColors.paid` = `#22C55E` — green, **status indicators only** (paid bills, success)
  - `AppColors.green` = `#C39A51` — golden/amber, **not for status**
  - Role gradients: `superAdminGradient` (violet), `adminGradient` (blue), `userGradient` (gold → dark navy)
- **Role theming:** `RoleTheme.of(UserRole.x)` → `.gradient`, `.primary`, `.secondary`
- **Spacing:** `AppConstants` in `lib/core/constants/app_constants.dart`
- **Loading states:** `ShimmerLoading` widget

### Widget Library (`lib/widgets/`)

14 shared widgets — always check before building a new component:

| Widget | Purpose |
|---|---|
| `AppTextField` | **Universal form field** — `OutlineInputBorder` + floating label. Use for ALL form inputs. Accepts `focusColor` for role-specific border color. Replaces all bare `TextFormField` usage. |
| `showChangePasswordSheet(context)` | Bottom sheet for changing password. `isFirstLogin: true` makes it non-dismissible. |
| `CommonButton` | Gradient primary button with loading state |
| `DashboardCard` | Stat summary card |
| `BillCard` | Bill display card |
| `StatusChip` | Paid/Pending/Overdue chip |
| `UserTile` | Member list item |
| `ApartmentHeader` | Apartment info banner |
| `MaintifyLogo` | App logo widget |
| `ShimmerLoading` | Loading skeleton |
| `BottomSheetContainer` | Standard bottom sheet wrapper |
| `PillFilterBar` | Horizontal filter pill row |
| `ChatBubble` / `ChatInputField` | Complaint chat UI |

### Bottom Sheet Rules

All bottom sheets must use:
```dart
showModalBottomSheet(
  isScrollControlled: true,
  ...
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
