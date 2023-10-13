// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../table_view/table_span.dart';
import 'tree_delegate.dart';
import 'tree_viewport.dart';

// TODO(Piinks):
//  * Update ALL docs
//  * Assert no reversed axes

///
enum TreeTraversalOrder {
  ///
  breadthFirst,

  ///
  depthFirst,
}

///
class TreeView extends StatefulWidget {
  ///
  const TreeView({
    super.key,
    this.primary,
    this.traversalOrder = TreeTraversalOrder.depthFirst, // mainAxis translation
    this.horizontalDetails = const ScrollableDetails.horizontal(),
    this.verticalDetails = const ScrollableDetails.vertical(),
    this.cacheExtent,
    this.diagonalDragBehavior = DiagonalDragBehavior.none,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.nodes = const <TreeNode>[],
    required TreeSpanBuilder treeSpanBuilder,
    required TreeNodeBuilder treeNodeBuilder,
  })  : _treeSpanBuilder = treeSpanBuilder,
        _treeNodeBuilder = treeNodeBuilder;

  ///
  const TreeView.simple({
    super.key,
    this.primary,
    this.traversalOrder = TreeTraversalOrder.depthFirst, // mainAxis translation
    this.horizontalDetails = const ScrollableDetails.horizontal(),
    this.verticalDetails = const ScrollableDetails.vertical(),
    this.cacheExtent,
    this.diagonalDragBehavior = DiagonalDragBehavior.none,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.nodes = const <TreeNode>[],
  })  : _treeSpanBuilder = TreeView.defaultTreeSpanBuilder,
        _treeNodeBuilder = TreeView.defaultTreeNodeBuilder;

  ///
  static TreeSpan defaultTreeSpanBuilder(TreeNode node) {
    return const TreeSpan(
        // TODO(Piinks): Account for textScaler
        extent: FixedTableSpanExtent(50.0),
        indentation: 58.0);
  }

  ///
  static Widget defaultTreeNodeBuilder(
    BuildContext context,
    TreeNode node,
  ) {
    // TODO(Piinks): Refine
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: <Widget>[
        // TODO(Piinks): Add expand/collapse handling here
        SizedBox.square(
          dimension: 48.0,
          child: AnimatedRotation(
            turns: node.expanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.arrow_right),
          ),
        ),
        const SizedBox(width: 10.0),
        Text(node.content),
      ]),
    );
  }

  ///
  TreeSpanBuilder get treeSpanBuilder => _treeSpanBuilder;
  final TreeSpanBuilder _treeSpanBuilder;

  ///
  TreeNodeBuilder get treeNodeBuilder => _treeNodeBuilder;
  final TreeNodeBuilder _treeNodeBuilder;

  /// {@macro flutter.rendering.RenderViewportBase.cacheExtent}
  final double? cacheExtent;

  /// Whether scrolling gestures should lock to one axes, allow free movement
  /// in both axes, or be evaluated on a weighted scale.
  ///
  /// Defaults to [DiagonalDragBehavior.none], locking axes to receive input one
  /// at a time.
  final DiagonalDragBehavior diagonalDragBehavior;

  /// {@macro flutter.widgets.scroll_view.primary}
  final bool? primary;

  /// The main axis of the two.
  ///
  /// Used to determine how to apply [primary] when true.
  ///
  /// This value should also be provided to the subclass of
  /// [TwoDimensionalViewport], where it is used to determine paint order of
  /// children.
  final TreeTraversalOrder traversalOrder;

  /// The configuration of the vertical Scrollable.
  ///
  /// These [ScrollableDetails] can be used to set the [AxisDirection],
  /// [ScrollController], [ScrollPhysics] and more for the vertical axis.
  final ScrollableDetails verticalDetails;

  /// The configuration of the horizontal Scrollable.
  ///
  /// These [ScrollableDetails] can be used to set the [AxisDirection],
  /// [ScrollController], [ScrollPhysics] and more for the horizontal axis.
  final ScrollableDetails horizontalDetails;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.widgets.scroll_view.keyboardDismissBehavior}
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  ///
  final List<TreeNode> nodes;

  ///
  static TreeViewState of(BuildContext context) {
    final _TreeViewScope scope =
        context.dependOnInheritedWidgetOfExactType<_TreeViewScope>()!;
    return scope._treeViewState;
  }

  @override
  TreeViewState createState() => TreeViewState();
}

