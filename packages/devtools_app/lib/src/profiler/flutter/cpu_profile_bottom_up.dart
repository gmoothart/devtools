// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/table.dart';
import '../../profiler/cpu_profile_columns.dart';
import '../../profiler/cpu_profile_model.dart';
import '../../table_data.dart';

/// A table of the CPU's bottom-up call tree.
class CpuBottomUpTable extends StatelessWidget {
  factory CpuBottomUpTable(List<CpuStackFrame> bottomUpRoots, {Key key}) {
    final treeColumn = MethodNameColumn();
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      TotalTimeColumn(),
      SelfTimeColumn(),
      treeColumn,
      SourceColumn(),
    ]);
    return CpuBottomUpTable._(key, bottomUpRoots, treeColumn, columns);
  }

  const CpuBottomUpTable._(
      Key key, this.bottomUpRoots, this.treeColumn, this.columns)
      : super(key: key);

  final TreeColumnData<CpuStackFrame> treeColumn;
  final List<ColumnData<CpuStackFrame>> columns;
  final List<CpuStackFrame> bottomUpRoots;
  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      dataRoots: bottomUpRoots,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (frame) => PageStorageKey<String>(frame.id),
    );
  }
}
