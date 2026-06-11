// lib/features/notifications/screens/notifications_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — NOTIFICATIONS UI v5.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [FIXED] Swipe-to-Delete crash resolved via Optimistic Provider state.
// ✅ [PERFORMANCE] 100% decoupled from direct Firestore streams.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/notification_provider.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

enum NotifCategory { sos, location, contact, system, danger }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotifCategory category;
  final DateTime createdAt;
  bool isRead;
  final Map<String, dynamic> metadata;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.metadata = const {},
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: d['title'] ?? d['type'] ?? 'Notification',
      body: d['body'] ?? d['message'] ?? '',
      category: _parseCategory(d['type'] ?? d['category'] ?? ''),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: d['isRead'] ?? d['read'] ?? false,
      metadata: Map<String, dynamic>.from(d),
    );
  }

  static NotifCategory _parseCategory(String type) {
    if (type.contains('sos') || type.contains('SOS') || type.contains('emergency')) return NotifCategory.sos;
    if (type.contains('location') || type.contains('journey') || type.contains('geofence')) return NotifCategory.location;
    if (type.contains('contact') || type.contains('guardian')) return NotifCategory.contact;
    if (type.contains('danger') || type.contains('zone')) return NotifCategory.danger;
    return NotifCategory.system;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _tabs = [
    (label: 'All', category: null),
    (label: '🚨 SOS', category: NotifCategory.sos),
    (label: '📍 Location', category: NotifCategory.location),
    (label: '👥 Contacts', category: NotifCategory.contact),
    (label: '⚠️ Danger', category: NotifCategory.danger),
    (label: '⚙️ System', category: NotifCategory.system),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _clearAll(NotificationProvider provider) async {
    HapticFeedback.mediumImpact();
    final cat = _tabs[_tabCtrl.index].category;
    final list = provider.getFiltered(cat);
    if (list.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Notifications', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text(
          'Delete ${list.length} notification${list.length == 1 ? '' : 's'}? This cannot be undone.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.sosRed, fontFamily: 'Poppins'))),
        ],
      ),
    );

    if (confirmed == true) {
      provider.clearAll(cat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF07071A) : const Color(0xFFF8F4FF),
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              _buildAppBar(isDark, provider),
              _buildTabBar(isDark, provider),
            ],
            body: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
              controller: _tabCtrl,
              children: _tabs.map((t) {
                return _NotifTabView(
                  notifications: provider.getFiltered(t.category),
                  isDark: isDark,
                  onTap: (n) => provider.markAsRead(n.id),
                  onDelete: (n) => provider.deleteNotification(n.id),
                  category: t.category,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(bool isDark, NotificationProvider provider) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: isDark ? const Color(0xFF0A0A1A) : Colors.white,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(colors: [Color(0xFF0A0A1A), Color(0xFF12122A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                : const LinearGradient(colors: [Colors.white, Color(0xFFF8F4FF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Notifications', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 22)),
                  Text(
                    '${provider.getUnreadCount(null)} unread · ${provider.notifications.length} total',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: isDark ? Colors.white54 : Colors.black38),
                  ),
                ]),
                Row(children: [
                  _AppBarAction(
                    icon: Icons.done_all_rounded,
                    tooltip: 'Mark all read',
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.markAllAsRead(_tabs[_tabCtrl.index].category);
                    },
                  ),
                  const SizedBox(width: 8),
                  _AppBarAction(
                    icon: Icons.delete_sweep_rounded,
                    tooltip: 'Clear all',
                    isDark: isDark,
                    color: AppColors.sosRed,
                    onTap: () => _clearAll(provider),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }

  SliverPersistentHeader _buildTabBar(bool isDark, NotificationProvider provider) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 12),
          indicator: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          indicatorPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tabs: _tabs.map((t) {
            final count = provider.getUnreadCount(t.category);
            return Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.label),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.sosRed, borderRadius: BorderRadius.circular(8)),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ],
              ]),
            );
          }).toList(),
        ),
        isDark: isDark,
      ),
    );
  }
}

// ─── Tab View ─────────────────────────────────────────────────────────────────

class _NotifTabView extends StatelessWidget {
  final List<AppNotification> notifications;
  final bool isDark;
  final void Function(AppNotification) onTap;
  final void Function(AppNotification) onDelete;
  final NotifCategory? category;

