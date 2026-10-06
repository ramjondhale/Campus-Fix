import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../src/mock_support.dart';
import 'mock_account.dart';
import 'seed_data.dart';

/// In-memory [AuthRepository] for the prototype: signs in against a fixed
/// list of [MockAccount]s.
class MockAuthRepository implements AuthRepository {
  /// Creates an auth backend that accepts [accounts]. [latency] simulates a
  /// network delay on [signIn] / [signOut].
  ///
  /// Throws an [ArgumentError] if two accounts share an ID number.
  MockAuthRepository(
    Iterable<MockAccount> accounts, {
    this.latency = Duration.zero,
  }) {
    for (final a in accounts) {
      if (_byIdNumber.containsKey(_key(a.user.idNumber))) {
        throw ArgumentError('Duplicate ID number ${a.user.idNumber}.');
      }
      _byIdNumber[_key(a.user.idNumber)] = a;
    }
  }

  /// An auth backend accepting the seeded accounts of [seed] (default:
  /// `SeedData.build()`).
  factory MockAuthRepository.seeded({
    SeedData? seed,
    Duration latency = Duration.zero,
  }) =>
      MockAuthRepository((seed ?? SeedData.build()).accounts, latency: latency);

  /// Simulated delay applied to [signIn] and [signOut].
  final Duration latency;

  final Map<String, MockAccount> _byIdNumber = {};
  AppUser? _current;

  /// ID numbers are matched after trimming, ignoring case.
  static String _key(String idNumber) => idNumber.trim().toLowerCase();

  @override
  AppUser? get currentUser => _current;

  /// Signs in with [idNumber] (trimmed, case-insensitive) and an exact
  /// [password]. Returns the user, or `null` for unknown credentials - in
  /// which case any existing session is left untouched.
  @override
  Future<AppUser?> signIn(String idNumber, String password) async {
    await simulateLatency(latency);
    final account = _byIdNumber[_key(idNumber)];
    if (account == null || account.password != password) return null;
    return _current = account.user;
  }

  @override
  Future<void> signOut() async {
    await simulateLatency(latency);
    _current = null;
  }
}
