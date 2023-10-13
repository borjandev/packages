// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../table_view/table_span.dart';
import 'tree.dart';
import 'tree_viewport.dart';

// TODO(Piinks): Swap TableSpans for TreeSpans

/// Signature for a function that creates a [TableSpan] for a given [TreeNode]
/// in a [TreeView].
typedef TreeSpanBuilder = TableSpan Function(TreeNode node);

/// Signature for a function that creates a child [Widget] for a given
/// [TreeNode] in a [TreeView].
typedef TreeNodeBuilder = Widget Function(BuildContext context, TreeNode node);

///
mixin TreeNodeDelegateMixin on TwoDimensionalChildDelegate {
  /// The number of rows that the [TreeView] has content for, excluding
  /// collapsed rows.
  ///
  /// The [buildRow] method will be called for indices smaller than the value
  /// provided here to learn more about the extent and visual appearance of a
  /// particular row.
  ///
  /// The value returned by this getter may be an estimate of the total
  /// available rows, but [buildRow] method must provide a valid
  /// [TableSpan] for all indices smaller than this integer.
  int get rowCount;

  ///
  TableSpan buildTreeSpan(covariant TreeNode node);
}

class _TreeNodeChildBuilder {
  _TreeNodeChildBuilder({
    required this.addRepaintBoundaries,
    required this.treeNodeBuilder,
  });
  final bool addRepaintBoundaries;
  final TreeNodeBuilder treeNodeBuilder;

  Widget? _childBuilder(BuildContext context, ChildVicinity vicinity) {
    final TreeNode node = TreeView.of(context).getNodeForVicinity(vicinity);
    Widget? child =  treeNodeBuilder(context, node);
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: treeNodeBuilder(context, node));
    }
    return _TreeNodeData(child: child /* add more details from node... */);
  }
}

///
class TreeNodeBuilderDelegate extends TwoDimensionalChildBuilderDelegate
    with TreeNodeDelegateMixin {
  ///
  TreeNodeBuilderDelegate({
    required int rowCount,
    bool addRepaintBoundaries = true,
    required TreeSpanBuilder treeSpanBuilder,
    required TreeNodeBuilder treeNodeBuilder,
  })  : _treeSpanBuilder = treeSpanBuilder,
        super(
          addRepaintBoundaries: false, // Handled in _TreeNodeChildBuilder
          maxXIndex: 0,
          maxYIndex: rowCount - 1,
          builder: _TreeNodeChildBuilder(
            addRepaintBoundaries: addRepaintBoundaries,
            treeNodeBuilder: treeNodeBuilder,
          )._childBuilder,
        );

  @override
  int get rowCount => maxYIndex! + 1;
  set rowCount(int value) {
    // TODO(Piinks): remove once this assertion is added in the super class
    assert(value >= -1);
    maxYIndex = value - 1;
  }

  final TreeSpanBuilder _treeSpanBuilder;
  @override
  TableSpan buildTreeSpan(covariant TreeNode node) => _treeSpanBuilder(node);
}

///
class TreeViewParentData extends TwoDimensionalViewportParentData {

}

class _TreeNodeData extends ParentDataWidget<TreeViewParentData> {
  const _TreeNodeData({required super.child});

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is TreeViewParentData);
    // TODO(Piinks): Do some stuff here later
  }

  @override
  Type get debugTypicalAncestorWidgetClass => TreeViewport;
}

///
class TreeSpan extends TableSpan {
  ///
  const TreeSpan({
    required super.extent,
    this.indentation = 0.0,
    super.recognizerFactories = const <Type, GestureRecognizerFactory>{},
    super.onEnter,
    super.onExit,
    super.cursor = MouseCursor.defer,
    super.backgroundDecoration,
    super.foregroundDecoration,
  });

  ///
  final double indentation;
}
