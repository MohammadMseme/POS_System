import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور الجديدة وتأكيدها غير متطابقين'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    switch (result) {
      case 'ok':
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case 'wrong_old_password':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة المرور الحالية غير صحيحة'),
            backgroundColor: Colors.red,
          ),
        );
        break;
      case 'not_allowed':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذه العملية متاحة للمدير فقط'),
            backgroundColor: Colors.red,
          ),
        );
        break;
      case 'too_short':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة المرور الجديدة قصيرة جداً (4 أحرف على الأقل)'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء إدخال كلمة مرور جديدة'),
            backgroundColor: Colors.orange,
          ),
        );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.blue.shade700),
            const SizedBox(width: 10),
            const Text('قفل التطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('سيتم قفل التطبيق وستحتاج لإدخال كلمة المرور مجدداً للدخول. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.lock_outline),
            label: const Text('قفل الآن'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool isAdmin = auth.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.settings_outlined),
            SizedBox(width: 10),
            Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NEW: who is logged in.
            _SessionCard(role: auth.role),
            const SizedBox(height: 16),

            if (isAdmin && (auth.isUsingDefaultPassword || auth.isEmployeeUsingDefaultPassword))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                    const SizedBox(width: 10),
                    // Not const: the message depends on the passwords set.
                    Expanded(
                      child: Text(
                        auth.isUsingDefaultPassword && auth.isEmployeeUsingDefaultPassword
                            ? 'كلمتا مرور المدير والموظف ما زالتا الافتراضيتين (12345). يُنصح بشدة بتغييرهما الآن.'
                            : auth.isUsingDefaultPassword
                                ? 'ما زلت تستخدم كلمة مرور المدير الافتراضية. يُنصح بشدة بتغييرها الآن.'
                                : 'كلمة مرور الموظف ما زالت الافتراضية (12345). يُنصح بتغييرها.',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),

            // Password management is Admin-only.
            if (isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.password_outlined, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'تغيير كلمة مرور المدير',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: _obscureOld,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureOld = !_obscureOld),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        if (v.trim().length < 4) return '4 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                      onFieldSubmitted: (_) => _changePassword(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSaving ? null : _changePassword,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('حفظ كلمة المرور الجديدة'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // NEW: the Admin sets the Employee password.
            const _EmployeePasswordCard(),

            const SizedBox(height: 16),
            ],

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_outline, color: Colors.red),
                ),
                title: const Text('قفل التطبيق الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('سيُطلب إدخال كلمة المرور مجدداً عند العودة', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_left),
                onTap: _confirmLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows which role is logged in.
class _SessionCard extends StatelessWidget {
  final UserRole? role;

  const _SessionCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final bool admin = role == UserRole.admin;
    final Color color = admin ? const Color(0xFF1565C0) : Colors.teal.shade700;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              admin ? Icons.admin_panel_settings_outlined : Icons.badge_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مسجل الدخول ك${role?.label ?? '-'}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  admin
                      ? 'صلاحيات كاملة لكل الصفحات والإعدادات'
                      : 'وضع محدود: نقطة البيع، الحاسبة، تحصيل الديون، وسجل حركات البيع',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin-only card for setting the Employee password. Confirmed with the
/// Admin's own current password; owns and disposes its own controllers.
class _EmployeePasswordCard extends StatefulWidget {
  const _EmployeePasswordCard();

  @override
  State<_EmployeePasswordCard> createState() => _EmployeePasswordCardState();
}

class _EmployeePasswordCardState extends State<_EmployeePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _adminPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _adminPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    if (_newPasswordController.text != _confirmPasswordController.text) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('كلمة مرور الموظف الجديدة وتأكيدها غير متطابقين'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isSaving = true);
    final result = await auth.setEmployeePassword(
      adminPassword: _adminPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    final (String text, Color color) = switch (result) {
      'ok' => ('تم تغيير كلمة مرور الموظف بنجاح', Colors.green),
      'wrong_old_password' => ('كلمة مرور المدير غير صحيحة', Colors.red),
      'too_short' => ('كلمة المرور الجديدة قصيرة جداً (4 أحرف على الأقل)', Colors.orange),
      'not_allowed' => ('هذه العملية متاحة للمدير فقط', Colors.red),
      _ => ('الرجاء إدخال كلمة مرور جديدة', Colors.orange),
    };
    if (result == 'ok') {
      _adminPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
    messenger.showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.badge_outlined, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 10),
                const Text(
                  'تغيير كلمة مرور الموظف',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _adminPasswordController,
              obscureText: _obscure,
              decoration: _decoration('كلمة مرور المدير الحالية (للتأكيد)', Icons.admin_panel_settings_outlined),
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscure,
              decoration: _decoration('كلمة مرور الموظف الجديدة', Icons.lock_reset_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return 'مطلوب';
                if (v.trim().length < 4) return '4 أحرف على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscure,
              decoration: _decoration('تأكيد كلمة مرور الموظف', Icons.check_circle_outline),
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ كلمة مرور الموظف'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}