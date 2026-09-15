import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../legal/data/legal_documents.dart';

/// Consent sheet, shown once at sign-up.
///
/// The scroll gate is deliberate here and should stay: agreeing to terms means
/// they were actually put in front of you, and the checkbox stays disabled
/// until both documents have been scrolled to the end.
///
/// It is two steps, and the sheet says so. People read the terms to the end,
/// saw "scroll to the bottom of both tabs", and had no idea there was a
/// second tab: the tab strip looks like a heading. So each step ends in a
/// button that takes you to the next one, and the notice at the bottom names
/// what is still unread. A page short enough not to scroll counts as read
/// the moment it is shown, or nobody could ever get past it.
///
/// Reading the same documents later goes through [LegalScreen] instead, which
/// has no gate and no buttons. Text for both comes from [LegalDocuments], so
/// the two can never drift apart.
class TermsModal extends StatefulWidget {
  /// 0 opens on the terms, 1 on the privacy policy. Reading order is still
  /// enforced; this only decides what is on screen first.
  final int initialTab;

  const TermsModal({super.key, this.initialTab = 0});

  @override
  State<TermsModal> createState() => _TermsModalState();
}

class _TermsModalState extends State<TermsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _termsScrollController = ScrollController();
  final ScrollController _privacyScrollController = ScrollController();
  
  bool _hasScrolledTermsToBottom = false;
  bool _hasScrolledPrivacyToBottom = false;
  bool _checkboxChecked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(_onTabChanged);
    
    // Listen for scroll events
    _termsScrollController.addListener(_checkTermsScroll);
    _privacyScrollController.addListener(_checkPrivacyScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) => _markShortPagesRead());
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    // The second page is built when it is first shown, so its controller
    // has nothing to measure until now.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markShortPagesRead());
  }

  /// A page with nothing to scroll can never fire the scroll listener.
  void _markShortPagesRead() {
    if (!mounted) return;
    var changed = false;
    if (!_hasScrolledTermsToBottom &&
        _termsScrollController.hasClients &&
        _termsScrollController.position.maxScrollExtent <= 0) {
      _hasScrolledTermsToBottom = true;
      changed = true;
    }
    if (!_hasScrolledPrivacyToBottom &&
        _privacyScrollController.hasClients &&
        _privacyScrollController.position.maxScrollExtent <= 0) {
      _hasScrolledPrivacyToBottom = true;
      changed = true;
    }
    if (changed) setState(() {});
  }

  void _goToPrivacy() => _tabController.animateTo(1);

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _termsScrollController.dispose();
    _privacyScrollController.dispose();
    super.dispose();
  }

  void _checkTermsScroll() {
    if (_termsScrollController.position.pixels >=
        _termsScrollController.position.maxScrollExtent - 10) {
      if (!_hasScrolledTermsToBottom) {
        setState(() => _hasScrolledTermsToBottom = true);
      }
    }
  }

  void _checkPrivacyScroll() {
    if (_privacyScrollController.position.pixels >=
        _privacyScrollController.position.maxScrollExtent - 10) {
      if (!_hasScrolledPrivacyToBottom) {
        setState(() => _hasScrolledPrivacyToBottom = true);
      }
    }
  }

  bool get _canEnableCheckbox => _hasScrolledTermsToBottom && _hasScrolledPrivacyToBottom;
  bool get _canAccept => _checkboxChecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Terms and Privacy Policy',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
              ),
            ),
          ),
          
          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.neutral600,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              _tab('1. Terms', _hasScrolledTermsToBottom),
              _tab('2. Privacy', _hasScrolledPrivacyToBottom),
            ],
          ),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScrollIndicatorWrapper(
                  _buildTermsContent(),
                  _hasScrolledTermsToBottom,
                  // Read to the end: the way forward is the next page.
                  next: _hasScrolledPrivacyToBottom ? null : _goToPrivacy,
                ),
                _buildScrollIndicatorWrapper(
                  _buildPrivacyContent(),
                  _hasScrolledPrivacyToBottom,
                ),
              ],
            ),
          ),
          
          // Bottom section with checkbox and buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.neutral200)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Says what is still unread, not "both tabs".
                  if (!_canEnableCheckbox)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _whatIsLeft(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _checkboxChecked,
                          onChanged: _canEnableCheckbox
                              ? (value) => setState(() => _checkboxChecked = value ?? false)
                              : null,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I have read and agree to the Terms and Conditions and Privacy Policy',
                          style: TextStyle(
                            fontSize: 14,
                            color: _canEnableCheckbox ? AppColors.neutral900 : AppColors.neutral400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.neutral600,
                            side: BorderSide(color: AppColors.neutral300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _canAccept
                              ? () => Navigator.pop(context, true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.neutral300,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  String _whatIsLeft() {
    if (!_hasScrolledTermsToBottom && !_hasScrolledPrivacyToBottom) {
      return 'Read the Terms and Conditions to the end. The Privacy Policy comes after it.';
    }
    if (!_hasScrolledTermsToBottom) {
      return 'One left: read the Terms and Conditions to the end.';
    }
    return 'One left: read the Privacy Policy to the end.';
  }

  Widget _tab(String label, bool read) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (read) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
          ],
        ],
      ),
    );
  }

  Widget _buildScrollIndicatorWrapper(
    Widget child,
    bool hasScrolledToBottom, {
    VoidCallback? next,
  }) {
    return Stack(
      children: [
        child,
        // Read to the end, and the other page still to go: one button that
        // takes you there, where the scroll hint was.
        if (hasScrolledToBottom && next != null)
          Positioned(
            bottom: 12,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(
                'Next: Privacy Policy',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        // Scroll indicator at bottom
        if (!hasScrolledToBottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Scroll to continue',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTermsContent() => _buildDocument(
        LegalDocuments.terms,
        _termsScrollController,
      );

  Widget _buildPrivacyContent() => _buildDocument(
        LegalDocuments.privacy,
        _privacyScrollController,
      );

  /// Flat and fully expanded on purpose: consent has to show the whole
  /// document, so nothing here is collapsible.
  Widget _buildDocument(LegalDocument doc, ScrollController controller) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < doc.sections.length; i++)
            _buildSection(
              "${i + 1}. ${doc.sections[i].title}",
              doc.sections[i].body,
            ),
          const SizedBox(height: 60), // Extra space for scroll indicator
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.neutral700,
            ),
          ),
        ],
      ),
    );
  }
}
