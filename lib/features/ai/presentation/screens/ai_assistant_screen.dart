import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rate_limiter.dart';
import '../../../../core/utils/report_export.dart';
import '../../data/ai_repository.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _loading = false;
  bool _started = false;
  ReportBundle? _latestReport;

  /// Phone / bottom-nav only (same breakpoint as AppShell mobile).
  bool _isCompactComposer(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 900;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = ref.read(l10nProvider);
      setState(() {
        _messages.add(
          _Msg(text: l10n.aiWelcome, fromUser: false, at: DateTime.now()),
        );
      });
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> _suggestions(AppL10n l10n) => l10n.isHindi
      ? const [
          'इस ऐप में बजट कैसे सेट करें?',
          'इस महीने का खर्च सारांश दो',
          'PDF रिपोर्ट बनाओ',
          'CSV रिपोर्ट डाउनलोड करो',
        ]
      : const [
          'How do I set a budget in this app?',
          'Summarize my spending this month',
          'Create a PDF report',
          'Export my activity as CSV',
        ];

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;
    final l10n = ref.read(l10nProvider);

    setState(() {
      _started = true;
      _messages.add(_Msg(text: text, fromUser: true, at: DateTime.now()));
      _loading = true;
      if (preset == null) _controller.clear();
    });
    _scrollToEnd();

    try {
      final reply = await ref.read(aiRepositoryProvider).ask(text);
      if (!mounted) return;
      setState(() {
        if (reply.report != null) _latestReport = reply.report;
        _messages.add(
          _Msg(
            text: reply.text,
            fromUser: false,
            at: DateTime.now(),
            report: reply.report,
          ),
        );
      });
    } on RateLimitException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _Msg(
            text: e.message,
            fromUser: false,
            isError: true,
            at: DateTime.now(),
          ),
        );
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _Msg(
            text: e.message.contains('AI unavailable')
                ? l10n.aiUnavailable
                : e.message,
            fromUser: false,
            isError: true,
            at: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _Msg(text: '$e', fromUser: false, isError: true, at: DateTime.now()),
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToEnd();
      _focus.requestFocus();
    }
  }

  void _newChat() {
    final l10n = ref.read(l10nProvider);
    ref.read(aiRepositoryProvider).resetChat();
    setState(() {
      _started = false;
      _latestReport = null;
      _messages
        ..clear()
        ..add(
          _Msg(text: l10n.aiWelcome, fromUser: false, at: DateTime.now()),
        );
    });
    _focus.requestFocus();
  }

  Future<void> _downloadReport(ReportBundle report, ReportFormat format) async {
    try {
      final msg = await downloadReportBundle(report, prefer: format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _shareReport(ReportBundle report, ReportFormat format) async {
    try {
      final msg = await shareReportBundle(report, prefer: format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final showChips = !_started || _messages.length <= 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(l10n.aiTitle),
        actions: [
          if (_latestReport != null)
            PopupMenuButton<String>(
              tooltip: l10n.downloadReport,
              icon: const Icon(Icons.download_outlined),
              onSelected: (v) async {
                final report = _latestReport!;
                switch (v) {
                  case 'pdf':
                    await _downloadReport(report, ReportFormat.pdf);
                  case 'csv':
                    await _downloadReport(report, ReportFormat.csv);
                  case 'both':
                    await _downloadReport(report, ReportFormat.both);
                  case 'share_pdf':
                    await _shareReport(report, ReportFormat.pdf);
                  case 'share_csv':
                    await _shareReport(report, ReportFormat.csv);
                  case 'share_both':
                    await _shareReport(report, ReportFormat.both);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'pdf', child: Text(l10n.downloadPdf)),
                PopupMenuItem(value: 'csv', child: Text(l10n.downloadCsv)),
                PopupMenuItem(value: 'both', child: Text(l10n.downloadBoth)),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'share_pdf', child: Text(l10n.sharePdf)),
                PopupMenuItem(value: 'share_csv', child: Text(l10n.shareCsv)),
                PopupMenuItem(value: 'share_both', child: Text(l10n.shareBoth)),
              ],
            ),
          IconButton(
            tooltip: l10n.aiNewChat,
            onPressed: _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length +
                  (showChips ? 1 : 0) +
                  (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _messages.length) {
                  final m = _messages[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Bubble(message: m),
                      if (m.report != null)
                        _ReportActions(
                          report: m.report!,
                          l10n: l10n,
                          onDownload: _downloadReport,
                          onShare: _shareReport,
                        ),
                    ],
                  );
                }
                final index = i - _messages.length;
                if (showChips && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tip in _suggestions(l10n))
                          ActionChip(
                            avatar: const Icon(Icons.chat_bubble_outline,
                                size: 16),
                            label: Text(tip),
                            onPressed: _loading ? null : () => _send(tip),
                          ),
                      ],
                    ),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                );
              },
            ),
          ),
          Material(
            elevation: 18,
            color: Colors.white,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.azure, width: 2),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                12,
                _isCompactComposer(context) ? 8 : 12,
                12,
                _isCompactComposer(context) ? 8 : 12,
              ),
              child: Builder(
                builder: (context) {
                  final isCompact = _isCompactComposer(context);
                  // Theme FilledButton uses Size.fromHeight(50) = infinite min
                  // width, which steals the whole Row and collapses the field.
                  final sendStyle = FilledButton.styleFrom(
                    backgroundColor: AppColors.azure,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.azure.withValues(alpha: 0.5),
                    minimumSize: Size(isCompact ? 44 : 96, isCompact ? 44 : 48),
                    maximumSize: Size(isCompact ? 44 : 160, isCompact ? 44 : 48),
                    fixedSize: isCompact ? const Size(44, 44) : null,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 0 : 18,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          enabled: !_loading,
                          minLines: 1,
                          maxLines: isCompact ? 1 : 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: TextStyle(
                            fontSize: isCompact ? 15 : 16,
                            color: Colors.black87,
                            height: 1.25,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: l10n.isHindi
                                ? 'संदेश लिखें…'
                                : 'Write a message…',
                            hintStyle: TextStyle(
                              color: AppColors.azure.withValues(alpha: 0.65),
                              fontSize: isCompact ? 14 : 15,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFEFF6FF),
                            prefixIcon: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.azure,
                              size: 20,
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: isCompact ? 40 : 44,
                              minHeight: isCompact ? 40 : 44,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.azure,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.azure,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.azure,
                                width: 2,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.azure.withValues(alpha: 0.4),
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: isCompact ? 10 : 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _loading ? null : () => _send(),
                        style: sendStyle,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : isCompact
                                ? const Icon(Icons.send_rounded, size: 20)
                                : Text(l10n.aiSend),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportActions extends StatelessWidget {
  const _ReportActions({
    required this.report,
    required this.l10n,
    required this.onDownload,
    required this.onShare,
  });

  final ReportBundle report;
  final AppL10n l10n;
  final Future<void> Function(ReportBundle, ReportFormat) onDownload;
  final Future<void> Function(ReportBundle, ReportFormat) onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 8, bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (report.hasPdf)
            FilledButton.tonalIcon(
              onPressed: () => onDownload(report, ReportFormat.pdf),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(l10n.downloadPdf),
            ),
          if (report.hasCsv)
            FilledButton.tonalIcon(
              onPressed: () => onDownload(report, ReportFormat.csv),
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: Text(l10n.downloadCsv),
            ),
          OutlinedButton.icon(
            onPressed: () => onShare(report, ReportFormat.both),
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(l10n.shareReport),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Msg message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.azure.withValues(alpha: 0.15),
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.azure,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fromUser
                    ? AppColors.azure
                    : (message.isError
                        ? Colors.red.shade50
                        : scheme.surface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(fromUser ? 18 : 4),
                  bottomRight: Radius.circular(fromUser ? 4 : 18),
                ),
                border: fromUser
                    ? null
                    : Border.all(
                        color: message.isError
                            ? Colors.red.shade200
                            : AppColors.cardBorder,
                      ),
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: fromUser
                      ? Colors.white
                      : (message.isError ? Colors.red.shade800 : null),
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (fromUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Msg {
  _Msg({
    required this.text,
    required this.fromUser,
    required this.at,
    this.isError = false,
    this.report,
  });

  final String text;
  final bool fromUser;
  final bool isError;
  final DateTime at;
  final ReportBundle? report;
}
