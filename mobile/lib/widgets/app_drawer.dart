import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/shared/profile_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../screens/shared/kyc_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user!;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user.name),
              accountEmail: Text('${user.email}  ·  ${user.role}'),
              currentAccountPicture: CircleAvatar(
                child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            if (user.role == 'technician' || user.role == 'supplier')
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('KYC verification'),
                subtitle: Text('Status: ${user.kycStatus}'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const KycScreen()));
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () async {
                await AuthService.instance.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
