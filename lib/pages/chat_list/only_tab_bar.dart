import 'package:flutter/material.dart';

class OnlyTabBar<T> extends StatefulWidget {
  const OnlyTabBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.label,
    required this.items,
  });

  final T selected;
  final void Function(T) onSelected;
  final String Function(T) label;
  final List<T> items;

  @override
  State<OnlyTabBar<T>> createState() => _OnlyTabBarState<T>();
}

class _OnlyTabBarState<T> extends State<OnlyTabBar<T>>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  void _handleTabSelection() {
    setState(() {
      final item = widget.items.elementAt(_tabController.index);
      widget.onSelected(item);
    });
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.items.indexWhere(
      (item) => item == widget.selected,
    );

    _tabController = TabController(
      length: widget.items.length,
      vsync: this,
      initialIndex: initialIndex == -1 ? 0 : initialIndex,
    );
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  List<Tab> get tabs =>
      widget.items.map((item) => Tab(text: widget.label(item))).toList();

  @override
  Widget build(BuildContext context) {
    return TabBar(controller: _tabController, tabs: tabs);
  }
}
