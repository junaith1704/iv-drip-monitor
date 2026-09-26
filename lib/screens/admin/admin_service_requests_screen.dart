import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/service_request_service.dart';
import '../../services/auth_service.dart';
import '../../models/service_request_model.dart';
import '../../theme/clinical_theme.dart';

class AdminServiceRequestsScreen extends StatefulWidget {
  const AdminServiceRequestsScreen({super.key});

  @override
  State<AdminServiceRequestsScreen> createState() => _AdminServiceRequestsScreenState();
}

class _AdminServiceRequestsScreenState extends State<AdminServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleResolve(BuildContext context, ServiceRequestModel req) async {
    final authService = context.read<AuthService>();
    final requestService = context.read<ServiceRequestService>();
    final adminName = authService.currentUser?.name ?? 'Clinical Admin';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Service Ticket'),
        content: Text(
          'Mark ticket "${req.issueText}" as resolved? This will archive the ticket and clear it from the open queue.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ClinicalTheme.statusRunning),
            child: const Text('MARK RESOLVED'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await requestService.resolveRequest(
      requestId: req.requestId,
      resolvedBy: adminName,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service request resolved and removed from active queue.'),
          backgroundColor: ClinicalTheme.statusRunning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestService = context.watch<ServiceRequestService>();

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      body: Column(
        children: [
          // Clinical Tab Switcher
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ClinicalTheme.primaryBlue,
              unselectedLabelColor: ClinicalTheme.textSecondary,
              indicatorColor: ClinicalTheme.primaryBlue,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.pending_actions_outlined, size: 20),
                  text: 'ACTIVE OPEN QUEUE',
                ),
                Tab(
                  icon: Icon(Icons.inventory_2_outlined, size: 20),
                  text: 'RESOLVED ARCHIVE',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ClinicalTheme.borderSubtle),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Active Open Requests (Resolve button marks resolved & disappears from this view)
                StreamBuilder<List<ServiceRequestModel>>(
                  stream: requestService.streamOpenRequests(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final openRequests = snap.data ?? [];

                    if (openRequests.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ClinicalTheme.borderSubtle),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 48, color: ClinicalTheme.statusRunning),
                              SizedBox(height: 12),
                              Text(
                                'No Open Service Requests',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ClinicalTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'All nurse tickets and biomedical requests have been resolved.',
                                style: TextStyle(fontSize: 12, color: ClinicalTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: openRequests.length,
                      itemBuilder: (context, index) {
                        final req = openRequests[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ClinicalTheme.statusStuckBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: ClinicalTheme.statusStuckBg,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: ClinicalTheme.statusStuckBorder),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.error_outline, size: 14, color: ClinicalTheme.statusStuck),
                                              SizedBox(width: 4),
                                              Text(
                                                'OPEN TICKET',
                                                style: TextStyle(
                                                  color: ClinicalTheme.statusStuck,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (req.deviceName != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: ClinicalTheme.background,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${req.deviceName!} (${req.deviceId ?? ""})',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: ClinicalTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      DateFormat('yyyy-MM-dd • HH:mm').format(req.raisedAt),
                                      style: const TextStyle(fontSize: 11, color: ClinicalTheme.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Nurse's exact issue text (Read-Only per spec: admin cannot modify or edit)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: ClinicalTheme.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ClinicalTheme.borderSubtle),
                                  ),
                                  child: Text(
                                    req.issueText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: ClinicalTheme.deepNavy,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Footer: Nurse info and Resolve Action
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: ClinicalTheme.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Submitted by: ${req.raisedByName ?? req.raisedBy}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: ClinicalTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _handleResolve(context, req),
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('RESOLVE'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ClinicalTheme.statusRunning,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // Tab 2: Resolved Archive
                StreamBuilder<List<ServiceRequestModel>>(
                  stream: requestService.streamAllRequests(),
                  builder: (context, snap) {
                    final all = snap.data ?? [];
                    final resolvedList = all.where((r) => r.isResolved).toList();

                    if (resolvedList.isEmpty) {
                      return const Center(
                        child: Text(
                          'No archived resolved tickets yet.',
                          style: TextStyle(color: ClinicalTheme.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: resolvedList.length,
                      itemBuilder: (context, index) {
                        final req = resolvedList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ClinicalTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ClinicalTheme.statusRunningBg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: ClinicalTheme.statusRunningBorder),
                                        ),
                                        child: const Text(
                                          'RESOLVED',
                                          style: TextStyle(
                                            color: ClinicalTheme.statusRunning,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (req.deviceName != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          req.deviceName!,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    req.resolvedAt != null
                                        ? 'Resolved on ${DateFormat('MMM d, HH:mm').format(req.resolvedAt!)}'
                                        : 'Resolved',
                                    style: const TextStyle(fontSize: 11, color: ClinicalTheme.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                req.issueText,
                                style: const TextStyle(fontSize: 13, color: ClinicalTheme.deepNavy),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Raised by: ${req.raisedByName ?? req.raisedBy} • Resolved by: ${req.resolvedBy ?? "Admin"}',
                                style: const TextStyle(fontSize: 11, color: ClinicalTheme.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
