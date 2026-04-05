# Hitwardhini - Matrimony Application

A premium matrimony application built with Flutter and Supabase, designed to connect individuals for matrimonial purposes with a modern, elegant interface.

## 📱 Features

### Core Features
- **User Authentication** - Secure email/OTP-based authentication via Supabase
- **Profile Management** - Create and manage detailed matrimonial profiles
- **Interest System** - Send, receive, accept, and decline interests
- **Saved Profiles** - Bookmark profiles for later viewing
- **In-App Chat** - Real-time messaging for mutual matches
- **Biodata Viewer** - View uploaded biodata documents/images in-app
- **Gender-Based Matching** - Automatically shows opposite gender profiles

### Premium Features
- **Subscription System** - UPI payment integration for premium access
- **Profile Photo Management** - Upload and update profile photos
- **Real-time Updates** - Live updates for interests, messages, and profile changes

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime)
- **Payments**: UPI India integration
- **UI Framework**: Material Design 3 with custom theming

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.x.x      # Backend & Auth
  google_fonts: ^6.x.x          # Typography
  image_picker: ^1.x.x          # Photo selection
  url_launcher: ^6.x.x          # External links
  webview_flutter: ^4.x.x       # Document viewer
  upi_india: local              # UPI payments
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Supabase account

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-repo/hitwardhini.git
   cd hitwardhini
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   
   Update `lib/main.dart` with your Supabase credentials:
   ```dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

## 🗄️ Database Schema

The application uses Supabase PostgreSQL with the following tables:

### `profiles`
Stores user profile information.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | User ID (from Supabase Auth) |
| `full_name` | TEXT | User's full name |
| `phone_number` | TEXT | Contact number |
| `date_of_birth` | DATE | Date of birth |
| `gender` | TEXT | Male/Female |
| `occupation` | TEXT | Job/Profession |
| `education` | TEXT | Educational qualification |
| `city` | TEXT | Current city |
| `height` | TEXT | Height |
| `marital_status` | TEXT | Never Married/Divorced/Widowed |
| `partner_expectations` | TEXT | Partner preference description |
| `profile_photo_url` | TEXT | Profile photo URL (Supabase Storage) |
| `biodata_url` | TEXT | Biodata document URL |
| `is_paid` | BOOLEAN | Subscription status (default: false) |
| `subscription_expiry` | TIMESTAMPTZ | Subscription end date |
| `razorpay_payment_id` | TEXT | Payment reference ID |
| `created_at` | TIMESTAMPTZ | Profile creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

### `saved_profiles`
Tracks which profiles a user has saved/bookmarked.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Record ID |
| `user_id` | UUID (FK) | User who saved the profile |
| `saved_profile_id` | UUID (FK) | Profile that was saved |
| `created_at` | TIMESTAMPTZ | When the profile was saved |

**Foreign Keys:**
- `user_id` → `profiles.id` (CASCADE)
- `saved_profile_id` → `profiles.id` (CASCADE)

### `interests`
Manages interest requests between users.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Interest record ID |
| `sender_id` | UUID (FK) | User who sent the interest |
| `receiver_id` | UUID (FK) | User who received the interest |
| `status` | TEXT | `pending` / `accepted` / `declined` |
| `created_at` | TIMESTAMPTZ | When interest was sent |
| `updated_at` | TIMESTAMPTZ | When status was last updated |

**Foreign Keys:**
- `sender_id` → `profiles.id`
- `receiver_id` → `profiles.id`

**Constraints:**
- `status` must be one of: `pending`, `accepted`, `declined`

### `messages`
Stores chat messages between mutual matches.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Message ID |
| `sender_id` | UUID (FK) | User who sent the message |
| `receiver_id` | UUID (FK) | User who received the message |
| `content` | TEXT | Message content |
| `is_read` | BOOLEAN | Read status (default: false) |
| `created_at` | TIMESTAMPTZ | When message was sent |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

**Foreign Keys:**
- `sender_id` → `profiles.id` (CASCADE)
- `receiver_id` → `profiles.id` (CASCADE)

### Entity Relationship Diagram

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────┐
│  profiles   │───────│  saved_profiles  │───────│  profiles   │
│             │ 1:N   │                  │ N:1   │             │
│  (user_id)  │       │  user_id         │       │  (saved)    │
└─────────────┘       │  saved_profile_id│       └─────────────┘
       │              └──────────────────┘
       │
       │              ┌──────────────────┐
       │──────────────│    interests     │──────────────│
       │ 1:N          │                  │         N:1  │
       │              │  sender_id       │              │
       │              │  receiver_id     │              │
       │              │  status          │              │
       │              └──────────────────┘              │
       │                                                │
       │              ┌──────────────────┐              │
       └──────────────│    messages      │──────────────┘
         1:N          │                  │         N:1
                      │  sender_id       │
                      │  receiver_id     │
                      │  content         │
                      └──────────────────┘
```

## 🔐 Row Level Security (RLS)

All tables have RLS enabled with the following policies:

### Profiles
- Users can read all paid profiles
- Users can only update their own profile

### Saved Profiles
- Users can only access their own saved profiles
- Users can insert/delete their own saved records

### Interests
- Users can read interests they sent or received
- Users can insert interests they send
- Users can update interests they received (accept/decline)

### Messages
- Users can read messages they sent or received
- Users can insert messages they send
- Users can update messages they received (mark as read)

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point & Supabase init
├── screens/
│   ├── welcome_screen.dart      # Landing & authentication
│   ├── profile_creation_screen.dart  # New user onboarding
│   ├── home_screen.dart         # Main app (tabs, explore, saved, interests)
│   ├── edit_profile_screen.dart # Edit existing profile
│   ├── subscription_screen.dart # Payment & subscription
│   ├── conversations_screen.dart # Chat list (mutual matches)
│   └── chat_screen.dart         # Individual chat interface
├── widgets/
│   └── glass_container.dart     # Custom glassmorphism widget
└── ...
```

## 🔄 Real-time Subscriptions

The app uses Supabase Realtime for:
- **Profile updates** - Detect subscription status changes
- **Saved profiles** - Instant UI updates when saving/unsaving
- **Interests** - Real-time notification of new interests
- **Messages** - Live chat with instant message delivery

## 📲 App Flow

1. **Welcome Screen** → Email authentication
2. **Profile Creation** → First-time user onboarding
3. **Subscription** → Payment required for access
4. **Home Screen** → Browse profiles, manage interests
5. **Chat** → Message mutual matches

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📦 Building

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For support, email support@hitwardhini.com or open an issue in the repository.

---

**Built with ❤️ using Flutter & Supabase**
