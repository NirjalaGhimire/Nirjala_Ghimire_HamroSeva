import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_notifications_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_profile_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_search_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/location_services_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/referral_loyalty_screen.dart';
import 'package:hamro_sewa_frontend/features/customer/screens/customer_categories_tab_screen.dart';
import 'package:hamro_sewa_frontend/features/auth/screens/login_prototype_screen.dart';
import 'package:hamro_sewa_frontend/features/orders/screens/place_order_screen.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:url_launcher/url_launcher.dart';

/// Customer Home tab: avatar + name, location bar, carousel, Upcoming Booking, Refer banner.
class CustomerHomeTabScreen extends StatefulWidget {
  const CustomerHomeTabScreen({super.key});

  @override
  State<CustomerHomeTabScreen> createState() => _CustomerHomeTabScreenState();
}

class _CustomerHomeTabScreenState extends State<CustomerHomeTabScreen> {
  int _carouselIndex = 0;
  Map<String, dynamic>? _user;
  String _locationScope = 'All services available';
  List<dynamic> _popularServices = [];
  List<dynamic> _bookings = [];
  int _notificationCount = 0;
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  Future<void> _loadUser() async {
    final user = await TokenStorage.getSavedUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      final results = await Future.wait([
        ApiService.getServices(),
        ApiService.getUserBookings(),
        ApiService.getCustomerNotifications(),
      ]);
      if (mounted) {
        final services = List<dynamic>.from(results[0] as List);
        final bookings = List<dynamic>.from(results[1] as List);
        final notifications = results[2] as List;
        setState(() {
          _popularServices = services.take(8).toList();
          _bookings = bookings;
          _notificationCount = notifications.length;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is SessionExpiredException || e.toString().contains('token not valid') || e.toString().contains('SESSION_EXPIRED')) {
          await TokenStorage.clearTokens();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPrototypeScreen()),
            (_) => false,
          );
          return;
        }
        setState(() {
          _popularServices = [];
          _bookings = [];
          _notificationCount = 0;
          _loadingData = false;
        });
      }
    }
  }

  void _openPlaceOrder(String serviceId, String serviceTitle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceOrderScreen(
          categoryId: serviceId,
          categoryTitle: serviceTitle,
          categoryIcon: Icons.build_circle_outlined,
          serviceId: int.tryParse(serviceId),
          serviceTitle: serviceTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['username'] ?? _user?['email'] ?? 'User';
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUser();
            await _loadData();
          },
          color: AppTheme.customerPrimary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(name),
                _buildLocationBar(),
                _buildCarousel(),
                _buildPopularServices(),
                _buildUpcomingBooking(),
                _buildReferBanner(),
                _buildNewRequestSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerProfileTabScreen()),
              ),
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.customerPrimary.withOpacity(0.2),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.customerPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.darkGrey),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerSearchScreen()),
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _notificationCount > 0,
              smallSize: 8,
              child: const Icon(Icons.notifications_outlined, color: AppTheme.darkGrey),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => const LocationServicesScreen()),
            );
            if (result != null && mounted) setState(() => _locationScope = result);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _locationScope,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _carouselImageUrls = [
    'https://picsum.photos/seed/hamrosewa1/400/160',
    'https://picsum.photos/seed/hamrosewa2/400/160',
    'https://picsum.photos/seed/hamrosewa3/400/160',
  ];

  Widget _buildCarousel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: PageView.builder(
                itemCount: 3,
                onPageChanged: (i) => setState(() => _carouselIndex = i),
                itemBuilder: (context, index) {
                  return Image.network(
                    _carouselImageUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 160,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppTheme.customerPrimary.withOpacity(0.15),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                            color: AppTheme.customerPrimary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.customerPrimary.withOpacity(0.15),
                        child: Center(
                          child: Icon(
                            index == 0 ? Icons.home_repair_service : Icons.image_not_supported_outlined,
                            size: 56,
                            color: AppTheme.customerPrimary.withOpacity(0.6),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _carouselIndex == i
                      ? AppTheme.customerPrimary
                      : Colors.grey[300],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularServices() {
    final items = _popularServices;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          _loadingData
              ? const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary)))
              : SizedBox(
                  height: 140,
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'No services available',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final s = items[index] as Map<String, dynamic>;
                            final id = (s['id'] ?? s['id']?.toString() ?? '').toString();
                            final title = (s['title'] ?? '').toString();
                            final price = s['price'] != null ? (s['price'] is num ? (s['price'] as num).toDouble() : 0.0) : 0.0;
                            final category = (s['category_name'] ?? s['category'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Material(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => _openPlaceOrder(id, title),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 160,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: AppTheme.customerPrimary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.build_circle_outlined, size: 32, color: AppTheme.customerPrimary),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Rs ${price.toStringAsFixed(0)} • $category',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBooking() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming = _bookings.where((b) {
      final status = ((b as Map)['status'] as String?)?.toLowerCase() ?? '';
      if (status == 'cancelled' || status == 'rejected' || status == 'completed') return false;
      final dateStr = b['booking_date']?.toString();
      if (dateStr == null || dateStr.isEmpty) return true;
      final d = DateTime.tryParse(dateStr);
      if (d == null) return true;
      final bookingDate = DateTime(d.year, d.month, d.day);
      return !bookingDate.isBefore(todayDate);
    }).toList();
    upcoming.sort((a, b) {
      final da = (a as Map)['booking_date']?.toString() ?? '';
      final db = (b as Map)['booking_date']?.toString() ?? '';
      return da.compareTo(db);
    });
    final booking = upcoming.isNotEmpty ? upcoming.first as Map<String, dynamic> : null;
    final serviceTitle = booking?['service_title']?.toString() ?? '';
    final bookingDate = booking?['booking_date']?.toString() ?? '';
    final bookingTime = booking?['booking_time']?.toString() ?? '';
    final status = (booking?['status'] ?? '').toString();
    String dateTimeStr = '';
    if (bookingDate.isNotEmpty) {
      final d = DateTime.tryParse(bookingDate);
      dateTimeStr = d != null ? 'Date: ${_formatDate(d)}' : bookingDate;
      if (bookingTime.isNotEmpty) dateTimeStr += '  Time: ${_formatTime(bookingTime)}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Booking',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          if (booking == null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No upcoming bookings',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                serviceTitle.isEmpty ? 'Booking' : serviceTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkGrey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateTimeStr.isEmpty ? '—' : dateTimeStr,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Booking Status: ',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    status.isEmpty ? '—' : status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: status.toLowerCase() == 'accepted' || status.toLowerCase() == 'confirmed' ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.payment_outlined, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Payment Status: ',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  const Text(
                                    'Pending',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _showUpcomingBookingSheet(context, booking),
                          borderRadius: BorderRadius.circular(24),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.customerPrimary.withOpacity(0.2),
                            child: const Icon(Icons.person, color: AppTheme.customerPrimary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _confirmCancelBooking(context, booking),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.customerPrimary.withOpacity(0.2),
                            foregroundColor: AppTheme.customerPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showUpcomingBookingSheet(BuildContext context, Map<String, dynamic> booking) {
    final serviceTitle = booking['service_title'] ?? booking['title'] ?? 'Service';
    final providerName = booking['provider_name'] ?? 'Provider';
    final status = (booking['status'] as String?) ?? '—';
    final bookingDate = booking['booking_date']?.toString() ?? '—';
    final bookingTime = booking['booking_time']?.toString() ?? '—';
    final amount = booking['total_amount'];
    final amountStr = amount != null ? 'Rs ${(amount as num).toStringAsFixed(0)}' : '—';
    final bookingId = booking['id']?.toString() ?? '';
    final email = (booking['provider_email'] as String?)?.trim() ?? '';
    final phone = (booking['provider_phone'] as String?)?.trim() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              serviceTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _detailRow('Provider', providerName),
            _detailRow('Status', status),
            _detailRow('Date', bookingDate),
            _detailRow('Time', bookingTime),
            _detailRow('Amount', amountStr),
            const SizedBox(height: 16),
            if (phone.isNotEmpty || email.isNotEmpty) ...[
              Text(
                'Contact provider',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              if (phone.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone, color: AppTheme.customerPrimary),
                  title: const Text('Call'),
                  subtitle: Text(phone),
                  onTap: () async {
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
              if (email.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: AppTheme.customerPrimary),
                  title: const Text('Email'),
                  subtitle: Text(email),
                  onTap: () async {
                    final uri = Uri.parse('mailto:$email');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancelBooking(BuildContext context, Map<String, dynamic> booking) async {
    final id = booking['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text(
          'This will cancel your upcoming booking. You can book again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, cancel', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.updateBookingStatus(id, 'cancelled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static String _formatDate(DateTime d) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatTime(String t) {
    if (t.isEmpty) return '';
    if (t.length >= 5 && t.contains(':')) {
      final parts = t.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1].substring(0, 2)) ?? 0 : 0;
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$h12:${m.toString().padLeft(2, '0')} $period';
    }
    return t;
  }

  Widget _buildReferBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Material(
        color: AppTheme.customerPrimary,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Refer friends & earn loyalty points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Invite your friends to try our services & both of you earn rewards instantly',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReferralLoyaltyScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.white,
                    side: const BorderSide(color: AppTheme.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Invite Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewRequestSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find services',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse categories to see real providers and book a service.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerCategoriesTabScreen()),
            ),
            icon: const Icon(Icons.grid_view_rounded, size: 20),
            label: const Text('Browse categories'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.customerPrimary,
              side: const BorderSide(color: AppTheme.customerPrimary),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          const SizedBox(height: 24),
          Material(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'If you didn\'t find our service, don\'t worry! You can easily post your request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlaceOrderScreen(
                          categoryId: 'custom',
                          categoryTitle: 'New Request',
                          categoryIcon: Icons.add_circle_outline,
                        ),
                      ),
                    ),
                    child: const Text(
                      'New Request',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
