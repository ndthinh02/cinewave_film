import 'package:flutter/material.dart';
import 'community_review_list.dart';
import 'notification_screen.dart';
import 'collection_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../screens/auth_screen.dart';
import 'community_profile_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Scaffold(
          appBar: AppBar(
              title: const Text('Cộng đồng'),
              actions: [
                IconButton(
                    tooltip: 'Hồ sơ của tôi',
                    onPressed: () async {
                      final auth = context.read<AuthCubit>();
                      if (!auth.api.loggedIn)
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AuthScreen()));
                      if (context.mounted && auth.api.loggedIn)
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CommunityProfileScreen(
                                    userId: auth.api.user!['id'].toString())));
                    },
                    icon: const Icon(Icons.person_outline)),
                IconButton(
                    onPressed: () => openCollections(context),
                    icon: const Icon(Icons.video_library_outlined)),
                const NotificationBell()
              ],
              bottom: const TabBar(
                  tabs: [Tab(text: 'Mới nhất'), Tab(text: 'Đang theo dõi')])),
          body: const TabBarView(children: [
            CommunityReviewList(path: '/feed'),
            CommunityReviewList(path: '/feed/following', requiresLogin: true)
          ])));
}
