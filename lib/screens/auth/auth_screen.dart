import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/app_constants.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../services/seed_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/studease_text_field.dart';
import '../../widgets/toast.dart';

/// Screen 1 — sign in, sign up (with daily goal + subjects) and demo entry.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const UserRepository _users = UserRepository();
  static const SeedService _seed = SeedService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _busy = false;
  String? _error;
  final Set<String> _subjects = <String>{...AppConstants.subjects};
  int _dailyGoal = AppConstants.defaultDailyGoal;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    if (_busy || _isSignUp == signUp) return;
    setState(() {
      _isSignUp = signUp;
      _error = null;
    });
  }

  void _toggleSubject(String subject) {
    setState(() {
      if (_subjects.contains(subject)) {
        if (_subjects.length > 1) {
          _subjects.remove(subject);
        } else {
          showAppToast(
            context,
            'Keep at least one subject selected.',
            type: AppToastType.info,
          );
        }
      } else {
        _subjects.add(subject);
      }
    });
  }

  Future<void> _bootstrapWorkspace(
    String uid, {
    required String name,
    required String email,
  }) async {
    await _users.ensureProfile(uid: uid, name: name, email: email);
    await _seed.ensureSeeded(uid);
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        final String name = _nameController.text.trim();
        final credential = await widget.authService.signUp(
          name: name,
          email: _emailController.text,
          password: _passwordController.text,
        );
        final String? uid = credential.user?.uid;
        if (uid != null) {
          await _users.ensureProfile(
            uid: uid,
            name: name,
            email: _emailController.text,
            subjects: _subjects.toList(growable: false),
            dailyGoalTarget: _dailyGoal,
          );
          await _seed.ensureSeeded(uid);
        }
      } else {
        final credential = await widget.authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        final String? uid = credential.user?.uid;
        if (uid != null) {
          await _bootstrapWorkspace(
            uid,
            name: credential.user?.displayName ?? 'Student',
            email: credential.user?.email ?? _emailController.text,
          );
        }
      }

      if (!mounted) return;
      showAppToast(
        context,
        _isSignUp ? 'Welcome to StudEase!' : 'Welcome back!',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tryDemo() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final credential = await widget.authService.signInToDemo();
      final String? uid = credential.user?.uid;
      if (uid != null) {
        await _users.ensureProfile(
          uid: uid,
          name: AppConstants.demoName,
          email: AppConstants.demoEmail,
          subjects: AppConstants.subjects,
          dailyGoalTarget: AppConstants.defaultDailyGoal,
          level: AppConstants.demoLevel,
        );
        await _seed.ensureSeeded(uid);
      }
      if (!mounted) return;
      showAppToast(
        context,
        'Demo workspace ready — explore StudEase freely!',
        type: AppToastType.streak,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final String? problem = Validators.email(_emailController.text);
    if (problem != null) {
      setState(
        () => _error = 'Enter your email above, then tap "Forgot password".',
      );
      return;
    }
    try {
      await widget.authService.sendPasswordReset(_emailController.text);
      if (!mounted) return;
      showAppToast(context, 'Password reset link sent to your email.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = AuthService.messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              context.surfaces.brandSoft,
              context.surfaces.surface,
              context.surfaces.canvas,
            ],
            stops: <double>[0.0, 0.40, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Center(child: AppLogo(size: 64)),
                      const SizedBox(height: 16),
                      Text(
                        'StudEase',
                        textAlign: TextAlign.center,
                        style: context.screenTitle.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'An Interactive Learning and Study Companion',
                        textAlign: TextAlign.center,
                        style: context.caption.copyWith(
                          color: context.surfaces.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _authCard(),
                      const SizedBox(height: 14),
                      _DemoButton(busy: _busy, onTap: _tryDemo),
                      const SizedBox(height: 12),
                      Text(
                        'ICS26011 • Group 3 · Interactive Prototype',
                        textAlign: TextAlign.center,
                        style: context.caption.copyWith(fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.surfaces.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.surfaces.ink.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ModeSwitcher(isSignUp: _isSignUp, onChanged: _setMode),
          const SizedBox(height: 16),
          _credentialFields(),
          if (_isSignUp) _signUpOptions(),
          if (!_isSignUp)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _resetPassword,
                child: const Text('Forgot password?'),
              ),
            ),
          if (_error != null) _ErrorBanner(message: _error!),
          const SizedBox(height: 14),
          _submitButton(),
        ],
      ),
    );
  }

  Widget _credentialFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_isSignUp) ...<Widget>[
          StudEaseTextField(
            controller: _nameController,
            label: 'Full name',
            hint: 'Enter your name',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.name],
            validator: Validators.name,
          ),
          const SizedBox(height: 12),
        ],
        StudEaseTextField(
          controller: _emailController,
          label: 'Student email',
          hint: 'student@university.edu',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
          validator: Validators.email,
        ),
        const SizedBox(height: 12),
        StudEaseTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'At least 6 characters',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.password],
          validator: Validators.password,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  Widget _signUpOptions() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Preferred study subjects',
            style: context.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: context.surfaces.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.subjects.map((String subject) {
              final SubjectPalette palette = context.surfaces.paletteFor(
                AppColors.forSubject(subject),
              );
              final bool selected = _subjects.contains(subject);
              return SelectableChip(
                label: subject,
                selected: selected,
                accent: palette.accent,
                soft: palette.soft,
                icon: selected ? Icons.check_rounded : Icons.add_rounded,
                onTap: () => _toggleSubject(subject),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Daily study goal',
            style: context.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: context.surfaces.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: AppConstants.dailyGoalOptions.map((int goal) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: SelectableChip(
                      label: goal == 1 ? '1 task' : '$goal tasks',
                      selected: _dailyGoal == goal,
                      onTap: () => setState(() => _dailyGoal = goal),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            'Each completed lesson, deck, quiz, book session or language '
            'exercise counts toward your goal.',
            style: context.caption.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return FilledButton(
      onPressed: _busy ? null : _submit,
      child: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isSignUp
                  ? 'Create Account & Start Studying'
                  : 'Log In to StudEase',
            ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.isSignUp, required this.onChanged});

  final bool isSignUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfaces.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          _tab(context, label: 'Log In', selected: !isSignUp, signUp: false),
          _tab(context, label: 'Sign Up', selected: isSignUp, signUp: true),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required String label,
    required bool selected,
    required bool signUp,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(signUp),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? context.surfaces.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: context.surfaces.ink.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.displayFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? context.surfaces.brandInk
                  : context.surfaces.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaces.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.surfaces.dangerInk.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: context.surfaces.dangerInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9F1239),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaces.successSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: context.surfaces.successInk,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Try Demo Account',
                    style: TextStyle(
                      fontFamily: AppTypography.displayFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: context.surfaces.successInk,
                    ),
                  ),
                  Text(
                    'One tap · no registration needed',
                    style: context.caption.copyWith(
                      fontSize: 9,
                      color: context.surfaces.successInk.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
