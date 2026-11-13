import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../data/services/api_client.dart';

/*
    Blocking someone.

    Hides the two people from each other both ways - jobs, profiles, posts
    and messages - whoever pressed it; the server enforces it everywhere
    (App\Support\Blocks). The other person is not told. Report stays a
    separate button for anything the KAYA team needs to see.
*/

/// Asks, then blocks. True when the block went through.
Future<bool> confirmBlock(BuildContext context, {required int userId, required String name}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block $name?'),
      content: Text(
        'You will not see each other\'s jobs, profiles, posts or messages on KAYA. '
        '$name is not told. You can unblock them in Settings.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Block', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  try {
    final res = await ApiClient().post('/users/$userId/block');
    if (!context.mounted) return true;
    AppToast.success(context, '${res.data['message'] ?? 'Blocked $name.'}');
    return true;
  } catch (e) {
    if (context.mounted) AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    return false;
  }
}

/// Settings: the people this account has blocked, each with Unblock.
Future<void> showBlockedAccounts(BuildContext context) {
  return showKayaPopup<void>(context, builder: (_) => const BlockedAccounts());
}

class BlockedAccounts extends StatefulWidget {
  const BlockedAccounts({super.key});

  @override
  State<BlockedAccounts> createState() => _BlockedAccountsState();
}

class _BlockedAccountsState extends State<BlockedAccounts> {
  List<Map<String, dynamic>>? _people;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient().get('/blocked-users');
      if (!mounted) return;
      setState(() {
        _people = ((res.data['data'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => p.cast<String, dynamic>())
            .toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _unblock(Map<String, dynamic> person) async {
    final id = person['id'] as int;
    setState(() => _busy.add(id));
    try {
      await ApiClient().delete('/users/$id/block');
      if (!mounted) return;
      setState(() {
        _busy.remove(id);
        _people = _people?.where((p) => p['id'] != id).toList();
      });
      AppToast.success(context, 'Unblocked ${person['name']}.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Blocked Accounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
            ],
          ),
        ),
        Flexible(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neutral600)),
                    TextButton(onPressed: _load, child: const Text('Try Again')),
                  ]),
                )
              : people == null
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  : people.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                          child: Text('You have not blocked anyone.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.neutral500)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          itemCount: people.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.neutral200),
                          itemBuilder: (_, i) {
                            final p = people[i];
                            final busy = _busy.contains(p['id']);
                            return ListTile(
                              title: Text('${p['name'] ?? 'KAYA user'}'),
                              trailing: TextButton(
                                onPressed: busy ? null : () => _unblock(p),
                                child: Text(busy ? 'Unblocking...' : 'Unblock'),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