class _TreeViewScope extends InheritedWidget {
  const _TreeViewScope({
    required super.child,
    required TreeViewState treeViewState,
  }) : _treeViewState = treeViewState;

  final TreeViewState _treeViewState;

  @override
  bool updateShouldNotify(_TreeViewScope old) =>
      _treeViewState != old._treeViewState;
}

///
class TreeViewState extends State<TreeView> with TickerProviderStateMixin {
  final List<TreeNode> _activeNodes = <TreeNode>[];
  final List<int> _tierForIndex = <int>[];
  final Set<TreeNode> _expandedNodes = <TreeNode>{};
  final Map<UniqueKey, Animation<double>> _activeAnimations =
      <UniqueKey, Animation<double>>{};

  @override
  void initState() {
    _buildActiveRows(tier: 0, nodes: widget.nodes);
    super.initState();
  }

  void _buildActiveRows({
    required int tier,
    required List<TreeNode> nodes,
    TreeNode? parent,
  }) {
    for (final TreeNode node in nodes) {
      node._depth = tier;
      node._parent = parent;
      _activeNodes.add(node);
      _tierForIndex.add(tier);
      if (node.children.isNotEmpty && node.expanded) {
        _expandedNodes.add(node);
        _buildActiveRows(
          tier: tier + 1,
          nodes: node.children,
          parent: node,
        );
      }
    }
  }

  void _addChildrenOf(TreeNode node) {
    final UniqueKey animationKey = UniqueKey();
    final AnimationController expandingAnimationController =
        AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    Animation<double> expandingAnimation = CurvedAnimation(
      parent: expandingAnimationController,
      curve: Curves.easeIn,
    );

    final int indexOfParentNode = _activeNodes.indexOf(node);
    _expandedNodes.add(node);
    final int insertingTier = _tierForIndex[indexOfParentNode] + 1;
    final List<TreeNode> nodesToUnpack = <TreeNode>[];
    int insertingIndex = indexOfParentNode + 1;
    for (TreeNode childNode in node.children) {
      horizontalExtent = math.max(childNode.width, horizontalExtent);
      _activeNodes.insert(insertingIndex, childNode.copyWith(animationKey));
      _tierForIndex.insert(insertingIndex, insertingTier);
      if (childNode.children.isNotEmpty && childNode.initiallyOpen) {
        nodesToUnpack.add(childNode);
      }
      insertingIndex++;
    }
    if (nodesToUnpack.isNotEmpty) {
      for (TreeNode openChildNode in nodesToUnpack) {
        _addChildrenOf(openChildNode);
      }
    }

    expandingAnimationController.addListener(() {
      setState(() {/* The animation ticked forward */});
    });
    expandingAnimationController.addStatusListener((AnimationStatus status) {
      switch (status) {
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          break;
        case AnimationStatus.dismissed:
        case AnimationStatus.completed:
          expandingAnimationController.dispose();
          _activeAnimations.remove(animationKey);
          break;
      }
    });
    _activeAnimations[animationKey] = expandingAnimation;
    expandingAnimationController.forward();
  }

