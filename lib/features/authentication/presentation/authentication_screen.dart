import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/authentication_providers.dart';
import 'terms_and_conditions_screen.dart';

class AuthenticationScreen
    extends ConsumerStatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  ConsumerState<AuthenticationScreen>
      createState() =>
          _AuthenticationScreenState();
}

class _AuthenticationScreenState
    extends ConsumerState<AuthenticationScreen> {
  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isCreatingAccount = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email =
        _emailController.text.trim();

    final password =
        _passwordController.text;

    if (
      email.isEmpty ||
      password.isEmpty
    ) {
      _showMessage(
        'Enter your email and password.',
      );
      return;
    }

    if (
      _isCreatingAccount &&
      !_acceptedTerms
    ) {
      _showMessage(
        'Please read and accept the Terms & Conditions.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository =
          ref.read(
        authenticationRepositoryProvider,
      );

      if (_isCreatingAccount) {
        await repository
            .createAccountWithEmailAndPassword(
          email: email,
          password: password,
        );

        await _recordTermsAcceptance();
      } else {
        await repository
            .signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        _isCreatingAccount
            ? 'Account created successfully.'
            : 'Signed in successfully.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _messageForFirebaseError(
          error,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recordTermsAcceptance() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'Unable to record Terms acceptance.',
      );
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('legal')
        .doc('terms')
        .set({
      'accepted': true,
      'version':
          TermsAndConditionsScreen.currentVersion,
      'acceptedAt':
          FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openTerms() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const TermsAndConditionsScreen(),
      ),
    );
  }

  String _messageForFirebaseError(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';

      case 'weak-password':
        return 'Choose a stronger password.';

      case 'email-already-in-use':
        return 'An account already exists with this email.';

      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      default:
        return error.message ??
            'Authentication failed. Please try again.';
    }
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              Icon(
                Icons.school_rounded,
                size: 72,
                color:
                    Theme.of(context)
                        .colorScheme
                        .primary,
              ),

              const SizedBox(height: 24),

              Text(
                _isCreatingAccount
                    ? 'Create your ExamReady account'
                    : 'Welcome to ExamReady',
                textAlign:
                    TextAlign.center,
                style:
                    Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
              ),

              const SizedBox(height: 8),

              Text(
                _isCreatingAccount
                    ? 'Create an account to track your '
                        'examinations and official updates.'
                    : 'Sign in to track your examinations, '
                        'requirements, and important updates.',
                textAlign:
                    TextAlign.center,
                style:
                    Theme.of(context)
                        .textTheme
                        .bodyLarge,
              ),

              const SizedBox(height: 40),

              OutlinedButton.icon(
                onPressed: null,
                icon: Icon(
                  Icons
                      .account_circle_outlined,
                ),
                label: Text(
                  'Continue with Google',
                ),
              ),

              const SizedBox(height: 24),

              const Row(
                children: [
                  Expanded(
                    child: Divider(),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child:
                        Text('or'),
                  ),
                  Expanded(
                    child: Divider(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              TextField(
                controller:
                    _emailController,
                enabled:
                    !_isLoading,
                keyboardType:
                    TextInputType
                        .emailAddress,
                autocorrect:
                    false,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Email',
                  prefixIcon:
                      Icon(
                    Icons.email_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller:
                    _passwordController,
                enabled:
                    !_isLoading,
                obscureText:
                    _obscurePassword,
                decoration:
                    InputDecoration(
                  labelText:
                      'Password',
                  prefixIcon:
                      const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon:
                      IconButton(
                    tooltip:
                        _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                    icon:
                        Icon(
                      _obscurePassword
                          ? Icons
                              .visibility_outlined
                          : Icons
                              .visibility_off_outlined,
                    ),
                  ),
                  border:
                      const OutlineInputBorder(),
                ),
              ),

              if (_isCreatingAccount) ...[
                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value:
                          _acceptedTerms,
                      onChanged:
                          _isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _acceptedTerms =
                                        value ??
                                        false;
                                  });
                                },
                    ),

                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 10,
                        ),
                        child: Wrap(
                          crossAxisAlignment:
                              WrapCrossAlignment
                                  .center,
                          children: [
                            const Text(
                              'I have read and agree to the ',
                            ),
                            InkWell(
                              onTap:
                                  _isLoading
                                      ? null
                                      : _openTerms,
                              child: Text(
                                'Terms & Conditions',
                                style:
                                    TextStyle(
                                  color:
                                      Theme.of(
                                    context,
                                  )
                                          .colorScheme
                                          .primary,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  decoration:
                                      TextDecoration
                                          .underline,
                                ),
                              ),
                            ),
                            const Text('.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  'ExamReady organizes information from '
                  'official sources. Always verify critical '
                  'and time-sensitive details through the '
                  'linked official authority source.',
                  style:
                      Theme.of(context)
                          .textTheme
                          .bodySmall,
                ),
              ],

              const SizedBox(height: 18),

              SizedBox(
                height: 52,
                child:
                    FilledButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _submit,
                  child:
                      _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : Text(
                              _isCreatingAccount
                                  ? 'Create Account'
                                  : 'Sign In',
                            ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed:
                    _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isCreatingAccount =
                                  !_isCreatingAccount;

                              _acceptedTerms =
                                  false;
                            });
                          },
                child:
                    Text(
                  _isCreatingAccount
                      ? 'Already have an account? Sign In'
                      : 'New to ExamReady? Create Account',
                ),
              ),

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: null,
                icon: Icon(
                  Icons
                      .phone_android_rounded,
                ),
                label: Text(
                  'Sign in with Phone OTP',
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Google and Phone authentication will be '
                'available after their Firebase '
                'configuration is completed.',
                textAlign:
                    TextAlign.center,
                style:
                    Theme.of(context)
                        .textTheme
                        .bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
