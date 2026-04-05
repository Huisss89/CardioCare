import 'package:flutter/material.dart';

class CollapsibleCategorySection extends StatefulWidget {
  final List<Map<String, dynamic>> categories;

  const CollapsibleCategorySection({super.key, required this.categories});

  @override
  State<CollapsibleCategorySection> createState() =>
      _CollapsibleCategorySectionState();
}

class _CollapsibleCategorySectionState extends State<CollapsibleCategorySection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleExpansion,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_rounded,
                      color: Color(0xFF667EEA), size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Blood Pressure Category Guide',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: const Icon(Icons.expand_more,
                        color: Color(0xFF718096), size: 24),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: Align(
              heightFactor: _isExpanded ? 1.0 : 0.0,
              child: SizeTransition(
                axisAlignment: 1.0,
                sizeFactor: _controller,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: widget.categories.map((cat) {
                      return BPCategoryAccordion(
                        key: ValueKey(cat['title']),
                        title: cat['title'] as String,
                        range: cat['range'] as String,
                        details: cat['details'] as String,
                        color: cat['color'] as Color,
                        icon: cat['icon'] as IconData,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BPCategoryAccordion extends StatefulWidget {
  final String title;
  final String range;
  final String details;
  final Color color;
  final IconData icon;

  const BPCategoryAccordion({
    super.key,
    required this.title,
    required this.range,
    required this.details,
    required this.color,
    required this.icon,
  });

  @override
  State<BPCategoryAccordion> createState() => _BPCategoryAccordionState();
}

class _BPCategoryAccordionState extends State<BPCategoryAccordion>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (_isExpanded) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.range,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.color.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_controller),
                    child: Icon(
                      Icons.expand_more,
                      color: widget.color,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isExpanded ? null : 0,
            child: _isExpanded
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                    ),
                    child: Text(
                      widget.details,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
