import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/features/setup/data/initial_setup_api.dart';
import 'package:omninest/features/setup/domain/initial_setup_status.dart';

final initialSetupApiProvider = Provider<InitialSetupApi>((ref) {
  return InitialSetupApi(ref.watch(apiClientProvider));
});

final initialSetupProvider =
    AsyncNotifierProvider<InitialSetupController, InitialSetupStatus>(
      InitialSetupController.new,
    );

class InitialSetupController extends AsyncNotifier<InitialSetupStatus> {
  @override
  Future<InitialSetupStatus> build() {
    return ref.watch(initialSetupApiProvider).status();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ref.read(initialSetupApiProvider).status);
  }

  Future<void> createSuperAdmin({
    required String setupToken,
    required String username,
    required String displayName,
    required String email,
    required String password,
    required String instanceName,
    required String defaultLocale,
    required String defaultTimezone,
  }) {
    return ref
        .read(initialSetupApiProvider)
        .createSuperAdmin(
          setupToken: setupToken,
          username: username,
          displayName: displayName,
          email: email,
          password: password,
          instanceName: instanceName,
          defaultLocale: defaultLocale,
          defaultTimezone: defaultTimezone,
        );
  }
}
