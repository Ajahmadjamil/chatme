import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile_models.dart';


final allUsersProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser!.id;

  final response = await supabase
      .from('profiles')
      .select()
      .neq('id', currentUserId);

  return (response as List)
      .map((json) => ProfileModel.fromJson(json))
      .toList();
});