/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import 'package:illinois/service/Auth2.dart';
import 'package:illinois/service/FlexUI.dart';
import 'package:illinois/service/Storage.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/utils/utils.dart';

class AcademicsHomePanel extends StatefulWidget {
  final AcademicsContent? content;

  AcademicsHomePanel({this.content});

  @override
  _AcademicsHomePanelState createState() => _AcademicsHomePanelState();
}

class _AcademicsHomePanelState extends State<AcademicsHomePanel> with AutomaticKeepAliveClientMixin<AcademicsHomePanel> implements NotificationsListener {
  late AcademicsContent _selectedContent;
  List<AcademicsContent>? _contentValues;
  bool _contentValuesVisible = false;

  @override
  void initState() {
    NotificationService().subscribe(this, [FlexUI.notifyChanged, Auth2.notifyLoginChanged]);
    _buildContentValues();
    AcademicsContent? lastSelectedContent = _contentFromString(Storage().academicsUserDropDownSelectionValue);
    _selectedContent = widget.content ?? (lastSelectedContent ?? AcademicsContent.events);
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  // AutomaticKeepAliveClientMixin

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
        appBar: RootHeaderBar(title: Localization().getStringEx('panel.academics.header.title', 'Academics')),
        body: Column(children: <Widget>[
          Expanded(
              child: SingleChildScrollView(
                  physics: (_contentValuesVisible ? NeverScrollableScrollPhysics() : null),
                  child: Container(
                      color: Styles().colors!.background,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                            padding: EdgeInsets.only(left: 16, top: 16, right: 16),
                            child: RibbonButton(
                                textColor: Styles().colors!.fillColorSecondary,
                                backgroundColor: Styles().colors!.white,
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                                border: Border.all(color: Styles().colors!.surfaceAccent!, width: 1),
                                rightIconAsset: (_contentValuesVisible ? 'images/icon-up.png' : 'images/icon-down-orange.png'),
                                label: _getContentLabel(_selectedContent),
                                onTap: _changeSettingsContentValuesVisibility)),
                        _buildContent()
                      ]))))
        ]),
        backgroundColor: Styles().colors!.background);
  }

  Widget _buildContent() {
    return Stack(children: [Padding(padding: EdgeInsets.all(16), child: _contentWidget), _buildContentValuesContainer()]);
  }

  Widget _buildContentValuesContainer() {
    return Visibility(
        visible: _contentValuesVisible,
        child: Positioned.fill(child: Stack(children: <Widget>[_buildContentDismissLayer(), _buildContentValuesWidget()])));
  }

  Widget _buildContentDismissLayer() {
    return Positioned.fill(
        child: BlockSemantics(
            child: GestureDetector(
                onTap: () {
                  setState(() {
                    _contentValuesVisible = false;
                  });
                },
                child: Container(color: Styles().colors!.blackTransparent06))));
  }

  Widget _buildContentValuesWidget() {
    List<Widget> sectionList = <Widget>[];
    sectionList.add(Container(color: Styles().colors!.fillColorSecondary, height: 2));
    for (AcademicsContent section in AcademicsContent.values) {
      if ((_selectedContent != section)) {
        sectionList.add(_buildContentItem(section));
      }
    }
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SingleChildScrollView(child: Column(children: sectionList)));
  }

  Widget _buildContentItem(AcademicsContent contentItem) {
    return RibbonButton(
        backgroundColor: Styles().colors!.white,
        border: Border.all(color: Styles().colors!.surfaceAccent!, width: 1),
        rightIconAsset: null,
        label: _getContentLabel(contentItem),
        onTap: () => _onTapContentItem(contentItem));
  }

  void _buildContentValues() {
    List<String>? contentCodes = JsonUtils.listStringsValue(FlexUI()['academics']);
    List<AcademicsContent>? contentValues;
    if (contentCodes != null) {
      contentValues = [];
      for (String code in contentCodes) {
        AcademicsContent? value = _getContentValueFromCode(code);
        if (value != null) {
          contentValues.add(value);
        }
      }
    }

    _contentValues = contentValues;
    if (mounted) {
      setState(() {});
    }
  }

  AcademicsContent? _getContentValueFromCode(String? code) {
    if (code == 'gies_checklist') {
      return AcademicsContent.gies_checklist;
    } else if (code == 'new_student_checklist') {
      return AcademicsContent.uiuc_checklist;
    } else if (code == 'canvas_courses') {
      return AcademicsContent.courses;
    } else if (code == 'academics_events') {
      return AcademicsContent.events;
    } else if (code == 'my_illini') {
      return AcademicsContent.my_illini;
    } else {
      return null;
    }
  }

  void _onTapContentItem(AcademicsContent contentItem) {
    //TBD: DD - properly implement My Illini - open in browser
    _selectedContent = contentItem;
    Storage().academicsUserDropDownSelectionValue = _selectedContent.toString();
    _changeSettingsContentValuesVisibility();
  }

  void _changeSettingsContentValuesVisibility() {
    _contentValuesVisible = !_contentValuesVisible;
    if (mounted) {
      setState(() {});
    }
  }

  Widget get _contentWidget {
    // There is no content for AcademicsContent.my_illini - it is a web url opened in an external browser
    switch (_selectedContent) {
      case AcademicsContent.events:
        //TBD: DD - implement
        return Container();
      case AcademicsContent.gies_checklist:
        //TBD: DD - implement
        return Container();
      case AcademicsContent.uiuc_checklist:
        //TBD: DD - implement
        return Container();
      case AcademicsContent.courses:
        //TBD: DD - implement
        return Container();
      default:
        return Container();
    }
  }

  // Utilities

  static AcademicsContent? _contentFromString(String? value) {
    if (value == null) {
      return null;
    }
    return AcademicsContent.values.firstWhere((element) => (element.toString() == value));
  }

  String _getContentLabel(AcademicsContent section) {
    switch (section) {
      case AcademicsContent.events:
        return Localization().getStringEx('panel.academics.section.events.label', 'Academic Events');
      case AcademicsContent.gies_checklist:
        return Localization().getStringEx('panel.academics.section.gies_checklist.label', 'iDegrees New Student Checklist');
      case AcademicsContent.uiuc_checklist:
        return Localization().getStringEx('panel.academics.section.uiuc_checklist.label', 'New Student Checklist');
      case AcademicsContent.courses:
        return Localization().getStringEx('panel.academics.section.courses.label', 'Courses');
      case AcademicsContent.my_illini:
        return Localization().getStringEx('panel.academics.section.my_illini.label', 'My Illini');
    }
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == FlexUI.notifyChanged) {
      _buildContentValues();
    } else if (name == Auth2.notifyLoginChanged) {
      _buildContentValues();
    }
  }
}

enum AcademicsContent { events, gies_checklist, uiuc_checklist, courses, my_illini }
