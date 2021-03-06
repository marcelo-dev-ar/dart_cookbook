// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library barback.graph.group_runner;

import 'dart:async';

import '../asset/asset_node.dart';
import '../log.dart';
import '../transformer/transformer_group.dart';
import '../utils/stream_pool.dart';
import 'asset_cascade.dart';
import 'node_status.dart';
import 'phase.dart';

/// A class that processes all of the phases in a single transformer group.
///
/// A group takes many inputs, processes them, and emits many outputs.
class GroupRunner {
  /// The group this runner runs.
  final TransformerGroup _group;

  /// A string describing the location of [this] in the transformer graph.
  final String _location;

  /// The phases defined by this group.
  final _phases = new List<Phase>();

  /// How far along [this] is in processing its assets.
  NodeStatus get status {
    // Just check the last phase, since it will check all the previous phases
    // itself.
    return _phases.last.status;
  }

  /// A stream that emits an event every time the group's status changes.
  Stream<NodeStatus> get onStatusChange => _onStatusChange;
  Stream _onStatusChange;

  /// A stream that emits any new assets emitted by [this].
  ///
  /// Assets are emitted synchronously to ensure that any changes are thoroughly
  /// propagated as soon as they occur.
  Stream<AssetNode> get onAsset => _onAsset;
  Stream<AssetNode> _onAsset;

  /// A stream that emits an event whenever any transforms in this group logs
  /// an entry.
  Stream<LogEntry> get onLog => _onLogPool.stream;
  final _onLogPool = new StreamPool<LogEntry>.broadcast();

  GroupRunner(Phase previous, this._group, this._location) {
    _addPhase(previous.addPhase(_location), []);
    for (var phase in _group.phases) {
      _addPhase(_phases.last.addPhase(), phase);
    }

    _onAsset = _phases.last.onAsset;
    _onStatusChange = _phases.last.onStatusChange;
  }

  /// Add a phase with [contents] to [this]'s list of phases.
  ///
  /// [contents] should be an inner [Iterable] from a [TransformGroup.phases]
  /// value.
  void _addPhase(Phase phase, Iterable contents) {
    _phases.add(phase);
    _onLogPool.add(phase.onLog);
    phase.updateTransformers(contents);
  }

  /// Force all [LazyTransformer]s' transforms in this group to begin producing
  /// concrete assets.
  void forceAllTransforms() {
    for (var phase in _phases) {
      phase.forceAllTransforms();
    }
  }

  /// Removes this group and all sub-phases within it.
  void remove() {
    _onLogPool.close();
    for (var phase in _phases) {
      phase.remove();
    }
  }

  String toString() => "group in phase $_location for $_group";
}
