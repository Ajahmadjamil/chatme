// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../core/theme/app_colors.dart';
// import '../providers/all_users_provider.dart';
// import '../providers/chat_actions_provider.dart';
// import '../providers/chat_list_provider.dart';
// import 'conversation_screens.dart';
//
// class CreateGroupScreen extends ConsumerStatefulWidget {
//   const CreateGroupScreen({super.key});
//
//   @override
//   ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
// }
//
// class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
//   final TextEditingController _groupNameController = TextEditingController();
//
//   // Keep track of which user ids are checked/selected
//   final List<String> _selectedUserIds = [];
//
//   static const List<Color> _avatarPalette = [
//     Color(0xFF3CB67C),
//     Color(0xFF6C63FF),
//     Color(0xFFFF7A59),
//     Color(0xFF3B9AE1),
//     Color(0xFFE55C8A),
//     Color(0xFFF2B84B),
//   ];
//
//   Color _colorForName(String name) {
//     if (name.isEmpty) return _avatarPalette.first;
//     final index = name.codeUnitAt(0) % _avatarPalette.length;
//     return _avatarPalette[index];
//   }
//
//   @override
//   void dispose() {
//     _groupNameController.dispose();
//     super.dispose();
//   }
//
//   void _toggleUser(String userId, bool? isChecked) {
//     setState(() {
//       if (isChecked == true) {
//         _selectedUserIds.add(userId);
//       } else {
//         _selectedUserIds.remove(userId);
//       }
//     });
//   }
//
//   Future<void> _createGroup() async {
//     final groupName = _groupNameController.text.trim();
//
//     if (groupName.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter a group name')),
//       );
//       return;
//     }
//
//     if (_selectedUserIds.length < 2) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Select at least 2 people for a group')),
//       );
//       return;
//     }
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(
//         child: CircularProgressIndicator(color: AppColors.primary),
//       ),
//     );
//
//     try {
//       final chatId = await ref.read(chatActionsProvider).createGroupChat(
//         groupName: groupName,
//         memberIds: _selectedUserIds,
//       );
//
//       if (!context.mounted) return;
//       Navigator.pop(context); // close loading dialog
//
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ConversationScreen(
//             chatId: chatId,
//             otherUserName: groupName,
//             isGroup: true,
//           ),
//         ),
//       );
//       ref.invalidate(chatListProvider);
//     } catch (e) {
//       if (!context.mounted) return;
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to create group: $e')),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final usersAsync = ref.watch(allUsersProvider);
//     final count = _selectedUserIds.length;
//
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.background,
//         elevation: 0,
//         surfaceTintColor: Colors.transparent,
//         title: const Text(
//           'New Group',
//           style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
//         ),
//         iconTheme: const IconThemeData(color: AppColors.textDark),
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: ListView(
//                 padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//                 children: [
//                   // ---- Group name card ----
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(14),
//                       boxShadow: const [
//                         BoxShadow(
//                           color: AppColors.shadow,
//                           blurRadius: 10,
//                           offset: Offset(0, 4),
//                         ),
//                       ],
//                     ),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 44,
//                           height: 44,
//                           decoration: BoxDecoration(
//                             color: AppColors.primary.withOpacity(0.12),
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(Icons.groups_rounded,
//                               color: AppColors.primary),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: TextField(
//                             controller: _groupNameController,
//                             style: const TextStyle(
//                               color: AppColors.textDark,
//                               fontWeight: FontWeight.w600,
//                             ),
//                             decoration: const InputDecoration(
//                               hintText: 'Group name',
//                               hintStyle: TextStyle(color: AppColors.icon),
//                               border: InputBorder.none,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   const SizedBox(height: 20),
// // ---- Selected members preview row (WhatsApp style) ----
//                   if (_selectedUserIds.isNotEmpty) ...[
//                     const SizedBox(height: 16),
//                     SizedBox(
//                       height: 78,
//                       child: usersAsync.when(
//                         data: (users) {
//                           final selectedUsers =
//                           users.where((u) => _selectedUserIds.contains(u.id)).toList();
//
//                           return ListView.builder(
//                             scrollDirection: Axis.horizontal,
//                             itemCount: selectedUsers.length,
//                             itemBuilder: (context, index) {
//                               final user = selectedUsers[index];
//                               final avatarColor = _colorForName(user.name);
//
//                               return Padding(
//                                 padding: const EdgeInsets.only(right: 14),
//                                 child: Column(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     Stack(
//                                       clipBehavior: Clip.none,
//                                       children: [
//                                         CircleAvatar(
//                                           radius: 26,
//                                           backgroundColor: avatarColor.withOpacity(0.15),
//                                           child: Text(
//                                             user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
//                                             style: TextStyle(
//                                               color: avatarColor,
//                                               fontWeight: FontWeight.w700,
//                                               fontSize: 17,
//                                             ),
//                                           ),
//                                         ),
//                                         // Small "x" remove button on top-right of avatar
//                                         Positioned(
//                                           top: -2,
//                                           right: -2,
//                                           child: GestureDetector(
//                                             onTap: () => _toggleUser(user.id, false),
//                                             child: Container(
//                                               padding: const EdgeInsets.all(2),
//                                               decoration: const BoxDecoration(
//                                                 color: AppColors.textGrey,
//                                                 shape: BoxShape.circle,
//                                               ),
//                                               child: const Icon(Icons.close,
//                                                   size: 12, color: Colors.white),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                     const SizedBox(height: 4),
//                                     SizedBox(
//                                       width: 60,
//                                       child: Text(
//                                         user.name.split(' ').first,
//                                         maxLines: 1,
//                                         overflow: TextOverflow.ellipsis,
//                                         textAlign: TextAlign.center,
//                                         style: const TextStyle(
//                                           fontSize: 11.5,
//                                           color: AppColors.textDark,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               );
//                             },
//                           );
//                         },
//                         loading: () => const SizedBox.shrink(),
//                         error: (_, __) => const SizedBox.shrink(),
//                       ),
//                     ),
//                   ],
//                   Row(
//                     children: [
//                       const Text(
//                         'Select members',
//                         style: TextStyle(
//                           color: AppColors.textDark,
//                           fontWeight: FontWeight.w700,
//                           fontSize: 14,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       if (count > 0)
//                         Container(
//                           padding:
//                           const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: AppColors.primary.withOpacity(0.12),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             '$count selected',
//                             style: const TextStyle(
//                               color: AppColors.primary,
//                               fontSize: 11.5,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//
//                   const SizedBox(height: 10),
//
//                   // ---- User list card ----
//                   usersAsync.when(
//                     data: (users) {
//                       if (users.isEmpty) {
//                         return const Padding(
//                           padding: EdgeInsets.symmetric(vertical: 30),
//                           child: Center(child: Text('No other users found')),
//                         );
//                       }
//
//                       return Container(
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(18),
//                           boxShadow: const [
//                             BoxShadow(
//                               color: AppColors.shadow,
//                               blurRadius: 14,
//                               offset: Offset(0, 6),
//                             ),
//                           ],
//                         ),
//                         clipBehavior: Clip.antiAlias,
//                         child: ListView.separated(
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           padding: const EdgeInsets.symmetric(vertical: 6),
//                           itemCount: users.length,
//                           separatorBuilder: (_, __) => const Divider(
//                             height: 1,
//                             indent: 72,
//                             color: AppColors.divider,
//                           ),
//                           itemBuilder: (context, index) {
//                             final user = users[index];
//                             final isSelected = _selectedUserIds.contains(user.id);
//                             final avatarColor = _colorForName(user.name);
//
//                             return Material(
//                               color: Colors.transparent,
//                               child: InkWell(
//                                 onTap: () => _toggleUser(user.id, !isSelected),
//                                 child: Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 16, vertical: 8),
//                                   child: Row(
//                                     children: [
//                                       CircleAvatar(
//                                         radius: 22,
//                                         backgroundColor:
//                                         avatarColor.withOpacity(0.15),
//                                         child: Text(
//                                           user.name.isNotEmpty
//                                               ? user.name[0].toUpperCase()
//                                               : '?',
//                                           style: TextStyle(
//                                             color: avatarColor,
//                                             fontWeight: FontWeight.w700,
//                                           ),
//                                         ),
//                                       ),
//                                       const SizedBox(width: 14),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               user.name,
//                                               style: const TextStyle(
//                                                 color: AppColors.textDark,
//                                                 fontWeight: FontWeight.w600,
//                                                 fontSize: 15,
//                                               ),
//                                             ),
//                                             const SizedBox(height: 2),
//                                             Text(
//                                               user.email,
//                                               maxLines: 1,
//                                               overflow: TextOverflow.ellipsis,
//                                               style: const TextStyle(
//                                                 color: AppColors.textGrey,
//                                                 fontSize: 12.5,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       AnimatedContainer(
//                                         duration: const Duration(milliseconds: 150),
//                                         width: 24,
//                                         height: 24,
//                                         decoration: BoxDecoration(
//                                           shape: BoxShape.circle,
//                                           color: isSelected
//                                               ? AppColors.primary
//                                               : Colors.transparent,
//                                           border: Border.all(
//                                             color: isSelected
//                                                 ? AppColors.primary
//                                                 : AppColors.divider,
//                                             width: 1.6,
//                                           ),
//                                         ),
//                                         child: isSelected
//                                             ? const Icon(Icons.check,
//                                             size: 15, color: Colors.white)
//                                             : null,
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       );
//                     },
//                     loading: () => const Padding(
//                       padding: EdgeInsets.symmetric(vertical: 30),
//                       child: Center(
//                         child: CircularProgressIndicator(color: AppColors.primary),
//                       ),
//                     ),
//                     error: (err, stack) => Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 30),
//                       child: Center(child: Text('Error: $err')),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),
//
//             // ---- Create button at the bottom ----
//             Container(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//               decoration: BoxDecoration(
//                 color: AppColors.background,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.04),
//                     blurRadius: 10,
//                     offset: const Offset(0, -4),
//                   ),
//                 ],
//               ),
//               child: SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: ElevatedButton(
//                   onPressed: _createGroup,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primary,
//                     foregroundColor: Colors.white,
//                     elevation: 0,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(Icons.groups_2_rounded, size: 20),
//                       const SizedBox(width: 8),
//                       Text(
//                         count > 0 ? 'Create Group ($count)' : 'Create Group',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w600,
//                           fontSize: 15,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../core/shared/widgets/app_skeletons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_haptics.dart';
import '../providers/all_users_provider.dart';
import '../providers/chat_actions_provider.dart';
import '../providers/chat_list_provider.dart';
import 'conversation_screens.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();

  // Keep track of which user ids are checked/selected
  final List<String> _selectedUserIds = [];

  static const List<Color> _avatarPalette = [
    Color(0xFF3CB67C),
    Color(0xFF6C63FF),
    Color(0xFFFF7A59),
    Color(0xFF3B9AE1),
    Color(0xFFE55C8A),
    Color(0xFFF2B84B),
  ];

  Color _colorForName(String name) {
    if (name.isEmpty) return _avatarPalette.first;
    final index = name.codeUnitAt(0) % _avatarPalette.length;
    return _avatarPalette[index];
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _toggleUser(String userId, bool? isChecked) {
    setState(() {
      if (isChecked == true) {
        _selectedUserIds.add(userId);
      } else {
        _selectedUserIds.remove(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 people for a group')),
      );
      return;
    }

    try {
      final chatId = await AppSkeletons.showBlockingOverlay(
        context: context,
        future: ref.read(chatActionsProvider).createGroupChat(
              groupName: groupName,
              memberIds: _selectedUserIds,
            ),
      );

      if (!context.mounted || chatId == null) return;

      AppNav.pushReplacement(
        context,
        ConversationScreen(
          chatId: chatId,
          otherUserName: groupName,
          isGroup: true,
        ),
      );
      ref.invalidate(chatListProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final count = _selectedUserIds.length;
    // Colors of the currently selected theme
    final p = ref.watch(themeProvider).preset;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'New Group',
          style: TextStyle(color: p.textMain, fontWeight: FontWeight.w700),
        ),
        iconTheme: IconThemeData(color: p.textMain),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  // ---- Group name card ----
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: p.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.groups_rounded, color: p.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _groupNameController,
                            style: TextStyle(
                              color: p.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Group name',
                              hintStyle: TextStyle(color: p.icon),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // ---- Selected members preview row (WhatsApp style) ----
                  if (_selectedUserIds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 78,
                      child: usersAsync.when(
                        data: (users) {
                          final selectedUsers =
                          users.where((u) => _selectedUserIds.contains(u.id)).toList();

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedUsers.length,
                            itemBuilder: (context, index) {
                              final user = selectedUsers[index];
                              final avatarColor = _colorForName(user.name);

                              return Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: avatarColor.withOpacity(0.15),
                                          child: Text(
                                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              color: avatarColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 17,
                                            ),
                                          ),
                                        ),
                                        // Small "x" remove button on top-right of avatar
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: GestureDetector(
                                            onTap: () {
                                              AppHaptics.tap();
                                              _toggleUser(user.id, false);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: p.textGrey,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.close,
                                                  size: 12, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        user.name.split(' ').first,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: p.textMain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Text(
                        'Select members',
                        style: TextStyle(
                          color: p.textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (count > 0)
                        Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count selected',
                            style: TextStyle(
                              color: p.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ---- User list card ----
                  usersAsync.when(
                    data: (users) {
                      if (users.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: Text('No other users found')),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 72,
                            color: p.divider,
                          ),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final isSelected = _selectedUserIds.contains(user.id);
                            final avatarColor = _colorForName(user.name);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  AppHaptics.select();
                                  _toggleUser(user.id, !isSelected);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                        avatarColor.withOpacity(0.15),
                                        child: Text(
                                          user.name.isNotEmpty
                                              ? user.name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: avatarColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.name,
                                              style: TextStyle(
                                                color: p.textMain,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              user.email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: p.textGrey,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? p.primary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? p.primary
                                                : p.divider,
                                            width: 1.6,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check,
                                                size: 15, color: Colors.white)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => SizedBox(
                      height: 320,
                      child: AppSkeletons.userList(count: 6),
                    ),
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Error: $err')),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ---- Create button at the bottom ----
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: p.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    AppHaptics.success();
                    _createGroup();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups_2_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        count > 0 ? 'Create Group ($count)' : 'Create Group',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