  const _NotifTabView({
    required this.notifications,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return _EmptyState(category: category, isDark: isDark);

    final grouped = <String, List<AppNotification>>{};
    for (final n in notifications) {
      final key = _dateLabel(n.createdAt);
      grouped.putIfAbsent(key, () => []).add(n);
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: grouped.length,
      itemBuilder: (_, gi) {
        final dateKey = grouped.keys.elementAt(gi);
        final items = grouped[dateKey]!;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(dateKey, style: const TextStyle(color: AppColors.primary, fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: AppColors.primary.withValues(alpha: 0.15))),
            ]),
          ),
          ...items.map((n) {
            return FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _NotifCard(
                notif: n,
                isDark: isDark,
                onTap: () => onTap(n),
                onDelete: () => onDelete(n),
              ),
            );
          }),
        ]);
      },
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) return 'Today';
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotifCard({required this.notif, required this.isDark, required this.onTap, required this.onDelete});

  static const _catConfig = {
    NotifCategory.sos:      (color: AppColors.sosRed,       icon: Icons.sos_rounded,         bg: Color(0xFFFF1744)),
    NotifCategory.location: (color: AppColors.safeGreen,    icon: Icons.location_on_rounded, bg: Color(0xFF00C853)),
    NotifCategory.contact:  (color: AppColors.primary,      icon: Icons.people_rounded,      bg: Color(0xFF6C3EE8)),
    NotifCategory.danger:   (color: AppColors.warningAmber, icon: Icons.warning_rounded,     bg: Color(0xFFFF6D00)),
    NotifCategory.system:   (color: Colors.blueGrey,        icon: Icons.info_rounded,        bg: Colors.blueGrey),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _catConfig[notif.category]!;
    final timeStr = _timeStr(notif.createdAt);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.sosRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_rounded, color: AppColors.sosRed, size: 24),
      ),
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        onDelete();
      },
      child: GestureDetector(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead ? (isDark ? AppColors.darkCard : Colors.white) : (isDark ? cfg.color.withValues(alpha: 0.07) : cfg.color.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(18),
            border: notif.isRead ? Border.all(color: Colors.transparent) : Border.all(color: cfg.color.withValues(alpha: 0.25), width: 1.2),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cfg.bg.withValues(alpha: 0.85), cfg.bg], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: cfg.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(cfg.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(notif.title, style: TextStyle(fontFamily: 'Poppins', fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 13, color: notif.isRead ? null : (isDark ? Colors.white : Colors.black87)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(timeStr, style: const TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 10)),
              ]),
              const SizedBox(height: 4),
              Text(notif.body, style: TextStyle(color: notif.isRead ? Colors.grey : (isDark ? Colors.white70 : Colors.black54), fontFamily: 'Poppins', fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: cfg.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_categoryLabel(notif.category), style: TextStyle(color: cfg.color, fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                if (!notif.isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('NEW', style: TextStyle(color: AppColors.primary, fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                const Spacer(),
                if (!notif.isRead)
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }

  String _categoryLabel(NotifCategory cat) {
    return switch (cat) {
      NotifCategory.sos => 'SOS ALERT',
      NotifCategory.location => 'LOCATION',
      NotifCategory.contact => 'CONTACT',
      NotifCategory.danger => 'DANGER ZONE',
      NotifCategory.system => 'SYSTEM',
    };
  }

  String _timeStr(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Empty State & Helpers ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final NotifCategory? category;
  final bool isDark;
  const _EmptyState({required this.category, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (emoji, title, sub) = switch (category) {
      NotifCategory.sos => ('🚨', 'No SOS Alerts', 'You\'re safe! No emergency alerts yet.'),
      NotifCategory.location => ('📍', 'No Location Alerts', 'Journey and geofence updates will appear here.'),
      NotifCategory.contact => ('👥', 'No Contact Updates', 'Guardian activity will appear here.'),
      NotifCategory.danger => ('⚠️', 'No Danger Alerts', 'Stay safe! No nearby danger zones detected.'),
      NotifCategory.system => ('⚙️', 'No System Messages', 'App updates and system info will appear here.'),
      _ => ('🔔', 'No Notifications Yet', 'All your safety alerts and updates will appear here.'),
    };

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 13)),
        ),
      ]),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final Color color;
  final VoidCallback onTap;
  const _AppBarAction({required this.icon, required this.tooltip, required this.isDark, this.color = AppColors.primary, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Icon(icon, color: color, size: 19),
      ),
    ),
  );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;
  const _TabBarDelegate(this.tabBar, {required this.isDark});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: isDark ? const Color(0xFF0A0A1A) : Colors.white, child: tabBar);
  @override double get maxExtent => tabBar.preferredSize.height + 16;
  @override double get minExtent => tabBar.preferredSize.height + 16;
  @override bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}