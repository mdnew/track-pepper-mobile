import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _householdName = TextEditingController(text: "Pepper's Schedule");
  final _inviteCode = TextEditingController();

  bool _loading = false;
  bool _joiningExisting = true;
  String? _error;
  String? _createdInviteCode;

  @override
  void dispose() {
    _householdName.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final household = await ref
          .read(authServiceProvider)
          .createHousehold(_householdName.text.trim());
      ref.invalidate(profileProvider);
      setState(() => _createdInviteCode = household.inviteCode);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinHousehold() async {
    if (!_joinFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).joinHousehold(_inviteCode.text);
      ref.invalidate(profileProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyInviteCode() {
    if (_createdInviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _createdInviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_createdInviteCode != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'Household created!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this invite code with your family:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.feedBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.feed),
                  ),
                  child: Text(
                    _createdInviteCode!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _copyInviteCode,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy invite code'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  child: const Text('Continue to calendar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your household'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(profileProvider);
            },
            child: const Text('Sign out', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join your family\'s schedule, or create a new household if you\'re the first one here.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Join household'),
                    icon: Icon(Icons.group_add_outlined, size: 18),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Create new'),
                    icon: Icon(Icons.home_outlined, size: 18),
                  ),
                ],
                selected: {_joiningExisting},
                onSelectionChanged: (selection) {
                  setState(() {
                    _joiningExisting = selection.first;
                    _error = null;
                  });
                },
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return AppColors.header;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.header;
                    }
                    return Colors.white;
                  }),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.trainBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.train, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: _joiningExisting ? _buildJoinForm() : _buildCreateForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinForm() {
    return Form(
      key: _joinFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter the invite code from a family member (find it in Profile & Household on their phone).',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _inviteCode,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'PEPPER-XXXX',
            ),
            validator: (v) =>
                v != null && v.trim().length >= 6 ? null : 'Enter invite code',
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _loading ? null : _joinHousehold,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Join household'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Form(
      key: _createFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Set up a new household for your family. You\'ll get an invite code to share with everyone else.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _householdName,
            decoration: const InputDecoration(labelText: 'Household name'),
            validator: (v) =>
                v != null && v.trim().isNotEmpty ? null : 'Enter a name',
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _loading ? null : _createHousehold,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create household'),
          ),
        ],
      ),
    );
  }
}
