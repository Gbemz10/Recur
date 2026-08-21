import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart' show formatNaira;
import '../data/spending_store.dart';
import '../models/spending.dart';
import '../ui/ui.dart';

/// The transactions behind one category.
///
/// This screen exists mainly so a category total is auditable. A breakdown
/// nobody can drill into is asking to be trusted on a number the user has no
/// way to check, and the first wrong category they spot with no way to fix it
/// is the moment they stop believing the whole feature. So every row here can
/// be recategorised, and the correction can be generalised to the merchant.
class CategoryTransactionsScreen extends StatefulWidget {
  const CategoryTransactionsScreen({
    super.key,
    required this.store,
    required this.category,
  });

  final SpendingStore store;
  final SpendCategory category;

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen> {
  List<SpendTransaction>? _transactions;
  String? _error;

  /// How many exist for this category, from the server. Used to say so, and
  /// to know when to stop asking.
  int _total = 0;
  bool _hasMore = false;
  bool _loadingMore = false;

  /// Page size. Small enough that the first screenful arrives quickly, large
  /// enough that most categories in a month need only one request.
  static const int _pageSize = 50;

  /// Ids with a recategorise request in flight, so a row cannot be tapped
  /// into two overlapping PATCHes. Same guard the dashboard uses for status
  /// changes.
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await widget.store.transactionsFor(widget.category, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _transactions = page.transactions;
        _total = page.total;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't load these transactions — try again.");
    }
  }

  /// Appends the next page.
  ///
  /// Guarded by [_loadingMore] because the scroll listener fires on every
  /// frame near the bottom, and without it one flick queues a dozen identical
  /// requests that all append the same rows.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final current = _transactions;
    if (current == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await widget.store.transactionsFor(
        widget.category,
        offset: current.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _transactions = [...current, ...page.transactions];
        _total = page.total;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: "Couldn't load more — try again.",
        variant: AppAlertVariant.danger,
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _recategorize(SpendTransaction txn) async {
    if (_pending.contains(txn.id)) return;

    final choice = await showAppSheet<_RecategorizeChoice>(
      context,
      builder: (_) => _CategoryPickerSheet(transaction: txn),
    );
    if (choice == null || !mounted) return;

    setState(() => _pending.add(txn.id));
    try {
      final moved = await widget.store.recategorize(
        txn,
        choice.category,
        applyToFuture: choice.applyToFuture,
      );
      if (!mounted) return;
      // Reload rather than removing the row locally: the transaction has left
      // this category, and if `applyToFuture` was set, so have others.
      await _load();
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: moved > 1
            ? 'Moved $moved transactions to ${choice.category.label.toLowerCase()}'
            : 'Moved to ${choice.category.label.toLowerCase()}',
        variant: AppAlertVariant.success,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: e.message, variant: AppAlertVariant.danger);
    } finally {
      if (mounted) setState(() => _pending.remove(txn.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        surfaceTintColor: Colors.transparent,
        title: Text(widget.category.label),
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.huge),
          Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Center(child: AppButton(label: 'Try again', onPressed: _load)),
        ],
      );
    }

    final transactions = _transactions;
    if (transactions == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: const [
          AppSkeletonListTile(),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
          AppSkeletonListTile(),
        ],
      );
    }

    if (transactions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.huge),
          AppEmptyState(
            icon: widget.category.icon,
            title: 'Nothing here this month',
            message: 'No ${widget.category.label.toLowerCase()} transactions in this period.',
          ),
        ],
      );
    }

    final total = transactions.fold<double>(0, (sum, t) => sum + t.amount);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      // Fetch the next page while the last one is still on screen, so the list
      // grows before the user reaches the end of it. Waiting for the actual
      // bottom means every page turn is a visible stall.
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 400) {
            _loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
          // One header, the rows, and a footer that is either a spinner or
          // nothing.
          itemCount: transactions.length + (_hasMore ? 2 : 1),
          separatorBuilder: (_, index) => index == 0
              ? const SizedBox(height: AppSpacing.lg)
              : const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    // The real count, not how many have loaded. "50
                    // transactions" while more are on the way is a lie that
                    // corrects itself on scroll, which is worse than either
                    // number alone.
                    _total == 1 ? '1 transaction' : '$_total transactions',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted(context)),
                  ),
                  Text(
                    formatNaira(total),
                    style: AppTypography.money(
                        size: 14, weight: FontWeight.w700, color: AppColors.ink(context)),
                  ),
                ],
              );
            }

            // Footer slot, only present while there is more to fetch.
            if (index > transactions.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              );
            }

            final txn = transactions[index - 1];
            return _TransactionRow(
              transaction: txn,
              isPending: _pending.contains(txn.id),
              onTap: () => _recategorize(txn),
            );
          },
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.isPending,
    required this.onTap,
  });

  final SpendTransaction transaction;
  final bool isPending;
  final VoidCallback onTap;

  static String _shortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isPending ? 0.5 : 1,
      child: AppCard(
        onTap: isPending ? null : onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaction.displayName,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Marks a category the user set by hand, so a
                      // correction visibly stuck rather than looking
                      // identical to a guess.
                      if (transaction.isUserCategorized) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(Icons.push_pin_rounded, size: 12, color: AppColors.muted(context)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // The raw narration, kept verbatim in the ledger face. It
                  // is unreadable by design: it is the string the user's own
                  // bank alert showed them, and it is how they recognise a
                  // charge they would otherwise dispute.
                  Text(
                    transaction.narration,
                    style: AppTypography.mono(
                        size: 11, weight: FontWeight.w400, color: AppColors.muted(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatNaira(transaction.amount),
                  style: AppTypography.money(
                      size: 14, weight: FontWeight.w700, color: AppColors.ink(context)),
                ),
                const SizedBox(height: 3),
                Text(
                  _shortDate(transaction.date),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ picker

class _RecategorizeChoice {
  const _RecategorizeChoice({required this.category, required this.applyToFuture});
  final SpendCategory category;
  final bool applyToFuture;
}

/// Category picker, with the "do this for future charges too" prompt.
///
/// The toggle defaults to on, and is the reason this is a sheet rather than a
/// long-press menu: teaching Recur once is the actual value, and burying it
/// behind a second interaction means almost nobody finds it. It is still a
/// visible switch rather than an invisible side effect, because silently
/// creating a standing rule from one tap is more behaviour than a tap implies.
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({required this.transaction});

  final SpendTransaction transaction;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  bool _applyToFuture = true;

  @override
  Widget build(BuildContext context) {
    final current = widget.transaction.category;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Move to', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.transaction.displayName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              for (final category in SpendCategory.values)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBR),
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: category.tint(context),
                      borderRadius: AppRadius.smBR,
                    ),
                    child: Icon(category.icon, size: 18, color: category.color(context)),
                  ),
                  title: Text(category.label, style: Theme.of(context).textTheme.bodyLarge),
                  trailing: category == current
                      ? const Icon(Icons.check_rounded, size: 20, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(
                    _RecategorizeChoice(category: category, applyToFuture: _applyToFuture),
                  ),
                ),
            ],
          ),
        ),
        const LedgerDivider(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl + MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apply to future charges', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Everything from this merchant lands here from now on.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted(context)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _applyToFuture,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _applyToFuture = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
