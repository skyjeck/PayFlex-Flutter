import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:payflex/api_call/loan_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/widget/app_feedback.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({Key? key}) : super(key: key);

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen>
    with SingleTickerProviderStateMixin {
  final LoanService _loanService = LoanService();

  // Screen & API States
  bool _isLoadingLoans = true;
  bool _isSubmitting = false;
  bool _isRepaying = false;
  bool _isHistoryExpanded = false;

  // Real API Loan Data
  Map<String, dynamic>? _activeLoan;
  Map<String, dynamic>? _pendingLoan;
  List<dynamic> _allLoans = [];

  // Calculator State
  double _requestedAmount = 100000;
  int _selectedTenureMonths = 3;
  final double _monthlyInterestRate = 0.05; // 5% per month

  // Animation controller for history section
  late AnimationController _historyAnimCtrl;
  late Animation<double> _historyAnim;

  // Calculated getters for Loan Calculator
  double get _totalInterest =>
      _requestedAmount * _monthlyInterestRate * _selectedTenureMonths;
  double get _totalRepayment => _requestedAmount + _totalInterest;
  double get _monthlyRepayment => _totalRepayment / _selectedTenureMonths;

  @override
  void initState() {
    super.initState();
    _historyAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _historyAnim = CurvedAnimation(
      parent: _historyAnimCtrl,
      curve: Curves.easeInOut,
    );
    _fetchLoans();
  }

  @override
  void dispose() {
    _historyAnimCtrl.dispose();
    super.dispose();
  }

  /// Fetches the current user's loans from backend API
  Future<void> _fetchLoans() async {
    setState(() => _isLoadingLoans = true);

    try {
      final response = await _loanService.getMyLoans();

      if (response != null && response['success'] == true) {
        final List<dynamic> loans = response['loans'] ?? response['data'] ?? [];

        Map<String, dynamic>? active;
        Map<String, dynamic>? pending;

        for (var loan in loans) {
          final String status = (loan['status'] ?? '').toString().toLowerCase();
          final num remaining = loan['remainingBalance'] ?? 0;

          if (status == 'active' || (status == 'approved' && remaining > 0)) {
            active ??= Map<String, dynamic>.from(loan);
          } else if (status == 'pending') {
            pending ??= Map<String, dynamic>.from(loan);
          }
        }

        if (mounted) {
          setState(() {
            _allLoans = loans;
            _activeLoan = active;
            _pendingLoan = pending;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        AppFeedback.error(
          context,
          error.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLoans = false);
    }
  }

  /// Handles the backend API call to apply for a loan
  Future<void> _handleLoanSubmission(BuildContext modalContext) async {
    try {
      final response = await _loanService.applyForLoan(
        amount: _requestedAmount,
        tenureMonths: _selectedTenureMonths,
        purpose: 'Personal/Business Loan',
      );

      if (!mounted) return;

      Navigator.pop(modalContext);

      AppFeedback.success(
        context,
        response['message'] ?? 'Loan application submitted successfully!',
      );

      setState(() {
        _requestedAmount = 100000;
        _selectedTenureMonths = 3;
      });

      await _fetchLoans();
    } catch (error) {
      if (!mounted) return;

      Navigator.pop(modalContext);

      AppFeedback.error(
        context,
        error.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Handles the backend API call to repay a loan
  Future<void> _handleLoanRepayment({
    required String loanId,
    double? customAmount,
    required BuildContext modalContext,
  }) async {
    try {
      final response = await _loanService.repayLoan(
        loanId: loanId,
        customAmount: customAmount,
      );

      if (!mounted) return;

      Navigator.pop(modalContext);

      AppFeedback.success(
        context,
        response['message'] ?? 'Loan repayment processed successfully!',
      );

      await _fetchLoans();
    } catch (error) {
      if (!mounted) return;

      Navigator.pop(modalContext);

      AppFeedback.error(
        context,
        error.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isRepaying = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatAmount(num? val) {
    if (val == null) return '₦0.00';
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '₦${formatter.format(val)}';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Under Review';
      case 'completed':
      case 'paid':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'overdue':
        return 'Overdue';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
        return const Color(0xFF00C853);
      case 'pending':
        return const Color(0xFFFFC107);
      case 'completed':
      case 'paid':
        return const Color(0xFF448AFF);
      case 'rejected':
        return PayFlexColors.error;
      case 'overdue':
        return const Color(0xFFFF5252);
      default:
        return PayFlexColors.textSecondary;
    }
  }

  void _onRepayLoanPressed() {
    if (_activeLoan != null) {
      _showRepaymentBottomSheet(_activeLoan!);
      return;
    }

    final activeOrApproved = _allLoans.firstWhere((l) {
      final st = (l['status'] ?? '').toString().toLowerCase();
      final num rem = l['remainingBalance'] ?? 0;
      return st == 'active' || st == 'approved' || rem > 0;
    }, orElse: () => null);

    if (activeOrApproved != null) {
      _showRepaymentBottomSheet(Map<String, dynamic>.from(activeOrApproved));
      return;
    }

    AppFeedback.info(
      context,
      'You currently do not have an active loan to repay.',
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PayFlexColors.background,
      appBar: AppBar(
        backgroundColor: PayFlexColors.background,
        elevation: 0,
        title: const Text(
          'Loans',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: PayFlexColors.textPrimary,
            ),
            onPressed: _fetchLoans,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLoans,
        color: PayFlexColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── QUICK ACTIONS BAR ──────────────────────────────────────────
              _buildTopActionBar(),
              const SizedBox(height: 16),

              // ── LOADING ───────────────────────────────────────────────────
              if (_isLoadingLoans) ...[
                _buildShimmerCard(),
                const SizedBox(height: 16),
                _buildShimmerCard(height: 90),
              ] else ...[
                // ── ACTIVE LOAN CARD ─────────────────────────────────────
                if (_activeLoan != null) _buildActiveLoanCard(_activeLoan!),

                // ── PENDING LOAN CARD ─────────────────────────────────────
                if (_pendingLoan != null) ...[
                  if (_activeLoan != null) const SizedBox(height: 16),
                  _buildPendingLoanCard(_pendingLoan!),
                ],

                // ── NO ACTIVE LOAN BANNER ─────────────────────────────────
                if (_activeLoan == null && _pendingLoan == null)
                  _buildNoActiveLoanBanner(),

                // ── LOAN HISTORY ──────────────────────────────────────────
                if (_allLoans.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildHistorySection(),
                ],
              ],

              const SizedBox(height: 28),

              // ── LOAN CALCULATOR ────────────────────────────────────────────
              Row(
                children: const [
                  Icon(
                    Icons.calculate_rounded,
                    color: PayFlexColors.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loan Calculator',
                    style: TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCalculatorCard(),

              const SizedBox(height: 20),

              // ── APPLY BUTTON ────────────────────────────────────────────────
              const SizedBox(height: 8),

              // ── ELIGIBILITY NOTE ────────────────────────────────────────────
              Center(
                child: Text(
                  'Loans are subject to eligibility checks & approval.',
                  style: TextStyle(
                    color: PayFlexColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── WIDGET BUILDERS ────────────────────────────────────────────────────────

  Widget _buildShimmerCard({double height = 200}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: PayFlexColors.primary),
      ),
    );
  }

  Widget _buildNoActiveLoanBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PayFlexColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PayFlexColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: PayFlexColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No active loans. You\'re eligible to apply for a loan below.',
              style: TextStyle(
                color: PayFlexColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACTIVE LOAN CARD ────────────────────────────────────────────────────────

  Widget _buildActiveLoanCard(Map<String, dynamic> loan) {
    final double principal = (loan['amount'] as num?)?.toDouble() ?? 0.0;
    final double remaining =
        (loan['remainingBalance'] as num?)?.toDouble() ?? 0.0;
    final double totalRepayment =
        (loan['totalRepayment'] as num?)?.toDouble() ?? 0.0;
    final double amountPaid = (loan['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final double monthlyEMI = (loan['monthlyEMI'] as num?)?.toDouble() ?? 0.0;
    final int tenure = (loan['tenureMonths'] as num?)?.toInt() ?? 0;
    final double rawInterest =
        (loan['interestRate'] as num?)?.toDouble() ??
        (_monthlyInterestRate * 100);
    final String interestDisplay = rawInterest > 0 && rawInterest < 1.0
        ? '${(rawInterest * 100).toStringAsFixed(0)}%'
        : '${rawInterest.toStringAsFixed(0)}%';
    final String status = (loan['status'] ?? 'active').toString();
    final String? nextPayment = loan['nextPaymentDate']?.toString();
    final String? startDate =
        loan['startDate']?.toString() ?? loan['createdAt']?.toString();
    final String? loanId =
        loan['id']?.toString() ??
        loan['loanId']?.toString() ??
        loan['_id']?.toString();

    final double progress = totalRepayment > 0
        ? (amountPaid / totalRepayment).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2E1C), Color(0xFF0F382C), Color(0xFF133D30)],
        ),
        border: Border.all(color: const Color(0xFF1E5C3A).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: PayFlexColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header Row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outstanding Loan',
                      style: TextStyle(
                        color: Color(0xFF8FBFA4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (loanId != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: ${loanId.length > 8 ? loanId.substring(0, 8).toUpperCase() : loanId.toUpperCase()}',
                        style: const TextStyle(
                          color: Color(0xFF4D8C6A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),

          // ── Remaining Balance ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAmount(remaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'Remaining Balance',
                        style: TextStyle(
                          color: Color(0xFF6BAA87),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAmount(principal),
                      style: const TextStyle(
                        color: Color(0xFF8FBFA4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Principal',
                      style: TextStyle(color: Color(0xFF4D8C6A), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Progress Bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Repayment Progress',
                      style: TextStyle(
                        color: const Color(0xFF6BAA87),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% Paid',
                      style: const TextStyle(
                        color: Color(0xFF4DFF91),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFF1E5C3A),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00C853),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Divider(
              color: const Color(0xFF1E5C3A).withOpacity(0.5),
              height: 1,
            ),
          ),

          // ── Details Grid ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildLoanDetailTile(
                        label: 'Amount Paid',
                        value: _formatAmount(amountPaid),
                        icon: Icons.payments_outlined,
                        iconColor: const Color(0xFF00C853),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLoanDetailTile(
                        label: 'Total Repayment',
                        value: _formatAmount(totalRepayment),
                        icon: Icons.account_balance_outlined,
                        iconColor: const Color(0xFF8FBFA4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildLoanDetailTile(
                        label: 'Monthly EMI',
                        value: _formatAmount(monthlyEMI),
                        icon: Icons.calendar_month_outlined,
                        iconColor: const Color(0xFF448AFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLoanDetailTile(
                        label: 'Interest Rate',
                        value: '$interestDisplay / mo',
                        icon: Icons.percent_rounded,
                        iconColor: const Color(0xFFFFC107),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildLoanDetailTile(
                        label: 'Tenure',
                        value: '$tenure Months',
                        icon: Icons.timelapse_rounded,
                        iconColor: const Color(0xFFB39DDB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLoanDetailTile(
                        label: nextPayment != null
                            ? 'Next Payment'
                            : 'Start Date',
                        value: nextPayment != null
                            ? _formatDate(nextPayment)
                            : _formatDate(startDate),
                        icon: Icons.event_rounded,
                        iconColor: const Color(0xFFFF7043),
                      ),
                    ),
                  ],
                ),
                if (loanId != null && loanId.isNotEmpty && remaining > 0) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRepaymentBottomSheet(loan),
                      icon: const Icon(
                        Icons.payment_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Repay Loan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PayFlexColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanDetailTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F14).withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E5C3A).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF4D8C6A),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PENDING LOAN CARD ───────────────────────────────────────────────────────

  Widget _buildPendingLoanCard(Map<String, dynamic> loan) {
    final double amount = (loan['amount'] as num?)?.toDouble() ?? 0.0;
    final int tenure = (loan['tenureMonths'] as num?)?.toInt() ?? 0;
    final String purpose = loan['purpose']?.toString() ?? 'N/A';
    final String? dateApplied =
        loan['createdAt']?.toString() ?? loan['startDate']?.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1400),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5C4200).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFFFFC107),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Application Under Review',
                      style: TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (dateApplied != null)
                      Text(
                        'Applied ${_formatDate(dateApplied)}',
                        style: const TextStyle(
                          color: Color(0xFF9C7A00),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge('pending'),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: const Color(0xFF5C4200).withOpacity(0.3), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPendingDetailItem(
                  label: 'Amount Requested',
                  value: _formatAmount(amount),
                ),
              ),
              Expanded(
                child: _buildPendingDetailItem(
                  label: 'Tenure',
                  value: '$tenure Months',
                ),
              ),
              Expanded(
                child: _buildPendingDetailItem(
                  label: 'Purpose',
                  value: purpose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFC107).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF9C7A00),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your application is being reviewed. You cannot apply for another loan while this is pending.',
                    style: TextStyle(
                      color: Color(0xFF9C7A00),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDetailItem({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B5200), fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD4A800),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ─── LOAN HISTORY SECTION ────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    // Loans that are not active or pending (completed, rejected, etc.)
    final historyLoans = _allLoans.where((loan) {
      final s = (loan['status'] ?? '').toString().toLowerCase();
      return s != 'active' && s != 'pending';
    }).toList();

    // If there's no history beyond active/pending, skip the section
    if (historyLoans.isEmpty && _allLoans.length <= 1) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header tap to expand/collapse
        GestureDetector(
          onTap: () {
            setState(() => _isHistoryExpanded = !_isHistoryExpanded);
            if (_isHistoryExpanded) {
              _historyAnimCtrl.forward();
            } else {
              _historyAnimCtrl.reverse();
            }
          },
          child: Container(
            color: Colors.transparent,
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: PayFlexColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Loan History',
                  style: TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: PayFlexColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${historyLoans.length} loan${historyLoans.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: PayFlexColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isHistoryExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: PayFlexColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _historyAnim,
          child: Column(
            children: [
              const SizedBox(height: 12),
              ...historyLoans.asMap().entries.map((entry) {
                final i = entry.key;
                final loan = entry.value as Map<String, dynamic>;
                return _HistoryLoanTile(
                  loan: loan,
                  index: i,
                  formatAmount: _formatAmount,
                  formatDate: _formatDate,
                  statusLabel: _statusLabel,
                  statusColor: _statusColor,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ─── CALCULATOR CARD ─────────────────────────────────────────────────────────

  Widget _buildCalculatorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PayFlexColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How much do you need?',
            style: TextStyle(color: PayFlexColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '₦${NumberFormat('#,##0', 'en_US').format(_requestedAmount)}',
            style: const TextStyle(
              color: PayFlexColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: PayFlexColors.primary,
              inactiveTrackColor: PayFlexColors.iconBg,
              thumbColor: PayFlexColors.primaryDark,
              overlayColor: PayFlexColors.primaryLight,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: _requestedAmount,
              min: 10000,
              max: 500000,
              divisions: 49,
              onChanged: (val) => setState(() => _requestedAmount = val),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '₦10,000',
                style: TextStyle(color: PayFlexColors.textMuted, fontSize: 11),
              ),
              Text(
                '₦500,000',
                style: TextStyle(color: PayFlexColors.textMuted, fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
            'Tenure (Months)',
            style: TextStyle(color: PayFlexColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),

          // Tenure Selector Chips
          Row(
            children: [3, 6, 12, 24].map((months) {
              final isSelected = _selectedTenureMonths == months;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTenureMonths = months),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? PayFlexColors.primary
                          : PayFlexColors.iconBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : PayFlexColors.border,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: PayFlexColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        '$months Mo',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : PayFlexColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Divider(color: PayFlexColors.divider),
          const SizedBox(height: 12),

          // Summary Breakdown
          _buildSummaryRow(
            'Monthly Payment',
            _formatAmount(_monthlyRepayment),
            isBold: true,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Interest Rate',
            '${(_monthlyInterestRate * 100).toInt()}% / month',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow('Total Interest', _formatAmount(_totalInterest)),
          const SizedBox(height: 8),
          _buildSummaryRow('Total Repayment', _formatAmount(_totalRepayment)),
        ],
      ),
    );
  }

  Widget _buildTopActionBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PayFlexColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _onRepayLoanPressed,
              icon: const Icon(
                Icons.payment_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Repay Loan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PayFlexColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pendingLoan != null ? null : _showConfirmationDialog,
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: PayFlexColors.primary,
                size: 18,
              ),
              label: const Text(
                'Apply Loan',
                style: TextStyle(
                  color: PayFlexColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(
                  color: PayFlexColors.primary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isBold
                ? PayFlexColors.textPrimary
                : PayFlexColors.textSecondary,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold
                ? PayFlexColors.primaryDark
                : PayFlexColors.textPrimary,
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── APPLY BUTTON ─────────────────────────────────────────────────────────────

  // ─── CONFIRMATION BOTTOM SHEET ───────────────────────────────────────────────

  void _showConfirmationDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PayFlexColors.surface,
      isDismissible: !_isSubmitting,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PayFlexColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Confirm Loan Application',
                      style: TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Review the details below before submitting.',
                      style: TextStyle(
                        color: PayFlexColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PayFlexColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PayFlexColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Amount Requested',
                            _formatAmount(_requestedAmount),
                          ),
                          const SizedBox(height: 10),
                          const Divider(
                            color: PayFlexColors.divider,
                            height: 1,
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                            'Tenure',
                            '$_selectedTenureMonths Months',
                          ),
                          const SizedBox(height: 10),
                          const Divider(
                            color: PayFlexColors.divider,
                            height: 1,
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                            'Interest Rate',
                            '${(_monthlyInterestRate * 100).toInt()}% / month',
                          ),
                          const SizedBox(height: 10),
                          const Divider(
                            color: PayFlexColors.divider,
                            height: 1,
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                            'Total Interest',
                            _formatAmount(_totalInterest),
                          ),
                          const SizedBox(height: 10),
                          const Divider(
                            color: PayFlexColors.divider,
                            height: 1,
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                            'Monthly Repayment',
                            _formatAmount(_monthlyRepayment),
                            isBold: true,
                          ),
                          const SizedBox(height: 10),
                          const Divider(
                            color: PayFlexColors.divider,
                            height: 1,
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                            'Total Repayment',
                            _formatAmount(_totalRepayment),
                            isBold: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Disclaimer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PayFlexColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.shield_outlined,
                            color: PayFlexColors.primaryDark,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'By applying, you agree to our loan terms and repayment schedule.',
                              style: TextStyle(
                                color: PayFlexColors.primaryDark,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PayFlexColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                setModalState(() => _isSubmitting = true);
                                await _handleLoanSubmission(modalContext);
                              },
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Application',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── REPAYMENT BOTTOM SHEET ──────────────────────────────────────────────────

  void _showRepaymentBottomSheet(Map<String, dynamic> loan) {
    final String loanId = (loan['id'] ?? loan['loanId'] ?? loan['_id'] ?? '')
        .toString();
    final double remaining =
        (loan['remainingBalance'] as num?)?.toDouble() ?? 0.0;
    final double monthlyEMI = (loan['monthlyEMI'] as num?)?.toDouble() ?? 0.0;

    int selectedOption =
        0; // 0: Standard EMI, 1: Full Balance, 2: Custom Amount
    final customAmountCtrl = TextEditingController(
      text: monthlyEMI > 0 && monthlyEMI <= remaining
          ? monthlyEMI.toStringAsFixed(2)
          : remaining.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: PayFlexColors.surface,
      isDismissible: !_isRepaying,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            double? getRepaymentAmount() {
              if (selectedOption == 0) {
                return monthlyEMI > 0 && monthlyEMI <= remaining
                    ? monthlyEMI
                    : remaining;
              } else if (selectedOption == 1) {
                return remaining;
              } else {
                return double.tryParse(customAmountCtrl.text);
              }
            }

            final double? amountToPay = getRepaymentAmount();
            final bool isValid =
                amountToPay != null &&
                amountToPay > 0 &&
                amountToPay <= (remaining + 0.01);

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PayFlexColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Repay Loan',
                      style: TextStyle(
                        color: PayFlexColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remaining Balance: ${_formatAmount(remaining)}',
                      style: const TextStyle(
                        color: PayFlexColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Option 0: Monthly EMI
                    GestureDetector(
                      onTap: () {
                        setModalState(() {
                          selectedOption = 0;
                          customAmountCtrl.text =
                              (monthlyEMI > 0 && monthlyEMI <= remaining
                                      ? monthlyEMI
                                      : remaining)
                                  .toStringAsFixed(2);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: selectedOption == 0
                              ? PayFlexColors.primaryLight
                              : PayFlexColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedOption == 0
                                ? PayFlexColors.primary
                                : PayFlexColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedOption == 0
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedOption == 0
                                  ? PayFlexColors.primaryDark
                                  : PayFlexColors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pay Next EMI',
                                    style: TextStyle(
                                      color: PayFlexColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _formatAmount(
                                      monthlyEMI > 0 && monthlyEMI <= remaining
                                          ? monthlyEMI
                                          : remaining,
                                    ),
                                    style: const TextStyle(
                                      color: PayFlexColors.primaryDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Option 1: Full Remaining Balance
                    GestureDetector(
                      onTap: () {
                        setModalState(() {
                          selectedOption = 1;
                          customAmountCtrl.text = remaining.toStringAsFixed(2);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: selectedOption == 1
                              ? PayFlexColors.primaryLight
                              : PayFlexColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedOption == 1
                                ? PayFlexColors.primary
                                : PayFlexColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedOption == 1
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedOption == 1
                                  ? PayFlexColors.primaryDark
                                  : PayFlexColors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Full Loan Settlement',
                                    style: TextStyle(
                                      color: PayFlexColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _formatAmount(remaining),
                                    style: const TextStyle(
                                      color: PayFlexColors.primaryDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Option 2: Custom Amount
                    GestureDetector(
                      onTap: () {
                        setModalState(() {
                          selectedOption = 2;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedOption == 2
                              ? PayFlexColors.primaryLight
                              : PayFlexColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedOption == 2
                                ? PayFlexColors.primary
                                : PayFlexColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  selectedOption == 2
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selectedOption == 2
                                      ? PayFlexColors.primaryDark
                                      : PayFlexColors.textMuted,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Custom Amount',
                                  style: TextStyle(
                                    color: PayFlexColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            if (selectedOption == 2) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: customAmountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setModalState(() {}),
                                decoration: InputDecoration(
                                  prefixText: '₦ ',
                                  labelText: 'Enter amount',
                                  filled: true,
                                  fillColor: PayFlexColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PayFlexColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            (_isRepaying || !isValid || amountToPay == null)
                            ? null
                            : () async {
                                setModalState(() => _isRepaying = true);
                                await _handleLoanRepayment(
                                  loanId: loanId,
                                  customAmount: amountToPay,
                                  modalContext: modalContext,
                                );
                              },
                        child: _isRepaying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                amountToPay != null
                                    ? 'Pay ${_formatAmount(amountToPay)}'
                                    : 'Process Repayment',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── HISTORY LOAN TILE ────────────────────────────────────────────────────────

class _HistoryLoanTile extends StatefulWidget {
  final Map<String, dynamic> loan;
  final int index;
  final String Function(num?) formatAmount;
  final String Function(String?) formatDate;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;

  const _HistoryLoanTile({
    required this.loan,
    required this.index,
    required this.formatAmount,
    required this.formatDate,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  State<_HistoryLoanTile> createState() => _HistoryLoanTileState();
}

class _HistoryLoanTileState extends State<_HistoryLoanTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final String status = (loan['status'] ?? 'unknown').toString();
    final double amount = (loan['amount'] as num?)?.toDouble() ?? 0.0;
    final int tenure = (loan['tenureMonths'] as num?)?.toInt() ?? 0;
    final double totalRepayment =
        (loan['totalRepayment'] as num?)?.toDouble() ?? 0.0;
    final double amountPaid = (loan['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final double remaining =
        (loan['remainingBalance'] as num?)?.toDouble() ?? 0.0;
    final double monthlyEMI = (loan['monthlyEMI'] as num?)?.toDouble() ?? 0.0;
    final String? createdAt = loan['createdAt']?.toString();
    final String? purpose = loan['purpose']?.toString();

    final statusColor = widget.statusColor(status);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: PayFlexColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? statusColor.withOpacity(0.3)
                : PayFlexColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Collapsed Row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status.toLowerCase() == 'completed' ||
                              status.toLowerCase() == 'paid'
                          ? Icons.check_circle_rounded
                          : status.toLowerCase() == 'rejected'
                          ? Icons.cancel_rounded
                          : Icons.receipt_long_rounded,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.formatAmount(amount),
                          style: const TextStyle(
                            color: PayFlexColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$tenure months  •  ${widget.formatDate(createdAt)}',
                          style: const TextStyle(
                            color: PayFlexColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.statusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: PayFlexColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded Details ──────────────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    Divider(color: PayFlexColors.divider, height: 1),
                    const SizedBox(height: 12),
                    _expandedRow(
                      'Total Repayment',
                      widget.formatAmount(totalRepayment),
                    ),
                    const SizedBox(height: 8),
                    _expandedRow(
                      'Amount Paid',
                      widget.formatAmount(amountPaid),
                    ),
                    const SizedBox(height: 8),
                    _expandedRow(
                      'Remaining Balance',
                      widget.formatAmount(remaining),
                    ),
                    const SizedBox(height: 8),
                    _expandedRow(
                      'Monthly EMI',
                      widget.formatAmount(monthlyEMI),
                    ),
                    if (purpose != null && purpose.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _expandedRow('Purpose', purpose),
                    ],
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: PayFlexColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: PayFlexColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
