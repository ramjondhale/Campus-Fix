import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

void main() {
  final seed = SeedData.build();
  late MockAuthRepository auth;
  setUp(() => auth = MockAuthRepository.seeded(seed: seed));

  group('MockAuthRepository', () {
    test('starts signed out', () {
      expect(auth.currentUser, isNull);
    });

    test('signs in every seeded account and sets currentUser', () async {
      for (final account in seed.accounts) {
        final user = await auth.signIn(account.user.idNumber, account.password);
        expect(user, account.user, reason: account.user.id);
        expect(auth.currentUser, account.user);
        await auth.signOut();
      }
    });

    test('covers every role and every department', () async {
      expect(
        seed.accounts.map((a) => a.user.role).toSet(),
        UserRole.values.toSet(),
      );
      expect(
        seed.accounts
            .where((a) => a.user.role == UserRole.maintenance)
            .map((a) => a.user.department)
            .toSet(),
        Department.values.toSet(),
      );
    });

    test('demo accounts: one per role, all of which sign in', () async {
      expect(seed.demoAccounts.map((a) => a.user.role).toList(), [
        UserRole.reporter,
        UserRole.maintenance,
        UserRole.verifier,
        UserRole.admin,
      ]);
      for (final a in seed.demoAccounts) {
        expect(
          (await auth.signIn(a.user.idNumber, a.password))?.role,
          a.user.role,
        );
      }
    });

    test('a wrong password or unknown ID number returns null', () async {
      final account = seed.demoAccounts.first;
      expect(await auth.signIn(account.user.idNumber, 'wrong'), isNull);
      expect(await auth.signIn(account.user.idNumber, ''), isNull);
      expect(await auth.signIn('NO-SUCH-ID', account.password), isNull);
      expect(await auth.signIn('', ''), isNull);
      expect(auth.currentUser, isNull);
    });

    test('the password is case-sensitive; the ID number is not', () async {
      final account = seed.demoAccounts.first;
      expect(
        await auth.signIn(
          account.user.idNumber,
          account.password.toUpperCase(),
        ),
        isNull,
      );
      expect(
        await auth.signIn(
          '  ${account.user.idNumber.toLowerCase()} ',
          account.password,
        ),
        account.user,
      );
    });

    test('signOut clears the session', () async {
      final account = seed.demoAccounts.first;
      await auth.signIn(account.user.idNumber, account.password);
      expect(auth.currentUser, isNotNull);
      await auth.signOut();
      expect(auth.currentUser, isNull);
      await auth.signOut(); // idempotent
      expect(auth.currentUser, isNull);
    });

    test('a failed sign-in leaves an existing session untouched', () async {
      final account = seed.demoAccounts.first;
      await auth.signIn(account.user.idNumber, account.password);
      expect(await auth.signIn(account.user.idNumber, 'wrong'), isNull);
      expect(auth.currentUser, account.user);
    });

    test('signing in as someone else replaces the session', () async {
      final a = seed.demoAccounts[0];
      final b = seed.demoAccounts[3];
      await auth.signIn(a.user.idNumber, a.password);
      await auth.signIn(b.user.idNumber, b.password);
      expect(auth.currentUser, b.user);
    });

    test('constructor rejects two accounts with the same ID number', () {
      final a = seed.accounts.first;
      expect(
        () => MockAuthRepository([
          a,
          MockAccount(
            user: a.user.copyWith(
              id: 'other',
              idNumber: a.user.idNumber.toUpperCase(),
            ),
            password: 'x',
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('MockAccount.toString never prints the password', () {
      final a = seed.accounts.first;
      expect(a.toString(), isNot(contains(a.password)));
      expect(a, MockAccount(user: a.user, password: a.password));
      expect(
        a.hashCode,
        MockAccount(user: a.user, password: a.password).hashCode,
      );
    });

    test('latency delays signIn and signOut', () async {
      final slow = MockAuthRepository(
        seed.accounts,
        latency: const Duration(milliseconds: 40),
      );
      final sw = Stopwatch()..start();
      await slow.signIn('nobody', 'x');
      await slow.signOut();
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(70));
    });
  });
}
