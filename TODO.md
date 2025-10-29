# TODO: Implement Anonymous Token-Based Voting System

## 1. Update Dependencies
- [ ] Add `uuid` package to `pubspec.yaml` for generating secure tokens

## 2. Create New Model
- [ ] Create `lib/models/token.dart` with Token model class

## 3. Update Main Voting Screen
- [ ] Add voting rights check (`direito_voto` table) for logged-in user
- [ ] Implement token request logic (`pedirToken` function)
- [ ] Display token to user for reference
- [ ] Modify vote function to use token for anonymous voting
- [ ] Handle token usage and prevent double voting

## 4. Add Helper Functions
- [ ] Implement `pedirToken` function for token generation
- [ ] Implement `votar` function for anonymous vote insertion

## 5. Followup Steps
- [ ] Run `flutter pub get` to install dependencies
- [ ] Test token generation and voting flow
- [ ] Verify Supabase RLS and database triggers
- [ ] Handle edge cases (expired elections, invalid tokens)
