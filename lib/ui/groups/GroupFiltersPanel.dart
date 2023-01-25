import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/ContentFilter.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/ui/groups/GroupWidgets.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/AppUtils.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/ui/widgets/rounded_button.dart';


class GroupFiltersPanel extends StatefulWidget {
  final bool createMode;
  final ContentFilterSet contentFilters;
  final Map<String, LinkedHashSet<String>>? selection;

  GroupFiltersPanel({Key? key, required this.contentFilters, this.selection, this.createMode = false }) : super(key: key);

  bool get editMode => !createMode;

  @override
  State<StatefulWidget> createState() => _GroupFiltersPanelState();
}

class _GroupFiltersPanelState extends State<GroupFiltersPanel> {

  final Map<String, GlobalKey> filterKeys = <String, GlobalKey>{};
  Map<String, LinkedHashSet<String>> _selection = <String, LinkedHashSet<String>>{};

  @override
  void initState() {
    if (widget.selection != null) {
      _selection = widget.selection!;
    }
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderBar(title: Localization().getStringEx('panel.group.filters.header.title', 'Group Filters'),),
      backgroundColor: Styles().colors?.background,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    List<ContentFilter>? filters = widget.contentFilters.filters;
    return ((filters != null) && filters.isNotEmpty) ? Column(children: <Widget>[
      Expanded(child:
        Stack(children: [
          Container(padding: EdgeInsets.only(left: 16, right: 24, top: 8), child:
            SingleChildScrollView(child:
              _buildFiltersContent(),
            ),
          ),
          Align(alignment: Alignment.topRight,
            child: GestureDetector(onTap: _onTapClear,
              child:Semantics(label: Localization().getStringEx('panel.group.filters.button.clear.title', 'Clear'), button: true, excludeSemantics: true,
                child: Container(width: 36, height: 36,
                  child: Align(alignment: Alignment.center,
                    child: Text('X', style: TextStyle(fontFamily: Styles().fontFamilies!.regular, fontSize: 16, color: Styles().colors!.fillColorPrimary,),),
                  ),
                ),
              ),
            ),
          ),
        ],)
      ),
      // Container(height: 1, color: Styles().colors?.surfaceAccent),
      _buildCommands(),
    ]) : Container();
  }

