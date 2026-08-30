import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/widgets/workbench_panel.dart';
import 'package:omninest/features/setup/application/initial_setup_controller.dart';

class InitialSetupPage extends ConsumerStatefulWidget {
  const InitialSetupPage({super.key});

  @override
  ConsumerState<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends ConsumerState<InitialSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _setupTokenController = TextEditingController();
  final _instanceNameController = TextEditingController(text: 'OmniNest');
  final _defaultLocaleController = TextEditingController(text: 'zh-CN');
  final _defaultTimezoneController = TextEditingController(
    text: 'Asia/Shanghai',
  );
  final _usernameController = TextEditingController(text: 'root');
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _setupTokenController.dispose();
    _instanceNameController.dispose();
    _defaultLocaleController.dispose();
    _defaultTimezoneController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final setupToken = _setupTokenController.text;
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final instanceName = _instanceNameController.text.trim();
    final defaultLocale = _defaultLocaleController.text.trim();
    final defaultTimezone = _defaultTimezoneController.text.trim();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(initialSetupProvider.notifier)
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
      if (!mounted) return;
      await ref
          .read(authSessionProvider.notifier)
          .signInWithCredentials(username: username, password: password);
      if (!mounted) return;
      await ref.read(initialSetupProvider.notifier).refresh();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      await ref.read(initialSetupProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.setupCreateFailed);
      await ref.read(initialSetupProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(initialSetupProvider);
    return Scaffold(
      body: SafeArea(
        child: setup.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (_, _) => _SetupStatusError(
                onRetry: ref.read(initialSetupProvider.notifier).refresh,
              ),
          data: (status) {
            if (!status.setupAvailable) {
              return _SetupUnavailable(
                onRetry: ref.read(initialSetupProvider.notifier).refresh,
              );
            }
            return _buildForm(context);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 48 : 20,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child:
                  wide
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: _SetupSummary()),
                          const SizedBox(width: 48),
                          SizedBox(width: 480, child: _formPanel(l10n)),
                        ],
                      )
                      : _formPanel(l10n),
            ),
          ),
        );
      },
    );
  }

  Widget _formPanel(AppLocalizations l10n) {
    return WorkbenchPanel(
      padding: const EdgeInsets.all(24),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.setupTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.setupSubtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _setupTokenController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.setupToken,
                  hintText: l10n.setupTokenHint,
                  prefixIcon: const Icon(Icons.key_rounded),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? l10n.setupTokenHint
                            : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _instanceNameController,
                decoration: InputDecoration(
                  labelText: l10n.setupInstanceName,
                  prefixIcon: const Icon(Icons.home_work_outlined),
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? l10n.setupInstanceNameRequired
                            : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _defaultLocaleController,
                      decoration: InputDecoration(
                        labelText: l10n.setupDefaultLocale,
                        prefixIcon: const Icon(Icons.language_outlined),
                      ),
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? l10n.setupDefaultLocaleRequired
                                  : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _defaultTimezoneController,
                      decoration: InputDecoration(
                        labelText: l10n.setupDefaultTimezone,
                        prefixIcon: const Icon(Icons.schedule_outlined),
                      ),
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? l10n.setupDefaultTimezoneRequired
                                  : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                autofillHints: const [AutofillHints.newUsername],
                decoration: InputDecoration(
                  labelText: l10n.loginUsername,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? l10n.loginUsernameHint
                            : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: l10n.setupDisplayName,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: l10n.setupEmail,
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.loginPassword,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip:
                        _obscurePassword
                            ? l10n.loginShowPassword
                            : l10n.loginHidePassword,
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6 || value.length > 32) {
                    return l10n.setupPasswordLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.setupConfirmPassword,
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                ),
                validator:
                    (value) =>
                        value != _passwordController.text
                            ? l10n.setupPasswordMismatch
                            : null,
                onFieldSubmitted: (_) => _submitting ? null : _submit(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon:
                    _submitting
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.admin_panel_settings_rounded),
                label: Text(l10n.setupCreateAdmin),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.setupSecureNotice)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupSummary extends StatelessWidget {
  const _SetupSummary();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hub_outlined, size: 44, color: scheme.primary),
          const SizedBox(height: 24),
          Text(
            'OmniNest',
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(fontSize: 48),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              l10n.setupSubtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupUnavailable extends StatelessWidget {
  const _SetupUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SetupCenteredMessage(
      icon: Icons.key_off_outlined,
      title: l10n.setupUnavailableTitle,
      message: l10n.setupUnavailableMessage,
      actionLabel: l10n.setupRetryStatus,
      onAction: onRetry,
    );
  }
}

class _SetupStatusError extends StatelessWidget {
  const _SetupStatusError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SetupCenteredMessage(
      icon: Icons.cloud_off_outlined,
      title: l10n.setupStatusFailed,
      message: l10n.loginConnectionError,
      actionLabel: l10n.setupRetryStatus,
      onAction: onRetry,
    );
  }
}

class _SetupCenteredMessage extends StatelessWidget {
  const _SetupCenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: WorkbenchPanel(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 22),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
