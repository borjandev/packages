// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../table_view/table_span.dart';
import 'tree.dart';
import 'tree_delegate.dart';

/// A widget through which a portion of a Table of [Widget] children are viewed,
/// typically in combination with a [TableView].
class TreeViewport extends TwoDimensionalViewport {
  /// Creates a viewport for [Widget]s that extend and scroll in both
  /// horizontal and vertical dimensions.
  const TreeViewport({
    super.key,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required TreeNodeDelegateMixin super.delegate,
    required super.mainAxis,
    super.cacheExtent,
    super.clipBehavior,
  });

  @override
  RenderTreeViewport createRenderObject(BuildContext context) {
    return RenderTreeViewport(
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalAxisDirection,
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalAxisDirection,
      mainAxis: mainAxis,
      cacheExtent: cacheExtent,
      clipBehavior: clipBehavior,
      delegate: delegate as TreeNodeDelegateMixin,
      childManager: context as TwoDimensionalChildManager,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTreeViewport renderObject,
  ) {
    renderObject
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalOffset = verticalOffset
      ..verticalAxisDirection = verticalAxisDirection
      ..mainAxis = mainAxis
      ..cacheExtent = cacheExtent
      ..clipBehavior = clipBehavior
      ..delegate = delegate as TreeNodeDelegateMixin;
  }
}

///
class RenderTreeViewport extends RenderTwoDimensionalViewport {
  /// Creates a viewport for [RenderBox] objects in a table format of rows and
  /// columns.
  RenderTreeViewport({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required TreeNodeDelegateMixin super.delegate,
    required super.mainAxis,
    required super.childManager,
    super.cacheExtent,
    super.clipBehavior,
  });

  @override
  TreeNodeDelegateMixin get delegate => super.delegate as TreeNodeDelegateMixin;

  @override
  set delegate(TreeNodeDelegateMixin value) {
    super.delegate = value;
  }

  Map<int, _Span> _rowMetrics = <int, _Span>{};
  int? _firstVisibleNode;
  int? _lastVisibleNode;

  // TODO(Piinks): Where to clip when animating?
  // * expanding?
  // * hasChildren?
  // * animation layout offset?
  // * parent vicinity?
  @override
  TreeViewParentData parentDataOf(RenderBox child) =>
      child.parentData! as TreeViewParentData;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TreeViewParentData) {
      child.parentData = TreeViewParentData();
    }
  }

  void _updateAllMetrics() {

  }

  void _updateFirstAndLastVisibleNode() {}

  @override
  void layoutChildSequence() {
    if (needsDelegateRebuild || didResize) {
      // Recomputes the table metrics, invalidates any cached information.
      _updateAllMetrics();
    } else {
      // Updates the visible cells based on cached table metrics.
      _updateFirstAndLastVisibleNode();
    }

    if (_firstVisibleNode == null) {
      assert(_lastVisibleNode == null);
      return;
    }

    // Layout visible rows.
    for (int node = _firstVisibleNode!; node <= _lastVisibleNode!; node++) {}
  }
}

class _Span
    with Diagnosticable
    implements HitTestTarget, MouseTrackerAnnotation {
  double get leadingOffset => _leadingOffset;
  late double _leadingOffset;

  double get extent => _extent;
  late double _extent;

  TableSpan get configuration => _configuration!;
  TableSpan? _configuration;

  double get trailingOffset => leadingOffset + extent;

  // ---- Span Management ----

  void update({
    required TableSpan configuration,
    required double leadingOffset,
    required double extent,
  }) {
    _leadingOffset = leadingOffset;
    _extent = extent;
    if (configuration == _configuration) {
      return;
    }
    _configuration = configuration;
    // Only sync recognizers if they are in use already.
    if (_recognizers != null) {
      _syncRecognizers();
    }
  }

  void dispose() {
    _disposeRecognizers();
  }

  // ---- Recognizers management ----

  Map<Type, GestureRecognizer>? _recognizers;

  void _syncRecognizers() {
    if (configuration.recognizerFactories.isEmpty) {
      _disposeRecognizers();
      return;
    }
    final Map<Type, GestureRecognizer> newRecognizers =
        <Type, GestureRecognizer>{};
    for (final Type type in configuration.recognizerFactories.keys) {
      assert(!newRecognizers.containsKey(type));
      newRecognizers[type] = _recognizers?.remove(type) ??
          configuration.recognizerFactories[type]!.constructor();
      assert(
        newRecognizers[type].runtimeType == type,
        'GestureRecognizerFactory of type $type created a GestureRecognizer of '
        'type ${newRecognizers[type].runtimeType}. The '
        'GestureRecognizerFactory must be specialized with the type of the '
        'class that it returns from its constructor method.',
      );
      configuration.recognizerFactories[type]!
          .initializer(newRecognizers[type]!);
    }
    _disposeRecognizers(); // only disposes the ones that where not re-used above.
    _recognizers = newRecognizers;
  }

  void _disposeRecognizers() {
    if (_recognizers != null) {
      for (final GestureRecognizer recognizer in _recognizers!.values) {
        recognizer.dispose();
      }
      _recognizers = null;
    }
  }

  // ---- HitTestTarget ----

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent &&
        configuration.recognizerFactories.isNotEmpty) {
      if (_recognizers == null) {
        _syncRecognizers();
      }
      assert(_recognizers != null);
      for (final GestureRecognizer recognizer in _recognizers!.values) {
        recognizer.addPointer(event);
      }
    }
  }

  // ---- MouseTrackerAnnotation ----

  @override
  MouseCursor get cursor => configuration.cursor;

  @override
  PointerEnterEventListener? get onEnter => configuration.onEnter;

  @override
  PointerExitEventListener? get onExit => configuration.onExit;

  @override
  bool get validForMouseTracker => true;
}