  Widget _buildFiltersContent() {
    List<ContentFilter>? filters = widget.contentFilters.filters;
    List<Widget> conentList = <Widget>[];
    if ((filters != null) && filters.isNotEmpty) {
      for (ContentFilter filter in filters) {
        conentList.add(_buildFilterDropDown(filter));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: conentList,); 
  }

  Widget _buildFilterDropDown(ContentFilter filter) {
    LinkedHashSet<String>? selectedIds = _selection[filter.id];
    ContentFilterEntry? selectedEntry = ((selectedIds != null) && selectedIds.isNotEmpty) ?
      ((1 < selectedIds.length) ? _ContentFilterMultipleEntries(selectedIds) : filter.findEntry(id: selectedIds.first)) : null;
    List<ContentFilterEntry>? entries = filter.entriesFromSelection(_selection);
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      GroupSectionTitle(
        title: widget.contentFilters.stringValue(filter.title)?.toUpperCase(),
        description: widget.contentFilters.stringValue(filter.description),
        requiredMark: widget.createMode && (0 < (filter.minSelectCount ?? 0)),
      ),
      GroupDropDownButton<ContentFilterEntry>(
        key: filterKeys[filter.id ?? ''] ??= GlobalKey(),
        emptySelectionText: widget.contentFilters.stringValue(filter.emptyLabel),
        buttonHint: widget.contentFilters.stringValue(filter.hint),
        items: entries,
        initialSelectedValue: selectedEntry,
        multipleSelection: (widget.createMode && filter.isMultipleSelection) || widget.editMode,
        enabled: entries?.isNotEmpty ?? true,
        constructTitle: (ContentFilterEntry value) => _constructFilterEntryTitle(filter, value),
        isItemSelected: (ContentFilterEntry value) => _isFilterEntrySelected(filter, value),
        onItemSelected: (ContentFilterEntry value) => _onContentFilterEntrySelected(filter, value),
        onValueChanged: (ContentFilterEntry value) => _onContentFilterEntry(filter, value),
      )
    ]);
  }

  String? _constructFilterEntryTitle(ContentFilter filter, ContentFilterEntry entry) {
    if (entry is _ContentFilterMultipleEntries) {
      String title = '';
      for (String subEntryId in entry.entryIds) {
        ContentFilterEntry? subEntry = filter.findEntry(id: subEntryId);
        String? subEntryName = widget.contentFilters.stringValue(subEntry?.label);
        if ((subEntryName != null) && subEntryName.isNotEmpty) {
          if (title.isNotEmpty) {
            title += ', ';
          }
          title += subEntryName;
        }
      }
      return title;
    }
    else {
      return widget.contentFilters.stringValue(entry.label);
    }
  }

  bool _isFilterEntrySelected(ContentFilter filter, ContentFilterEntry entry) {
    LinkedHashSet<String>? selectedIds = _selection[filter.id];
    return selectedIds?.contains(entry.id) ?? false;
  }

  void _onContentFilterEntrySelected(ContentFilter filter, ContentFilterEntry value) {
  }

  void _onContentFilterEntry(ContentFilter filter, ContentFilterEntry value) {
    String? filterId = filter.id;
    String? valueId = value.id;
    if ((filterId != null) && (valueId != null)) {
      LinkedHashSet<String> selectedIds = (_selection[filterId] ??= LinkedHashSet<String>());
      setStateIfMounted(() {
        
        if (selectedIds.contains(valueId)) {
          selectedIds.remove(valueId);
        }
        else {
          selectedIds.add(valueId);
        }
        
        if (widget.createMode && (filter.maxSelectCount != null)) {
          while (filter.maxSelectCount! < selectedIds.length) {
            selectedIds.remove(selectedIds.first);
          }
        }

        widget.contentFilters.validateSelection(_selection);
      });
    }

    if ((widget.createMode && filter.isMultipleSelection) || widget.editMode) {
      // Ugly workaround: show again dropdown popup if filter supports multiple select.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        final RenderObject? renderBox = filterKeys[filter.id]?.currentContext?.findRenderObject();
        if (renderBox is RenderBox) {
          Offset globalOffset = renderBox.localToGlobal(Offset(renderBox.size.width / 2, renderBox.size.height / 2));
          GestureBinding.instance.handlePointerEvent(PointerDownEvent(position: globalOffset,));
          //Future.delayed(Duration(milliseconds: 100)).then((_) =>);
          GestureBinding.instance.handlePointerEvent(PointerUpEvent(position: globalOffset,));
        }
      });
    }
  }

  Widget _buildCommands() {
    bool canApply = (widget.createMode && (widget.contentFilters.unsatisfiedFilterFromSelection(_selection) == null)) || widget.editMode;
    return SafeArea(child:
      Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16), child:
        Row(children: <Widget>[
          Expanded(child:
            RoundedButton(
              label: Localization().getStringEx('panel.group.filters.button.apply.title', 'Apply'),
              textColor: canApply ? Styles().colors?.fillColorPrimary : Styles().colors?.surfaceAccent,
              borderColor: canApply ? Styles().colors?.fillColorSecondary : Styles().colors?.surfaceAccent ,
              backgroundColor: Styles().colors?.white,
              enabled: canApply,
              onTap: _onTapApply
            )
          )
        ],)
      )
    );
  }

  void _onTapApply() {
    Analytics().logSelect(target: 'Apply');
    Navigator.of(context).pop(_selection);
  }

  void _onTapClear() {
    Analytics().logSelect(target: 'Clear');
    setStateIfMounted(() {
      _selection = <String, LinkedHashSet<String>>{};
    });
  }
}

class _ContentFilterMultipleEntries extends ContentFilterEntry {
  final LinkedHashSet<String> entryIds;
  _ContentFilterMultipleEntries(this.entryIds);
}