  void _removeChildrenOf(TreeNode node) {
    assert(_activeNodes.contains(node));

    final UniqueKey animationKey = UniqueKey();
    final AnimationController collapsingAnimationController =
        AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 200),
    );
    Animation<double> colapsingAnimation = CurvedAnimation(
      parent: collapsingAnimationController,
      curve: Curves.easeIn,
    );

    final int indexOfParentNode = _activeNodes.indexOf(node);
    _expandedNodes.remove(node);
    final int tierOfParentNode = _tierForIndex[indexOfParentNode];
    int evaluatingIndex = indexOfParentNode + 1;
    while (evaluatingIndex < _tierForIndex.length &&
        _tierForIndex[evaluatingIndex] > tierOfParentNode) {
      // _selectedIndex = null;
      _activeNodes[evaluatingIndex] =
          _activeNodes[evaluatingIndex].copyWith(animationKey);
      evaluatingIndex++;
      // final TreeNode removedNode = _activeNodes.removeAt(evaluatingIndex);
      // _expandedNodes.remove(removedNode);
      // _tierForIndex.removeAt(evaluatingIndex);
    }

    collapsingAnimationController.addListener(() {
      setState(() {
        /* The animation ticked forward */
      });
    });
    collapsingAnimationController.addStatusListener((AnimationStatus status) {
      switch (status) {
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          break;
        case AnimationStatus.dismissed:
        case AnimationStatus.completed:
          int i = 0;
          horizontalExtent = 0;
          while (i < _activeNodes.length) {
            if (_activeNodes[i]._animationKey == animationKey) {
              _tierForIndex.removeAt(i);
              final TreeNode removedNode = _activeNodes[i];
              _activeNodes.remove(removedNode);
              _expandedNodes.remove(removedNode);
            } else {
              horizontalExtent =
                  math.max(horizontalExtent, _activeNodes[i].width);
              i++;
            }
          }
          collapsingAnimationController.dispose();
          _activeAnimations.remove(animationKey);
          break;
      }
    });
    _activeAnimations[animationKey] = colapsingAnimation;
    collapsingAnimationController.reverse();
  }

  double getRowFactorForIndex(int index) {
    final TreeNode node = _activeNodes[index];
    if (node._animationKey != null &&
        _activeAnimations.containsKey(node._animationKey!)) {
      return _activeAnimations[node._animationKey!]!.value;
    }
    return 1.0;
  }

  ///
  TreeNode getNodeForVicinity(ChildVicinity vicinity) {
    return _activeNodes[vicinity.yIndex];
  }

  @override
  Widget build(BuildContext context) {
    final Axis mainAxis = switch (widget.traversalOrder) {
      TreeTraversalOrder.breadthFirst => Axis.horizontal,
      TreeTraversalOrder.depthFirst => Axis.vertical,
    };
    return _TreeViewScope(
      treeViewState: this,
      child: _TreeView.builder(
        primary: widget.primary,
        mainAxis: mainAxis,
        horizontalDetails: widget.horizontalDetails,
        verticalDetails: widget.verticalDetails,
        cacheExtent: widget.cacheExtent,
        diagonalDragBehavior: widget.diagonalDragBehavior,
        dragStartBehavior: widget.dragStartBehavior,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
        clipBehavior: widget.clipBehavior,
        rowCount: _activeNodes.length - 1,
        treeSpanBuilder: widget.treeSpanBuilder,
        treeNodeBuilder: widget.treeNodeBuilder,
      ),
    );
  }
}

class _TreeView extends TwoDimensionalScrollView {
  _TreeView.builder({
    super.primary,
    super.mainAxis,
    super.horizontalDetails,
    super.verticalDetails,
    super.cacheExtent,
    super.diagonalDragBehavior = DiagonalDragBehavior.none,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.clipBehavior,
    required int rowCount,
    required TreeSpanBuilder treeSpanBuilder,
    required TreeNodeBuilder treeNodeBuilder,
  }) : super(
          delegate: TreeNodeBuilderDelegate(
            rowCount: rowCount,
            treeSpanBuilder: treeSpanBuilder,
            treeNodeBuilder: treeNodeBuilder,
          ),
        );

  @override
  TreeViewport buildViewport(
    BuildContext context,
    ViewportOffset verticalOffset,
    ViewportOffset horizontalOffset,
  ) {
    return TreeViewport(
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalDetails.direction,
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalDetails.direction,
      delegate: delegate as TreeNodeBuilderDelegate,
      mainAxis: mainAxis,
      cacheExtent: cacheExtent,
      clipBehavior: clipBehavior,
    );
  }
}

///
class TreeNode {
  ///
  TreeNode({
    required this.content,
    this.children = const <TreeNode>[],
    bool expanded = false,
    this.onSelectionChanged,
    this.onExpansionChanged,
  })  : _animationKey = null,
        _expanded = children.isNotEmpty && expanded;

  ///
  final String content;

  ///
  final List<TreeNode> children;

  ///
  bool get expanded => _expanded;
  bool _expanded;

  ///
  TreeNode? get parent => _parent;
  TreeNode? _parent;

  ///
  int? get depth => _depth;
  int? _depth;

  // TODO(Piinks): Move these to the TreeSpan API, similar to onEnter onExit?
  ///
  final ValueChanged<bool>? onSelectionChanged;

  ///
  final ValueChanged<bool>? onExpansionChanged;

  final UniqueKey? _animationKey;

  // See VSCode for copyWith and animate constructor if needed again

  @override
  String toString() {
    return 'Node: $content, ${children.isEmpty ? 'leaf' : 'parent, expanded: $expanded'}';
  }
}
