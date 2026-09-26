import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();

  bool _obscure = true;
  bool _isChecking = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    // A tiny, deliberate delay so the button's loading state is visible
    // even though the check itself is instant (local Hive lookup) - this
    // avoids the UI flashing an instant "loading -> success" and gives a
    // sense of the app confirming the password rather than just letting
    // any value in.
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = auth.login(_passwordController.text);

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      if (!success) {
        _errorText = 'كلمة المرور غير صحيحة، حاول مرة أخرى';
        _passwordController.clear();
        _focusNode.requestFocus();
      }
    });

    // On success, AuthProvider.notifyListeners() already flipped
    // isAuthenticated to true - the AuthGate widget watching it will
    // automatically swap this screen out for MainNavigationScreen, so
    // there is nothing further to do here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: Stack(
        children: [
          // ---------------------------------------------------------------
          // BACKGROUND WATERMARK
          // Sits behind everything else (first child = painted first, so
          // every later child renders on top of it) and never intercepts
          // touches, thanks to IgnorePointer - so it can never sit "in
          // front of" or block the password field or the login button.
          // ---------------------------------------------------------------
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  // Scales with the available width instead of a fixed
                  // pixel size, so it stays proportionate on phones,
                  // tablets and desktop windows alike.
                  widthFactor: 0.55,
                  child: Opacity(
                    // Kept deliberately subtle - purely a brand mark,
                    // never competing with the login card in front of it.
                    opacity: 0.12,
                    child: Image.asset(
                      'assets/images/fikra_logo.png',
                      fit: BoxFit.contain,
                      // Tints the logo a flat white so it reads cleanly
                      // against the dark blue background regardless of
                      // the source PNG's own colors. Remove `color` and
                      // `colorBlendMode` below if you'd rather show the
                      // logo's original brand colors instead.
                     //// color: Colors.white,
                      ////colorBlendMode: BlendMode.srcIn,
                      // If the asset hasn't been added yet (or the path
                      // is wrong), fail silently instead of crashing the
                      // login screen with a red error box - the watermark
                      // is purely decorative, never load-bearing.
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---------------------------------------------------------------
          // EXISTING LOGIN UI - untouched, just moved into the foreground
          // layer of the Stack.
          // ---------------------------------------------------------------
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Fikra Store',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الرجاء إدخال كلمة المرور للدخول',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _focusNode,
                                autofocus: true,
                                obscureText: _obscure,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  errorText: _errorText,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1565C0),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isChecking ? null : _submit,
                                  child: _isChecking
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'دخول',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}