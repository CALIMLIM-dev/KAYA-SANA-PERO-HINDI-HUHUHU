import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/legal_documents.dart';

/// Reads the Terms and Privacy Policy. No consent, no gate.
///
/// The profile used to open the sign-up consent sheet, so looking up one line
/// of the privacy policy meant scrolling twenty screens of text through two
/// tabs, ticking a box, and pressing Accept on terms already accepted.
///
/// Reading and consenting are different jobs. Consent has to prove the document
/// was put in front of someone, which is why the sheet gates its button on
/// scrolling. Reading only has to help somebody find one clause, which is why
/// every section starts collapsed: the whole document becomes a short list of
/// headings you can skim in one flick instead of a wall of text you scroll
/// through hunting for a word.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, this.initialTab = 0});

  /// 0 = Terms, 1 = Privacy. Lets "Privacy Policy" open on the right document.
  final int initialTab;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Terms and Privacy',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.neutral200)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.neutral600,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: const [Tab(text: 'Terms'), Tab(text: 'Privacy')],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DocumentView(document: LegalDocuments.terms),
          _DocumentView(document: LegalDocuments.privacy),
        ],
      ),
    );
  }
}

class _DocumentView extends StatefulWidget {
  const _DocumentView({required this.document});

  final LegalDocument document;

  @override
  State<_DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<_DocumentView>
    with AutomaticKeepAliveClientMixin {
  /// Which sections are open. Kept here rather than inside each tile so
  /// switching tabs and coming back does not silently collapse everything the
  /// reader had opened.
  final Set<int> _open = {};

  // Without this, moving between tabs rebuilds the list and loses _open.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final sections = widget.document.sections;
    final allOpen = _open.length == sections.length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: sections.length + 2,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Header(
            title: widget.document.title,
            allOpen: allOpen,
            onToggleAll: () => setState(() {
              if (allOpen) {
                _open.clear();
              } else {
                _open.addAll(List.generate(sections.length, (i) => i));
              }
            }),
          );
        }

        if (index == sections.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Last updated ${LegalDocuments.lastUpdated}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.neutral400),
            ),
          );
        }

        final i = index - 1;
        return _SectionTile(
          number: i + 1,
          section: sections[i],
          expanded: _open.contains(i),
          onTap: () => setState(() {
            if (!_open.remove(i)) _open.add(i);
          }),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.allOpen,
    required this.onToggleAll,
  });

  final String title;
  final bool allOpen;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: AppColors.neutral900,
            ),
          ),
        ),
        TextButton(
          onPressed: onToggleAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            allOpen ? 'Collapse all' : 'Expand all',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.number,
    required this.section,
    required this.expanded,
    required this.onTap,
  });

  final int number;
  final LegalSection section;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: expanded ? AppColors.primary.withValues(alpha: 0.35)
                              : AppColors.neutral200,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The number is the anchor people quote back at you, so it
                  // stays visible whether the section is open or not.
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: expanded
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: expanded ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 34, right: 4),
                  child: Text(
                    section.body,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.65,
                      color: AppColors.neutral700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
