/// PIN entry + enrollment bottom sheets for the mobile groups UX.
///
/// Two surfaces:
///   * [PinEntrySheet] — operator types the existing PIN to unlock a
///     gated group.  Used for shared-mode groups (everyone uses the
///     household PIN) AND per-client groups the calling client has
///     already enrolled in.
///   * [PinEnrollmentSheet] — first-time enrollment for a per-client
///     group (M8).  Two PIN fields ("Set PIN" + "Confirm PIN") so
///     fat-finger doesn't lock the operator out of their own content.
///
/// Both sheets `Navigator.pop(pin)` on submit so the calling widget
/// can fire the cubit op + render the success / failure snackbar
/// without having to thread the cubit ref into the sheet builder.
///
/// Plan: `docs/10_planning/13_groups_v2_content_spaces.md` §M4 + §M8.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora_core/fluxora_core.dart';

/// Mirror of the server's `_OBVIOUS_PINS` blocklist + the desktop's
/// `_PinSectionState._obviousPins`.  Server is authoritative; this
/// stops the obvious cases before the network round-trip so the
/// modal can fail closed with a friendlier error.
const _kObviousPins = <String>{
  '0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777',
  '8888', '9999',
  '1234', '2345', '3456', '4567', '5678', '6789',
  '4321', '5432', '6543', '7654', '8765', '9876', '0987',
  '0123',
  '2580',
};

String? _validatePin(String pin) {
  if (pin.isEmpty) return 'Enter a PIN';
  if (!RegExp(r'^[0-9]+$').hasMatch(pin)) return 'Numbers only';
  if (pin.length < 4 || pin.length > 8) return '4 to 8 digits';
  if (_kObviousPins.contains(pin)) return 'Too easy to guess';
  return null;
}

/// Bottom sheet that asks the operator for an existing PIN.
class PinEntrySheet extends StatefulWidget {
  const PinEntrySheet({
    super.key,
    required this.groupName,
    required this.pinMode,
    required this.pinModel,
  });

  final String groupName;
  final PinMode pinMode;
  final PinModel pinModel;

  @override
  State<PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<PinEntrySheet> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = _ctrl.text.trim();
    final canSubmit =
        !_submitting && pin.isNotEmpty && _validatePin(pin) == null;
    final isPerClient = widget.pinModel == PinModel.perClient;
    final ttl = widget.pinMode == PinMode.perEntry
        ? '5 minutes'
        : '12 hours';
    return FluxBottomSheet(
      title: 'Enter PIN — ${widget.groupName}',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              isPerClient
                  ? 'Your PIN unlocks this group on this device.  Grant '
                      'lasts $ttl.'
                  : 'Group PIN unlocks the libraries this group exposes.  '
                      'Grant lasts $ttl.',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: canSubmit ? (_) => _submit() : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textBright,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                    ),
                    onPressed: canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Unlock'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.pop(context, _ctrl.text.trim());
  }
}

/// Bottom sheet for first-time per-client PIN enrollment (M8).
/// Two-field layout (set + confirm) catches typos so the operator
/// doesn't lock themselves out of their own group on first access.
class PinEnrollmentSheet extends StatefulWidget {
  const PinEnrollmentSheet({
    super.key,
    required this.groupName,
    required this.pinMode,
  });

  final String groupName;
  final PinMode pinMode;

  @override
  State<PinEnrollmentSheet> createState() => _PinEnrollmentSheetState();
}

class _PinEnrollmentSheetState extends State<PinEnrollmentSheet> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? get _error {
    final pin = _newCtrl.text.trim();
    if (pin.isEmpty) return null; // don't shout before the user types
    final policy = _validatePin(pin);
    if (policy != null) return policy;
    if (_confirmCtrl.text.trim().isEmpty) return null;
    if (_newCtrl.text.trim() != _confirmCtrl.text.trim()) {
      return 'PINs don\'t match';
    }
    return null;
  }

  bool get _canSubmit {
    final pin = _newCtrl.text.trim();
    if (pin.isEmpty) return false;
    if (_validatePin(pin) != null) return false;
    if (_confirmCtrl.text.trim() != pin) return false;
    return !_submitting;
  }

  @override
  Widget build(BuildContext context) {
    final ttl = widget.pinMode == PinMode.perEntry
        ? '5 minutes'
        : '12 hours';
    final err = _error;
    return FluxBottomSheet(
      title: 'Set up PIN — ${widget.groupName}',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Each device picks its own PIN.  Only this device knows '
              'it.  If forgotten, your operator can reset it for you '
              '(you\'ll set a new one on next access).  Grant lasts $ttl.',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'New PIN (4-8 digits)',
                errorText: _newCtrl.text.isEmpty
                    ? null
                    : _validatePin(_newCtrl.text.trim()),
                border: const OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'Confirm PIN',
                errorText: (_confirmCtrl.text.isNotEmpty &&
                        _confirmCtrl.text.trim() !=
                            _newCtrl.text.trim())
                    ? 'PINs don\'t match'
                    : null,
                border: const OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _canSubmit ? (_) => _submit() : null,
            ),
            if (err != null && err != 'PINs don\'t match') ...[
              const SizedBox(height: 8),
              Text(
                err,
                style: AppTypography.captionV2.copyWith(color: AppColors.red),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textBright,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                    ),
                    onPressed: _canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Set PIN'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    Navigator.pop(context, _newCtrl.text.trim());
  }
}
