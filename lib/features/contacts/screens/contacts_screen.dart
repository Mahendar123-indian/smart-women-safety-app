// lib/features/contacts/screens/contacts_screen.dart

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../providers/contact_provider.dart';
import '../models/emergency_contact_model.dart';
import '../../../core/theme/app_colors.dart';
import 'contact_monitor_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with TickerProviderStateMixin {

  late TabController _tabCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late Animation<double>   _contentFade;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _entryCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().init();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Background
          _buildBackground(size),

          SafeArea(
            child: Consumer<ContactProvider>(
              builder: (_, provider, __) => Column(
                children: [
                  // Header
                  FadeTransition(
                    opacity: _headerFade,
                    child: SlideTransition(
                      position: _headerSlide,
                      child: _buildHeader(provider),
                    ),
                  ),

                  // Banners
                  FadeTransition(
                    opacity: _contentFade,
                    child: Column(
                      children: [
                        if (provider.lastResult != null)
                          _AlertBanner(
                            result: provider.lastResult!,
                            onDismiss: provider.clearResult,
                          ),
                        if (provider.newAppUsersFound > 0)
                          _InfoBanner(
                            icon: _AppUserIconPainter(
                                color: AppColors.safeGreen),
                            color: AppColors.safeGreen,
                            text:
                            '${provider.newAppUsersFound} contact(s) joined SafeHer!',
                          ),
                      ],
                    ),
                  ),

                  // Tab bar
                  FadeTransition(
                    opacity: _contentFade,
                    child: _buildTabBar(provider),
                  ),

                  // Tab content
                  Expanded(
                    child: FadeTransition(
                      opacity: _contentFade,
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _EmergencyTab(provider: provider),
                          _PhoneTab(
                            provider: provider,
                            onPickDone: () => _tabCtrl.animateTo(0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // FAB
          Positioned(
            bottom: 24,
            right: 20,
            child: FadeTransition(
              opacity: _contentFade,
              child: Consumer<ContactProvider>(
                builder: (_, p, __) => _AddFab(
                  onTap: () => _showAddSheet(p),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────
  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0D0D1A),
                    Color(0xFF110820),
                    Color(0xFF0A0F1E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.05 + t * 20,
              right: -size.width * 0.2,
              child: _blob(size.width * 0.65,
                  AppColors.primary.withValues(alpha: 0.08)),
            ),
            Positioned(
              bottom: -size.height * 0.05 - t * 15,
              left: -size.width * 0.2,
              child: _blob(size.width * 0.60,
                  AppColors.secondary.withValues(alpha: 0.06)),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(ContactProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    'Emergency\nContacts',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _PulseDot(color: AppColors.safeGreen),
                    const SizedBox(width: 5),
                    Text(
                      '${p.activeCount} active · ${p.appUserCount} on SafeHer',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Scan button
          _ScanButton(
            isScanning: p.isScanning,
            onTap: () async {
              HapticFeedback.mediumImpact();
              await p.scanForAppUsers();
              if (mounted && p.newAppUsersFound > 0) {
                _showSnack(
                  '${p.newAppUsersFound} contacts found on SafeHer!',
                  AppColors.safeGreen,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────
  Widget _buildTabBar(ContactProvider p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.38),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'My Contacts (${p.contacts.length})'),
          const Tab(text: 'Phone Contacts'),
        ],
      ),
    );
  }

  // ── Add sheet ─────────────────────────────────────────────────
  void _showAddSheet(ContactProvider p) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOptionsSheet(
        onFromPhone: () {
          Navigator.pop(context);
          _tabCtrl.animateTo(1);
          p.loadPhoneContacts();
        },
        onManual: () {
          Navigator.pop(context);
          ContactFormSheet.show(context, p);
        },
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — EMERGENCY CONTACTS
// ═══════════════════════════════════════════════════════════════

class _EmergencyTab extends StatelessWidget {
  final ContactProvider provider;
  const _EmergencyTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.contacts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.contacts.isEmpty) {
      return _EmptyState(provider: provider);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        // Primary card
        if (provider.primary != null) ...[
          _PrimaryCard(contact: provider.primary!, provider: provider),
          const SizedBox(height: 16),
        ],

        // Stats row
        _StatsRow(provider: provider),
        const SizedBox(height: 16),

        // Contact list
        ...provider.contacts.asMap().entries.map((e) {
          return _ContactCard(
            contact: e.value,
            provider: provider,
            index: e.key,
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — PHONE CONTACTS
// ═══════════════════════════════════════════════════════════════

class _PhoneTab extends StatefulWidget {
  final ContactProvider provider;
  final VoidCallback onPickDone;
  const _PhoneTab({required this.provider, required this.onPickDone});

  @override
  State<_PhoneTab> createState() => _PhoneTabState();
}

class _PhoneTabState extends State<_PhoneTab> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.provider.phoneContacts.isEmpty) {
        widget.provider.loadPhoneContacts();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;

    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: _SearchField(
            controller: _searchCtrl,
            onChanged: (q) {
              p.filterPhoneContacts(q);
              setState(() {});
            },
            onClear: () {
              _searchCtrl.clear();
              p.filterPhoneContacts('');
              setState(() {});
            },
          ),
        ),

        if (p.isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (p.phoneContacts.isEmpty)
          _PhoneEmptyState(onReload: p.loadPhoneContacts)
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: p.phoneContacts.length,
              itemBuilder: (_, i) {
                final c = p.phoneContacts[i];
                final phone =
                c.phones.isNotEmpty ? c.phones.first.number : '';
                final added =
                p.contacts.any((ec) => ec.phone == phone);
                return _PhoneContactTile(
                  contact: c,
                  phone: phone,
                  isAdded: added,
                  onAdd: phone.isEmpty
                      ? null
                      : () => _pickRelation(c, p),
                );
              },
            ),
          ),
      ],
    );
  }

  void _pickRelation(Contact c, ContactProvider p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RelationSheet(
        contactName: c.displayName,
        onSelected: (relation, isPrimary) async {
          Navigator.pop(context);
          HapticFeedback.mediumImpact();
          final ec = await p.addFromPhoneContact(
            c,
            relation: relation,
            isPrimary: isPrimary,
          );
          if (ec != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                '${ec.name} added!${ec.isAppUser ? ' (SafeHer user 🎉)' : ''}',
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              backgroundColor: AppColors.safeGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
            widget.onPickDone();
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONTACT CARDS
// ═══════════════════════════════════════════════════════════════

class _PrimaryCard extends StatelessWidget {
  final EmergencyContact contact;
  final ContactProvider provider;
  const _PrimaryCard({required this.contact, required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: contact.appUid != null
          ? () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactMonitorScreen(
            contact: contact,
            trackedUid: contact.appUid!,
          ),
        ),
      )
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.40),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _Avatar(
              name: contact.name,
              photoUrl: contact.photoUrl,
              size: 58,
              white: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TagBadge('⭐ PRIMARY'),
                      if (contact.isAppUser) ...[
                        const SizedBox(width: 6),
                        _TagBadge('📱 SafeHer'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contact.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${contact.relation} · ${contact.phone}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontFamily: 'Poppins',
                      fontSize: 12,
                    ),
                  ),
                  if (contact.appUid != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CustomPaint(
                          size: const Size(11, 11),
                          painter: _EyeSmallPainter(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to monitor live location',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontFamily: 'Poppins',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                _WhiteCircleBtn(
                  painter: _CallIconPainter(color: AppColors.safeGreen),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    provider.callContact(contact.phone);
                  },
                ),
                const SizedBox(height: 8),
                _WhiteCircleBtn(
                  painter: _SosSmallPainter(),
                  onTap: () => _confirmSos(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSos(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _SosConfirmDialog(
        activeCount: provider.activeCount,
        onConfirm: () async {
          Navigator.pop(context);
          HapticFeedback.heavyImpact();
          await provider.sendSosAlert(
            lat: 0,
            lng: 0,
            address: 'See SafeHer app for location',
          );
        },
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final ContactProvider provider;
  final int index;
  const _ContactCard({
    required this.contact,
    required this.provider,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: contact.isPrimary
              ? AppColors.primary.withValues(alpha: 0.35)
              : contact.isActive
              ? AppColors.safeGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _Avatar(
            name: contact.name,
            photoUrl: contact.photoUrl,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: contact.isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                    if (contact.isAppUser)
                      CustomPaint(
                        size: const Size(16, 16),
                        painter: _PhoneSmallPainter(
                            color: AppColors.safeGreen),
                      ),
                  ],
                ),
                Text(
                  contact.phone,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _Chip(contact.relation, AppColors.primary),
                    if (!contact.isActive) ...[
                      const SizedBox(width: 6),
                      _Chip('Inactive', Colors.grey),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              _SmallIconBtn(
                painter: _CallIconPainter(color: AppColors.safeGreen),
                color: AppColors.safeGreen,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.callContact(contact.phone);
                },
              ),
              const SizedBox(height: 6),
              if (contact.appUid != null)
                _SmallIconBtn(
                  painter: _LocationPinPainter(color: AppColors.primary),
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactMonitorScreen(
                        contact: contact,
                        trackedUid: contact.appUid!,
                      ),
                    ),
                  ),
                )
              else
                _SmallIconBtn(
                  painter: _MoreIconPainter(color: Colors.white.withValues(alpha: 0.38)),
                  color: Colors.white.withValues(alpha: 0.15),
                  onTap: () => _showOptions(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OptionsSheet(
        contact: contact,
        onSetPrimary: () {
          Navigator.pop(context);
          provider.setPrimary(contact.id);
        },
        onToggleActive: () {
          Navigator.pop(context);
          provider.toggleActive(contact.id, !contact.isActive);
        },
        onEdit: () {
          Navigator.pop(context);
          ContactFormSheet.show(context, provider, existing: contact);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context);
        },
        onCall: () {
          Navigator.pop(context);
          provider.callContact(contact.phone);
        },
        onMonitor: contact.appUid != null
            ? () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactMonitorScreen(
                contact: contact,
                trackedUid: contact.appUid!,
              ),
            ),
          );
        }
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DeleteConfirmDialog(
        name: contact.name,
        onConfirm: () {
          Navigator.pop(context);
          provider.deleteContact(contact.id);
        },
      ),
    );
  }
}

class _PhoneContactTile extends StatelessWidget {
  final Contact contact;
  final String phone;
  final bool isAdded;
  final VoidCallback? onAdd;
  const _PhoneContactTile({
    required this.contact,
    required this.phone,
    required this.isAdded,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _Avatar(
            name: contact.displayName,
            photo: contact.photo,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  phone.isEmpty ? 'No phone number' : phone,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
          if (isAdded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.safeGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.safeGreen.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Text(
                'Added',
                style: TextStyle(
                  color: AppColors.safeGreen,
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (phone.isEmpty)
            CustomPaint(
              size: const Size(20, 20),
              painter: _BlockIconPainter(
                  color: Colors.white.withValues(alpha: 0.25)),
            )
          else
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onAdd?.call();
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM SHEETS
// ═══════════════════════════════════════════════════════════════

class _AddOptionsSheet extends StatelessWidget {
  final VoidCallback onFromPhone;
  final VoidCallback onManual;
  const _AddOptionsSheet(
      {required this.onFromPhone, required this.onManual});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 16),
          const Text(
            'Add Emergency Contact',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _SheetOptionRow(
            painter: _ContactsIconPainter(color: AppColors.primary),
            color: AppColors.primary,
            title: 'From Phone Contacts',
            sub: 'Pick from your saved contacts',
            onTap: onFromPhone,
          ),
          const SizedBox(height: 10),
          _SheetOptionRow(
            painter: _EditIconPainter(color: AppColors.secondary),
            color: AppColors.secondary,
            title: 'Enter Manually',
            sub: 'Type name, phone & relation',
            onTap: onManual,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class ContactFormSheet extends StatefulWidget {
  final EmergencyContact? existing;
  final Future<void> Function(String, String, String, bool) onSave;
  const ContactFormSheet(
      {super.key, this.existing, required this.onSave});

  static void show(BuildContext context, ContactProvider p,
      {EmergencyContact? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactFormSheet(
        existing: existing,
        onSave: (name, phone, relation, isPrimary) async {
          Navigator.pop(context);
          if (existing != null) {
            await p.updateContact(existing.copyWith(
              name: name,
              phone: phone,
              relation: relation,
              isPrimary: isPrimary,
            ));
          } else {
            await p.addContact(
              name: name,
              phone: phone,
              relation: relation,
              isPrimary: isPrimary,
            );
          }
        },
      ),
    );
  }

  @override
  State<ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<ContactFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String _relation  = 'Family';
  bool   _isPrimary = false;

  static const _relations = [
    'Family', 'Mother', 'Father', 'Sister', 'Brother',
    'Husband', 'Friend', 'Colleague', 'Neighbour', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _name     = TextEditingController(text: widget.existing?.name  ?? '');
    _phone    = TextEditingController(text: widget.existing?.phone ?? '');
    _relation   = widget.existing?.relation  ?? 'Family';
    _isPrimary  = widget.existing?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 14),
              Text(
                widget.existing != null ? 'Edit Contact' : 'Add Contact',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              _FormField(
                ctrl: _name,
                hint: 'Full Name',
                painter: _PersonSmallPainter(),
              ),
              const SizedBox(height: 10),
              _FormField(
                ctrl: _phone,
                hint: 'Phone Number',
                painter: _PhoneSmallPainter(color: AppColors.primary),
                type: TextInputType.phone,
              ),
              const SizedBox(height: 10),

              // Relation dropdown
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _relation,
                    dropdownColor: AppColors.darkCard,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    items: _relations
                        .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _relation = v!),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Primary toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isPrimary = !_isPrimary);
                },
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: _isPrimary
                            ? AppColors.primaryGradient
                            : null,
                        color: _isPrimary
                            ? null
                            : Colors.transparent,
                        border: Border.all(
                          color: _isPrimary
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: _isPrimary
                          ? Center(
                        child: CustomPaint(
                          size: const Size(12, 12),
                          painter: _CheckSmallPainter(),
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Set as primary contact',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              GestureDetector(
                onTap: () {
                  if (_name.text.trim().isEmpty ||
                      _phone.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Name and phone required',
                            style: TextStyle(fontFamily: 'Poppins')),
                      ),
                    );
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  widget.onSave(
                    _name.text.trim(),
                    _phone.text.trim(),
                    _relation,
                    _isPrimary,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.existing != null
                        ? 'Save Changes'
                        : 'Add Contact',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationSheet extends StatefulWidget {
  final String contactName;
  final void Function(String, bool) onSelected;
  const _RelationSheet(
      {required this.contactName, required this.onSelected});

  @override
  State<_RelationSheet> createState() => _RelationSheetState();
}

class _RelationSheetState extends State<_RelationSheet> {
  String _rel     = 'Family';
  bool   _primary = false;
  static const _relations = [
    'Family', 'Mother', 'Father', 'Sister', 'Brother',
    'Husband', 'Friend', 'Colleague', 'Neighbour', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            const SizedBox(height: 14),
            Text(
              'Add ${widget.contactName}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _relations
                  .map((r) => GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rel = r);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: _rel == r
                        ? AppColors.primaryGradient
                        : null,
                    color: _rel == r
                        ? null
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _rel == r
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _rel == r
                          ? Colors.white
                          : Colors.white
                          .withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _primary = !_primary);
              },
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: _primary ? AppColors.primaryGradient : null,
                      border: Border.all(
                        color: _primary
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: _primary
                        ? Center(
                      child: CustomPaint(
                        size: const Size(10, 10),
                        painter: _CheckSmallPainter(),
                      ),
                    )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Set as primary',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => widget.onSelected(_rel, _primary),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Text(
                  'Add as Emergency Contact',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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

class _OptionsSheet extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onSetPrimary;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback? onMonitor;
  const _OptionsSheet({
    required this.contact,
    required this.onSetPrimary,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
    required this.onCall,
    this.onMonitor,
  });

  @override
  Widget build(BuildContext context) {
    final rowCount = 4 +
        (onMonitor != null ? 1 : 0) +
        (!contact.isPrimary ? 1 : 0);
    final estimated = rowCount * 68.0 + 100;
    final screenH = MediaQuery.of(context).size.height;
    final initSize = (estimated / screenH).clamp(0.35, 0.80);

    return DraggableScrollableSheet(
      initialChildSize: initSize,
      minChildSize: 0.30,
      maxChildSize: 0.90,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _SheetHandle(),
            const SizedBox(height: 12),
            Text(
              contact.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            _SheetOptionRow(
              painter: _CallIconPainter(color: AppColors.safeGreen),
              color: AppColors.safeGreen,
              title: 'Call',
              sub: contact.phone,
              onTap: onCall,
            ),
            if (onMonitor != null)
              _SheetOptionRow(
                painter: _LocationPinPainter(color: AppColors.primary),
                color: AppColors.primary,
                title: 'Monitor Live Location',
                sub: 'Open tracking map',
                onTap: onMonitor!,
              ),
            if (!contact.isPrimary)
              _SheetOptionRow(
                painter: _StarIconPainter(color: AppColors.warningAmber),
                color: AppColors.warningAmber,
                title: 'Set as Primary',
                sub: 'First SOS contact',
                onTap: onSetPrimary,
              ),
            _SheetOptionRow(
              painter: contact.isActive
                  ? _ToggleOffPainter(color: Colors.grey)
                  : _ToggleOnPainter(color: AppColors.safeGreen),
              color: contact.isActive ? Colors.grey : AppColors.safeGreen,
              title: contact.isActive ? 'Deactivate' : 'Activate',
              sub: contact.isActive ? 'Stop alerts' : 'Resume alerts',
              onTap: onToggleActive,
            ),
            _SheetOptionRow(
              painter: _EditIconPainter(color: AppColors.secondary),
              color: AppColors.secondary,
              title: 'Edit',
              sub: 'Change details',
              onTap: onEdit,
            ),
            _SheetOptionRow(
              painter: _DeleteIconPainter(color: AppColors.sosRed),
              color: AppColors.sosRed,
              title: 'Delete',
              sub: 'Remove from emergency list',
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DIALOGS
// ═══════════════════════════════════════════════════════════════

class _SosConfirmDialog extends StatelessWidget {
  final int activeCount;
  final VoidCallback onConfirm;
  const _SosConfirmDialog(
      {required this.activeCount, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.sosRed.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sosRed.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.sosRed.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(32, 32),
                  painter: _SosIconPainter(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Send SOS Alert?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alert all $activeCount active contacts immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.50),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.sosGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sosRed.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Send SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final String name;
  final VoidCallback onConfirm;
  const _DeleteConfirmDialog(
      {required this.name, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.sosRed.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete $name?',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This contact will be removed from your emergency list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.sosRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.sosRed.withValues(alpha: 0.40),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.sosRed,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final ContactProvider provider;
  const _StatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          painter: _PeopleIconPainter(color: AppColors.primary),
          label: 'Total',
          value: '${provider.contacts.length}',
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _StatCard(
          painter: _CheckCirclePainter(color: AppColors.safeGreen),
          label: 'Active',
          value: '${provider.activeCount}',
          color: AppColors.safeGreen,
        ),
        const SizedBox(width: 8),
        _StatCard(
          painter: _PhoneSmallPainter(color: AppColors.secondary),
          label: 'On App',
          value: '${provider.appUserCount}',
          color: AppColors.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final CustomPainter painter;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.painter,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(18, 18),
              painter: painter,
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Poppins',
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final Uint8List? photo;
  final double size;
  final bool white;
  const _Avatar({
    required this.name,
    this.photoUrl,
    this.photo,
    required this.size,
    this.white = false,
  });

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: Image.memory(photo!,
            width: size, height: size, fit: BoxFit.cover),
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final parts = name.trim().split(' ');
    final txt = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: white ? null : AppColors.primaryGradient,
        color: white
            ? Colors.white.withValues(alpha: 0.20)
            : null,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Text(
          txt,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: size * 0.30,
          ),
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String text;
  const _TagBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5 * _anim.value),
              blurRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onTap;
  const _ScanButton({required this.isScanning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: isScanning
            ? Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        )
            : Center(
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _SyncIconPainter(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(18, 18),
              painter: _PersonAddPainter(),
            ),
            const SizedBox(width: 8),
            const Text(
              'Add Contact',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetOptionRow extends StatelessWidget {
  final CustomPainter painter;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _SheetOptionRow({
    required this.painter,
    required this.color,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(20, 20),
                  painter: painter,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(16, 16),
              painter: _ChevronRightPainter(
                  color: Colors.white.withValues(alpha: 0.25)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final CustomPainter painter;
  final Color color;
  final VoidCallback onTap;
  const _SmallIconBtn({
    required this.painter,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(17, 17),
            painter: painter,
          ),
        ),
      ),
    );
  }
}

class _WhiteCircleBtn extends StatelessWidget {
  final CustomPainter painter;
  final VoidCallback onTap;
  const _WhiteCircleBtn({required this.painter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        child: Center(
          child: CustomPaint(
            size: const Size(22, 22),
            painter: painter,
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.30),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CustomPaint(
              size: const Size(18, 18),
              painter: _SearchIconPainter(
                  color: AppColors.primary),
            ),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _CloseSmallPainter(
                    color:
                    Colors.white.withValues(alpha: 0.40)),
              ),
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final CustomPainter painter;
  final TextInputType? type;
  const _FormField({
    required this.ctrl,
    required this.hint,
    required this.painter,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CustomPaint(
              size: const Size(18, 18),
              painter: painter,
            ),
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ContactProvider provider;
  const _EmptyState({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(44, 44),
                  painter: _PeopleIconPainter(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Emergency Contacts',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add people who should be notified\nin any emergency.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.40),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ContactFormSheet.show(context, provider);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(18, 18),
                      painter: _PersonAddPainter(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Add First Contact',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneEmptyState extends StatelessWidget {
  final VoidCallback onReload;
  const _PhoneEmptyState({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(60, 60),
              painter: _ContactsIconPainter(
                  color: Colors.white.withValues(alpha: 0.18)),
            ),
            const SizedBox(height: 14),
            const Text(
              'No contacts found',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onReload,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Grant Permission & Reload',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _AlertBanner extends StatelessWidget {
  final AlertResult result;
  final VoidCallback onDismiss;
  const _AlertBanner({required this.result, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.safeGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.safeGreen.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(18, 18),
            painter: _CheckCirclePainter(color: AppColors.safeGreen),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.summary,
              style: const TextStyle(
                color: AppColors.safeGreen,
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: CustomPaint(
              size: const Size(14, 14),
              painter: _CloseSmallPainter(
                  color: AppColors.safeGreen.withValues(alpha: 0.70)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final CustomPainter icon;
  final Color color;
  final String text;
  const _InfoBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          CustomPaint(size: const Size(18, 18), painter: icon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ALL CUSTOM PAINTERS
// ════════════════════════════════════════════════════════════════

class _CallIconPainter extends CustomPainter {
  final Color color;
  const _CallIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.20, s.height * 0.08);
    path.quadraticBezierTo(s.width * 0.08, s.height * 0.22,
        s.width * 0.22, s.height * 0.38);
    path.quadraticBezierTo(
        s.width * 0.36, s.height * 0.54, s.width * 0.50, s.height * 0.68);
    path.quadraticBezierTo(s.width * 0.64, s.height * 0.82,
        s.width * 0.78, s.height * 0.82);
    path.quadraticBezierTo(s.width * 0.94, s.height * 0.82,
        s.width * 0.94, s.height * 0.66);
    path.lineTo(s.width * 0.94, s.height * 0.56);
    path.lineTo(s.width * 0.72, s.height * 0.44);
    path.lineTo(s.width * 0.60, s.height * 0.52);
    path.lineTo(s.width * 0.48, s.height * 0.52);
    path.lineTo(s.width * 0.28, s.height * 0.28);
    path.lineTo(s.width * 0.36, s.height * 0.16);
    path.lineTo(s.width * 0.32, s.height * 0.00);
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CallIconPainter o) => o.color != color;
}

class _LocationPinPainter extends CustomPainter {
  final Color color;
  const _LocationPinPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.50, 0);
    path.cubicTo(s.width * 0.18, 0, 0, s.height * 0.26, 0, s.height * 0.48);
    path.cubicTo(
        0, s.height * 0.70, s.width * 0.18, s.height * 0.84, s.width * 0.50, s.height);
    path.cubicTo(s.width * 0.82, s.height * 0.84, s.width, s.height * 0.70,
        s.width, s.height * 0.48);
    path.cubicTo(s.width, s.height * 0.26, s.width * 0.82, 0, s.width * 0.50, 0);
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.46), s.width * 0.15,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LocationPinPainter o) => o.color != color;
}

class _SearchIconPainter extends CustomPainter {
  final Color color;
  const _SearchIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
        Offset(s.width * 0.42, s.height * 0.42), s.width * 0.30, p);
    canvas.drawLine(Offset(s.width * 0.64, s.height * 0.64),
        Offset(s.width * 0.90, s.height * 0.90), p);
  }

  @override
  bool shouldRepaint(_SearchIconPainter o) => o.color != color;
}

class _SyncIconPainter extends CustomPainter {
  final Color color;
  const _SyncIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(s.width * 0.10, s.height * 0.10,
        s.width * 0.80, s.height * 0.80), -math.pi * 0.5, math.pi * 1.5, false, p);
    // Arrow tip
    final tip = Path();
    tip.moveTo(s.width * 0.50, 0);
    tip.lineTo(s.width * 0.72, s.height * 0.18);
    tip.moveTo(s.width * 0.50, 0);
    tip.lineTo(s.width * 0.28, s.height * 0.18);
    canvas.drawPath(tip, p);
  }

  @override
  bool shouldRepaint(_SyncIconPainter o) => o.color != color;
}

class _PersonAddPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Head
    canvas.drawCircle(Offset(s.width * 0.38, s.height * 0.26), s.width * 0.18, p);
    // Body
    final body = Path();
    body.moveTo(0, s.height);
    body.quadraticBezierTo(0, s.height * 0.58, s.width * 0.38, s.height * 0.58);
    body.quadraticBezierTo(s.width * 0.72, s.height * 0.58, s.width * 0.72, s.height);
    canvas.drawPath(body, p);
    // Plus
    canvas.drawLine(Offset(s.width * 0.82, s.height * 0.30),
        Offset(s.width * 0.82, s.height * 0.70), p);
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.50),
        Offset(s.width * 1.02, s.height * 0.50), p);
  }

  @override
  bool shouldRepaint(_PersonAddPainter o) => false;
}

class _PeopleIconPainter extends CustomPainter {
  final Color color;
  const _PeopleIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width * 0.36, s.height * 0.28), s.width * 0.16, p);
    final b = Path();
    b.moveTo(0, s.height);
    b.quadraticBezierTo(0, s.height * 0.60, s.width * 0.36, s.height * 0.60);
    b.quadraticBezierTo(s.width * 0.68, s.height * 0.60, s.width * 0.68, s.height);
    canvas.drawPath(b, p);
    canvas.drawCircle(Offset(s.width * 0.76, s.height * 0.22), s.width * 0.13,
        Paint()
          ..color = color.withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_PeopleIconPainter o) => o.color != color;
}

class _CheckCirclePainter extends CustomPainter {
  final Color color;
  const _CheckCirclePainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = s.width * 0.46;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    final check = Path();
    check.moveTo(cx - r * 0.42, cy);
    check.lineTo(cx - r * 0.08, cy + r * 0.40);
    check.lineTo(cx + r * 0.42, cy - r * 0.36);
    canvas.drawPath(check,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_CheckCirclePainter o) => o.color != color;
}

class _PhoneSmallPainter extends CustomPainter {
  final Color color;
  const _PhoneSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.20, 0, s.width * 0.60, s.height),
            Radius.circular(s.width * 0.12)),
        p);
    canvas.drawCircle(
        Offset(s.width * 0.50, s.height * 0.84),
        s.width * 0.06,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PhoneSmallPainter o) => o.color != color;
}

class _EditIconPainter extends CustomPainter {
  final Color color;
  const _EditIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.15, s.height * 0.75);
    path.lineTo(s.width * 0.10, s.height * 0.92);
    path.lineTo(s.width * 0.28, s.height * 0.88);
    path.lineTo(s.width * 0.88, s.height * 0.28);
    path.lineTo(s.width * 0.72, s.height * 0.12);
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_EditIconPainter o) => o.color != color;
}

class _DeleteIconPainter extends CustomPainter {
  final Color color;
  const _DeleteIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Bin body
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.14, s.height * 0.28, s.width * 0.72, s.height * 0.68),
            const Radius.circular(4)),
        p);
    // Lid
    canvas.drawLine(Offset(0, s.height * 0.26),
        Offset(s.width, s.height * 0.26), p);
    // Handle
    canvas.drawLine(Offset(s.width * 0.36, s.height * 0.26),
        Offset(s.width * 0.36, s.height * 0.10), p);
    canvas.drawLine(Offset(s.width * 0.64, s.height * 0.26),
        Offset(s.width * 0.64, s.height * 0.10), p);
    canvas.drawLine(Offset(s.width * 0.36, s.height * 0.10),
        Offset(s.width * 0.64, s.height * 0.10), p);
    // Lines inside
    canvas.drawLine(Offset(s.width * 0.38, s.height * 0.44),
        Offset(s.width * 0.38, s.height * 0.82), p);
    canvas.drawLine(Offset(s.width * 0.62, s.height * 0.44),
        Offset(s.width * 0.62, s.height * 0.82), p);
  }

  @override
  bool shouldRepaint(_DeleteIconPainter o) => o.color != color;
}

class _StarIconPainter extends CustomPainter {
  final Color color;
  const _StarIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    const n = 5;
    final cx = s.width / 2;
    final cy = s.height / 2;
    final outer = s.width * 0.46;
    final inner = s.width * 0.20;
    final path = Path();
    for (int i = 0; i < n * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = (i * math.pi / n) - math.pi / 2;
      final x = cx + r * math.cos(a);
      final y = cy + r * math.sin(a);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_StarIconPainter o) => o.color != color;
}

class _ToggleOnPainter extends CustomPainter {
  final Color color;
  const _ToggleOnPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, s.height * 0.20, s.width, s.height * 0.60),
            Radius.circular(s.height * 0.30)),
        Paint()..color = color.withValues(alpha: 0.30));
    canvas.drawCircle(Offset(s.width * 0.72, s.height * 0.50), s.height * 0.28,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ToggleOnPainter o) => o.color != color;
}

class _ToggleOffPainter extends CustomPainter {
  final Color color;
  const _ToggleOffPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, s.height * 0.20, s.width, s.height * 0.60),
            Radius.circular(s.height * 0.30)),
        Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(Offset(s.width * 0.28, s.height * 0.50), s.height * 0.28,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ToggleOffPainter o) => o.color != color;
}

class _ContactsIconPainter extends CustomPainter {
  final Color color;
  const _ContactsIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.12, 0, s.width * 0.76, s.height),
            const Radius.circular(4)),
        p);
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.36), s.width * 0.16, p);
    canvas.drawLine(Offset(s.width * 0.26, s.height * 0.72),
        Offset(s.width * 0.74, s.height * 0.72), p);
  }

  @override
  bool shouldRepaint(_ContactsIconPainter o) => o.color != color;
}

class _SosIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.46,
        Paint()
          ..color = AppColors.sosRed.withValues(alpha: 0.20)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, cy), s.width * 0.46,
        Paint()
          ..color = AppColors.sosRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // S O S letters approximated as exclamation
    final p = Paint()
      ..color = AppColors.sosRed
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 2.5, cy - s.height * 0.28, 5, s.height * 0.32),
            const Radius.circular(2)),
        p);
    canvas.drawCircle(Offset(cx, cy + s.height * 0.16), 3, p);
  }

  @override
  bool shouldRepaint(_SosIconPainter o) => false;
}

class _ChevronRightPainter extends CustomPainter {
  final Color color;
  const _ChevronRightPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.30, s.height * 0.18);
    path.lineTo(s.width * 0.70, s.height * 0.50);
    path.lineTo(s.width * 0.30, s.height * 0.82);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevronRightPainter o) => o.color != color;
}

class _CloseSmallPainter extends CustomPainter {
  final Color color;
  const _CloseSmallPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, 0), Offset(s.width, s.height), p);
    canvas.drawLine(Offset(s.width, 0), Offset(0, s.height), p);
  }

  @override
  bool shouldRepaint(_CloseSmallPainter o) => o.color != color;
}

class _CheckSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(s.width * 0.15, s.height * 0.50);
    path.lineTo(s.width * 0.42, s.height * 0.75);
    path.lineTo(s.width * 0.85, s.height * 0.25);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CheckSmallPainter o) => false;
}

class _BlockIconPainter extends CustomPainter {
  final Color color;
  const _BlockIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.46,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.drawLine(
        Offset(cx - s.width * 0.30, cy + s.height * 0.30),
        Offset(cx + s.width * 0.30, cy - s.height * 0.30),
        Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_BlockIconPainter o) => o.color != color;
}

class _MoreIconPainter extends CustomPainter {
  final Color color;
  const _MoreIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()..color = color;
    final cx = s.width / 2;
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(cx, s.height * (0.25 + i * 0.25)), 2.0, paint);
    }
  }

  @override
  bool shouldRepaint(_MoreIconPainter o) => o.color != color;
}

class _EyeSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final eye = Path();
    eye.moveTo(0, s.height * 0.50);
    eye.cubicTo(s.width * 0.25, s.height * 0.15, s.width * 0.75, s.height * 0.15,
        s.width, s.height * 0.50);
    eye.cubicTo(s.width * 0.75, s.height * 0.85, s.width * 0.25, s.height * 0.85,
        0, s.height * 0.50);
    canvas.drawPath(eye, p);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 0.14,
        Paint()..color = Colors.white.withValues(alpha: 0.65));
  }

  @override
  bool shouldRepaint(_EyeSmallPainter o) => false;
}

class _SosSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width * 0.44,
        Paint()..color = AppColors.sosRed.withValues(alpha: 0.80));
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SosSmallPainter o) => false;
}

class _PersonSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width * 0.50, s.height * 0.28), s.width * 0.20, p);
    final body = Path();
    body.moveTo(0, s.height);
    body.quadraticBezierTo(0, s.height * 0.60, s.width * 0.50, s.height * 0.60);
    body.quadraticBezierTo(s.width, s.height * 0.60, s.width, s.height);
    canvas.drawPath(body, p);
  }

  @override
  bool shouldRepaint(_PersonSmallPainter o) => false;
}

class _AppUserIconPainter extends CustomPainter {
  final Color color;
  const _AppUserIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s.width * 0.38, s.height * 0.28), s.width * 0.17, p);
    final body = Path();
    body.moveTo(0, s.height);
    body.quadraticBezierTo(0, s.height * 0.60, s.width * 0.38, s.height * 0.60);
    body.quadraticBezierTo(s.width * 0.72, s.height * 0.60, s.width * 0.72, s.height);
    canvas.drawPath(body, p);
    // Plus badge
    canvas.drawLine(Offset(s.width * 0.80, s.height * 0.28),
        Offset(s.width * 0.80, s.height * 0.68), p);
    canvas.drawLine(Offset(s.width * 0.60, s.height * 0.48),
        Offset(s.width, s.height * 0.48), p);
  }

  @override
  bool shouldRepaint(_AppUserIconPainter o) => o.color != color;
}