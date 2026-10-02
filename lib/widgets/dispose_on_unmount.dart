import 'package:flutter/widgets.dart';

/// Disposes [disposables] (TextEditingControllers, FocusNodes, ...) only
/// when this widget is really removed from the tree.
///
/// WHY: the common pattern
///
///     showDialog(...).then((_) => controller.dispose());
///
/// is unsafe. The Future returned by showDialog completes as soon as
/// Navigator.pop() is called, but the dialog stays mounted for its whole
/// closing animation. Any rebuild during that animation (a setState in
/// the dialog, a focus change, a provider notification...) then touches
/// an already-disposed controller. That throws inside the framework and
/// leaves the element tree half torn down, which surfaces as
/// "Failed assertion: '_dependents.isEmpty' is not true".
///
/// Wrapping the dialog content in this widget moves the dispose to
/// State.dispose, which Flutter calls only after the dialog's children
/// (TextFields etc.) have been unmounted and have detached from the
/// controllers.
///
/// Usage:
///
///     showDialog(
///       context: context,
///       builder: (ctx) => DisposeOnUnmount(
///         disposables: [nameController, amountController],
///         child: AlertDialog(...),
///       ),
///     );
class DisposeOnUnmount extends StatefulWidget {
  final List<ChangeNotifier> disposables;
  final Widget child;

  const DisposeOnUnmount({
    super.key,
    required this.disposables,
    required this.child,
  });

  @override
  State<DisposeOnUnmount> createState() => _DisposeOnUnmountState();
}

class _DisposeOnUnmountState extends State<DisposeOnUnmount> {
  @override
  void dispose() {
    for (final d in widget.disposables) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
