import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/all_users_provider.dart';

// Lets the admin pick people to add. Returns the chosen user ids.
class AddMembersScreen extends ConsumerStatefulWidget {
  final Set<String> existingMemberIds;
  const AddMembersScreen({super.key, required this.existingMemberIds});

  @override
  ConsumerState<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends ConsumerState<AddMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _selected = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(themeProvider).preset;
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.header,
        foregroundColor: Colors.white,
        elevation: 1,
        title: const Text('Add members'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                style: TextStyle(color: p.textMain),
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  hintStyle: TextStyle(color: p.icon, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: p.icon),
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                ),
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                // Only people who are not already in the group
                final available = users
                    .where((u) => !widget.existingMemberIds.contains(u.id))
                    .where((u) =>
                _query.isEmpty ||
                    u.name.toLowerCase().contains(_query) ||
                    u.email.toLowerCase().contains(_query))
                    .toList();

                if (available.isEmpty) {
                  return Center(
                    child: Text(
                      'No one left to add',
                      style: TextStyle(color: p.textGrey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: available.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, indent: 72, color: p.divider),
                  itemBuilder: (context, index) {
                    final user = available[index];
                    final isSelected = _selected.contains(user.id);
                    final hasAvatar =
                        user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

                    return ListTile(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selected.remove(user.id);
                        } else {
                          _selected.add(user.id);
                        }
                      }),
                      leading: CircleAvatar(
                        backgroundColor: p.primary.withOpacity(0.15),
                        backgroundImage:
                        hasAvatar ? NetworkImage(user.avatarUrl!) : null,
                        child: hasAvatar
                            ? null
                            : Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: p.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        user.name,
                        style: TextStyle(
                          color: p.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textGrey, fontSize: 12.5),
                      ),
                      trailing: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? p.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? p.primary : p.divider,
                            width: 1.6,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 15, color: Colors.white)
                            : null,
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  Center(child: CircularProgressIndicator(color: p.primary)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),

          // ---- Add button ----
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty ? 'Add' : 'Add (${_selected.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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