import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_text_styles.dart';

import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _linkFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _linkController = TextEditingController();
  bool _loading = false;
  bool _linkLoading = false;
  bool _sent = false;
  String? _error;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .requestPasswordReset(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitLink() async {
    if (!_linkFormKey.currentState!.validate()) return;

    setState(() {
      _linkLoading = true;
      _linkError = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .recoverSessionFromResetLink(_linkController.text);
      ref.read(pendingPasswordRecoveryProvider.notifier).state = true;
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => _linkError = e.toString());
    } finally {
      if (mounted) setState(() => _linkLoading = false);
    }
  }

  Widget _buildPasteLinkSection() {
    return Form(
      key: _linkFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 40),
          Text(
            'Link opened in Safari with an error?',
            style: AppFonts.nunito(
              fontSize: AppFonts.sz(16),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Long-press the URL in Safari, copy it, and paste it here. '
            'This works even if the link starts with localhost.',
            style: TextStyle(
              fontSize: AppFonts.sz(13),
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          if (_linkError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.trainBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _linkError!,
                style: TextStyle(color: AppColors.train, fontSize: AppFonts.sz(13)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _linkController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Paste reset link',
              alignLabelWithHint: true,
            ),
            validator: (v) =>
                v != null && v.trim().isNotEmpty ? null : 'Paste the full link',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _linkLoading ? null : _submitLink,
            child: _linkLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue with pasted link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailForm(),
        _buildPasteLinkSection(),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Forgot your password?',
            style: AppFonts.nunito(
              fontSize: AppFonts.sz(22),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email and we\'ll send you a link to choose a new password.',
            style: TextStyle(
              fontSize: AppFonts.sz(14),
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.trainBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: AppColors.train, fontSize: AppFonts.sz(13)),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) =>
                v != null && v.contains('@') ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('📬', textAlign: TextAlign.center, style: TextStyle(fontSize: AppFonts.sz(48))),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: AppFonts.nunito(
            fontSize: AppFonts.sz(22),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'If an account exists for ${_emailController.text.trim()}, you\'ll get a '
          'password reset link shortly. Open it on this device to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppFonts.sz(14),
            height: 1.5,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to sign in'),
        ),
        _buildPasteLinkSection(),
      ],
    );
  }
}
