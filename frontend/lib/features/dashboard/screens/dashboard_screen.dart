import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/dashboard/widgets/app_drawer.dart';

/// Prototype styling: light lavender bg #E0E0EB, dark grey #2D3250 for app bar and cards.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? dashboardStats;
  List<dynamic> services = [];
  List<dynamic> bookings = [];
  bool isLoading = true;

  static const Color _darkGrey = Color(0xFF2D3250);
  static const Color _lightLavender = Color(0xFFE0E0EB);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final savedUser = await TokenStorage.getSavedUser();
      Map<String, dynamic>? profile;
      Map<String, dynamic>? stats;
      List<dynamic> servicesList = [];
      List<dynamic> bookingsList = [];
      try {
        profile = await ApiService.getUserProfile();
        await TokenStorage.saveUser(profile);
      } catch (e) {
        if (e is SessionExpiredException) rethrow;
        profile = savedUser;
      }
      try {
        stats = await ApiService.getDashboardStats();
      } catch (e) {
        if (e is SessionExpiredException) rethrow;
      }
      try {
        servicesList = await ApiService.getServices();
      } catch (_) {}
      try {
        bookingsList = await ApiService.getUserBookings();
      } catch (e) {
        if (e is SessionExpiredException) rethrow;
      }
      if (profile == null && savedUser != null) profile = savedUser;

      if (mounted) {
        setState(() {
          userProfile = profile;
          dashboardStats = stats;
          services = servicesList;
          bookings = bookingsList;
          isLoading = false;
        });
      }
      if (profile == null && savedUser == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load profile')),
        );
      }
    } catch (e) {
      if (e is SessionExpiredException || e.toString().contains('token not valid') || e.toString().contains('SESSION_EXPIRED')) {
        await TokenStorage.clearTokens();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
            (_) => false,
          );
        }
        return;
      }
      final savedUser = await TokenStorage.getSavedUser();
      if (mounted) {
        setState(() {
          userProfile = savedUser;
          dashboardStats = null;
          services = [];
          bookings = [];
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clearTokens();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPrototypeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: _lightLavender,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userRole = userProfile?['role'] ?? 'customer';
    final userName = userProfile?['username'] ?? 'User';

    return Scaffold(
      backgroundColor: _lightLavender,
      appBar: AppBar(
        title: Text(
          'Welcome, $userName!',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _darkGrey,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: AppDrawer(
        onClose: () => Navigator.pop(context),
        onLogout: _logout,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: _darkGrey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(),
              const SizedBox(height: 20),
              _buildSectionTitle(
                userRole == 'admin'
                    ? 'Admin Overview'
                    : userRole == 'provider'
                        ? 'Your Statistics'
                        : 'Your Activity',
              ),
              const SizedBox(height: 8),
              _buildStatsCards(userRole),
              const SizedBox(height: 20),
              _buildSectionTitle('Recent Bookings'),
              const SizedBox(height: 8),
              _buildRecentBookings(),
              const SizedBox(height: 20),
              if (userRole == 'customer') ...[
                _buildSectionTitle('Available Services'),
                const SizedBox(height: 8),
                _buildAvailableServices(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _darkGrey,
      ),
    );
  }

  Widget _buildProfileCard() {
    final userRole = userProfile?['role'] ?? 'customer';
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _darkGrey,
              ),
            ),
            const SizedBox(height: 12),
            _profileRow(Icons.email, 'Email', userProfile?['email'] ?? 'N/A'),
            _profileRow(
                Icons.badge, 'Role', (userRole as String).toUpperCase()),
            if (userRole == 'provider')
              _profileRow(
                Icons.work,
                'Profession',
                userProfile?['profession'] ?? 'Not specified',
              ),
            _profileRow(
              Icons.verified_user,
              'Verified',
              userProfile?['is_verified'] == true ? 'Yes' : 'No',
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _darkGrey),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _darkGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _darkGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(String userRole) {
    final stats = dashboardStats ?? {};
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'Total ${userRole == 'provider' ? 'Services' : 'Bookings'}',
          (userRole == 'provider'
                  ? stats['total_services'] ?? 0
                  : stats['total_bookings'] ?? 0)
              .toString(),
          Icons.list_alt,
          _darkGrey,
        ),
        _buildStatCard(
          'Pending',
          (stats['pending_bookings'] ?? 0).toString(),
          Icons.pending_actions,
          Colors.orange.shade700,
        ),
        if (userRole == 'provider') ...[
          _buildStatCard(
            'Completed',
            (stats['completed_bookings'] ?? 0).toString(),
            Icons.check_circle,
            Colors.green.shade700,
          ),
          _buildStatCard(
            'Earnings',
            'Rs. ${stats['total_earnings'] ?? 0}',
            Icons.payments,
            Colors.purple.shade700,
          ),
          _buildStatCard(
            'Rating',
            '${(stats['average_rating'] ?? 0).toStringAsFixed(1)} ⭐',
            Icons.star,
            Colors.amber.shade700,
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _darkGrey,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: _darkGrey.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBookings() {
    if (bookings.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No bookings yet')),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookings.length > 3 ? 3 : bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              booking['service_title'] ?? 'Service',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: _darkGrey),
            ),
            subtitle: Text(
              'Date: ${booking['booking_date']}\nStatus: ${booking['status']}',
              style: TextStyle(color: _darkGrey.withOpacity(0.8)),
            ),
            trailing: Icon(
              _getStatusIcon(booking['status']),
              color: _getStatusColor(booking['status']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableServices() {
    if (services.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No services available')),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length > 5 ? 5 : services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              service['title'] ?? 'Service',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: _darkGrey),
            ),
            subtitle: Text(
              'Provider: ${service['provider_name']}\nPrice: Rs. ${service['price']}',
              style: TextStyle(color: _darkGrey.withOpacity(0.8)),
            ),
            trailing:
                const Icon(Icons.arrow_forward_ios, size: 16, color: _darkGrey),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Service details — coming soon')),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
