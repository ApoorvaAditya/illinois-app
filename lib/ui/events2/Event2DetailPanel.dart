import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:geolocator/geolocator.dart';
import 'package:illinois/ext/Event2.dart';
import 'package:illinois/ext/Explore.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth2.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/AppUtils.dart';
import 'package:intl/intl.dart';
import 'package:rokwire_plugin/model/auth2.dart';
import 'package:rokwire_plugin/model/content_attributes.dart';
import 'package:rokwire_plugin/model/event2.dart';
import 'package:rokwire_plugin/service/app_datetime.dart';
import 'package:rokwire_plugin/service/events2.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/ui/widgets/rounded_button.dart';
import 'package:rokwire_plugin/utils/utils.dart';
import 'package:timezone/timezone.dart';
import 'package:url_launcher/url_launcher.dart';

class Event2DetailPanel extends StatefulWidget implements AnalyticsPageAttributes {
  final Event2? event;
  final Position? userLocation;
  Event2DetailPanel({ this.event, this.userLocation });
  
  @override
  State<StatefulWidget> createState() => _Event2DetailPanelState();

  // AnalyticsPageAttributes

  @override
  Map<String, dynamic>? get analyticsPageAttributes => event?.analyticsAttributes;
}

class _Event2DetailPanelState extends State<Event2DetailPanel> implements NotificationsListener {
  Event2? _event;
  
  @override
  void initState() {
    NotificationService().subscribe(this, [
      Auth2UserPrefs.notifyFavoritesChanged,
    ]);
    _event = widget.event;
    
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }


  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Auth2UserPrefs.notifyFavoritesChanged) {
      setStateIfMounted(() { });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(body:
      Column(children: <Widget>[
        Expanded(child:
          CustomScrollView(slivers: <Widget>[
            SliverToutHeaderBar(
              flexImageUrl:  _event?.imageUrl,
              flexImageKey: 'event-detail-default',
              flexRightToLeftTriangleColor: Colors.white,
            ),
            SliverList(delegate:
              SliverChildListDelegate([
                Container(color: Styles().colors?.white, child:
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _categoriesWidget,
                    Padding(padding: EdgeInsets.only(left: 16, right: 16, bottom: 16), child:
                      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _titleWidget,
                        _sponsorWidget,
                        _detailsWidget,
                      ])
                    ),
                  ]),
                ),
                Padding(padding: EdgeInsets.only(left: 16, right: 16), child:
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _descriptionWidget,
                  _buttonsWidget,
               ]))
              ], addSemanticIndexes:false)
            ),
          ])
        ),
      ])
    );
  }

  Widget get _categoriesWidget => 
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child:
        Padding(padding: EdgeInsets.only(left: 16, top: 16, bottom: 8), child:
          Text(_displayCategories?.join(', ') ?? '', overflow: TextOverflow.ellipsis, maxLines: 2, style: Styles().textStyles?.getTextStyle("widget.card.title.small.fat"))
        ),
      ),
      _favoriteButton
    ]);

  List<String>? get _displayCategories =>
    Events2().contentAttributes?.displaySelectedLabelsFromSelection(_event?.attributes, usage: ContentAttributeUsage.category);

  Widget get _favoriteButton {
    bool isFavorite = Auth2().isFavorite(_event);
    return Opacity(opacity: Auth2().canFavorite ? 1 : 0, child:
      Semantics(container: true,
        child: Semantics(
          label: isFavorite ?
            Localization().getStringEx('widget.card.button.favorite.off.title', 'Remove From Favorites') :
            Localization().getStringEx('widget.card.button.favorite.on.title', 'Add To Favorites'),
          hint: isFavorite ?
            Localization().getStringEx('widget.card.button.favorite.off.hint', '') :
            Localization().getStringEx('widget.card.button.favorite.on.hint', ''),
          button: true,
          child: InkWell(onTap: _onFavorite,
            child: Padding(padding: EdgeInsets.all(16),
              child: Styles().images?.getImage(isFavorite ? 'star-filled' : 'star-outline-gray', excludeFromSemantics: true,)
            )
          ),
        ),
      )
    );
  }

  Widget get _titleWidget => Row(children: [
    Expanded(child: 
      Text(_event?.name ?? '', style: Styles().textStyles?.getTextStyle('widget.title.extra_large'), maxLines: 2,)
    ),
  ],);

  Widget get _sponsorWidget => StringUtils.isNotEmpty(_event?.sponsor) ? Padding(padding: EdgeInsets.only(top: 8), child:
    Row(children: [
      Expanded(child: 
        Text(_event?.sponsor ?? '', style: Styles().textStyles?.getTextStyle('widget.item.regular.fat'), maxLines: 2,)
      ),
    ],),
   ) : Container();

  Widget get _descriptionWidget => StringUtils.isNotEmpty(_event?.description) ? Padding(padding: EdgeInsets.only(top: 24, left: 10, right: 10), child:
       HtmlWidget(
          StringUtils.ensureNotEmpty(_event?.description),
          onTapUrl : (url) {_onLaunchUrl(url, context: context); return true;},
          textStyle: Styles().textStyles?.getTextStyle("widget.info.regular")
      )
  ) : Container();

  Widget get _detailsWidget {
    List<Widget> detailWidgets = <Widget>[
      ...?_dateDetailWidget,
      ...?_onlineDetailWidget,
      ...?_locationDetailWidget,
      ...?_priceDetailWidget,
      ...?_privacyDetailWidget,
      ...?_contactsDetailWidget,
    ];

    return detailWidgets.isNotEmpty ? Padding(padding: EdgeInsets.only(top: 16), child:
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: detailWidgets,)
    ) : Container();
  }

  List<Widget>? get _dateDetailWidget {
    TZDateTime? dateTimeUni = _event?.startTimeUtc?.toUniOrLocal();
    return (dateTimeUni != null) ? <Widget>[_buildTextDetailWidget(DateFormat('MMM d, ha').format(dateTimeUni), 'calendar')] : null;
  }

  List<Widget>? get _onlineDetailWidget {
    if (_event?.online == true) {
      bool canLaunch = StringUtils.isNotEmpty(_event?.onlineDetails?.url);
      List<Widget> details = <Widget>[
        InkWell(onTap: canLaunch ? _onOnline : null, child:
          _buildTextDetailWidget('Online', 'laptop'),
        ),
      ];

      Widget onlineWidget = canLaunch ?
        Text(_event?.onlineDetails?.url ?? '', style: Styles().textStyles?.getTextStyle('widget.button.title.small.semi_bold.underline'),) :
        Text(_event?.onlineDetails?.url ?? '', style: Styles().textStyles?.getTextStyle('widget.explore.card.detail.regular'),);
      details.add(
        InkWell(onTap: canLaunch ? _onOnline : null, child:
          _buildDetailWidget(onlineWidget, 'laptop', iconVisible: false, contentPadding: EdgeInsets.zero)
        )
      );

      return details;
    }
    return null;
  }

  List<Widget>? get _locationDetailWidget {
    if (_event?.inPerson == true) {

      bool canLocation = _event?.location?.isLocationCoordinateValid ?? false;
      
      List<Widget> details = <Widget>[
        InkWell(onTap: canLocation ? _onLocation : null, child:
          _buildTextDetailWidget('In Person', 'location'),
        ),
      ];

      String? locationText = (
        _event?.location?.displayName ??
        _event?.location?.displayAddress ??
        _event?.location?.displayCoordinates
      );
      if (locationText != null) {
        Widget locationWidget = canLocation ?
          Text(locationText, maxLines: 1, style: Styles().textStyles?.getTextStyle('widget.button.title.small.semi_bold.underline'),) :
          Text(locationText, maxLines: 1, style: Styles().textStyles?.getTextStyle('widget.explore.card.detail.regular'),);
        details.add(
          InkWell(onTap: canLocation ? _onLocation : null, child:
            _buildDetailWidget(locationWidget, 'location', iconVisible: false, contentPadding: EdgeInsets.zero)
          )
        );
      }
      return details;
    }
    return null;
  }

  List<Widget>? get _priceDetailWidget{
    return null; //TBD
  }

  List<Widget>? get _privacyDetailWidget{
    return null; //TBD
  }

  List<Widget>? get _contactsDetailWidget{
    return null; //TBD
  }

  Widget get _buttonsWidget {
    List<Widget> buttons = <Widget>[
      ...?_urlButtonWidget,
      ...?_registrationButtonWidget
    ];

    return buttons.isNotEmpty ? Padding(padding: EdgeInsets.only(top: 16), child:
    Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: buttons,)
    ) : Container();
  }

  List<Widget>? get _urlButtonWidget => //TBD check if this is the proper url for this button
    StringUtils.isNotEmpty(_event?.eventUrl) ? <Widget>[_buildUrlButtonWidget(
      title: Localization().getStringEx('panel.groups_event_detail.button.visit_website.title', 'Visit website'),
      hint: Localization().getStringEx('panel.groups_event_detail.button.visit_website.hint', ''),
      onTap: (){_onWebButton(_event?.eventUrl, analyticsName: 'Website');}
    )] : null;

  List<Widget>? get _registrationButtonWidget{
    return null; //TBD
  }

  Widget _buildTextDetailWidget(String text, String iconKey, {
    EdgeInsetsGeometry contentPadding = const EdgeInsets.only(top: 4),
    EdgeInsetsGeometry iconPadding = const EdgeInsets.only(right: 6),
    bool iconVisible = true
  }) =>
    _buildDetailWidget(
      Text(text, maxLines: 1, style: Styles().textStyles?.getTextStyle('widget.explore.card.detail.regular'),),
      iconKey,
      contentPadding: contentPadding,
      iconPadding: iconPadding,
      iconVisible: iconVisible
    );

  Widget _buildDetailWidget(Widget contentWidget, String iconKey, {
    EdgeInsetsGeometry contentPadding = const EdgeInsets.only(top: 4),
    EdgeInsetsGeometry iconPadding = const EdgeInsets.only(right: 6),
    bool iconVisible = true
  }) {
    List<Widget> contentList = <Widget>[];
    Widget? iconWidget = Styles().images?.getImage(iconKey, excludeFromSemantics: true);
    if (iconWidget != null) {
      contentList.add(Padding(padding: iconPadding, child:
        Opacity(opacity: iconVisible ? 1 : 0, child:
          iconWidget,
        )
      ));
    }
    contentList.add(Expanded(child:
      contentWidget
    ),);
    return Padding(padding: contentPadding, child:
      Row(children: contentList)
    );
  }

  //TBD remove if not needed
  Widget _buildUrlButtonWidget({String? title, String? hint, bool enabled = true, void Function()? onTap}) => StringUtils.isNotEmpty(title) ?
    Padding(padding: EdgeInsets.only(bottom: 6), child:
      Row(children:<Widget>[
        Expanded(child:
          RoundedButton(
              label: StringUtils.ensureNotEmpty(title),
              hint: hint,
              textStyle: Styles().textStyles?.getTextStyle("widget.button.title.large.fat"),
              backgroundColor: enabled ? Colors.white : Styles().colors!.background,
              borderColor: enabled ? Styles().colors!.fillColorSecondary : Styles().colors!.fillColorPrimary,  //TBD proper disabled colors
              rightIcon: Styles().images?.getImage(enabled ? 'external-link-dark' : 'external-link'),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              onTap: onTap
          ),
        ),],)
      ) : Container();

  void _onLocation() {
    Analytics().logSelect(target: "Location Directions: ${_event?.name}");
    _event?.launchDirections();
  }

  void _onOnline() {
    Analytics().logSelect(target: "Online Url: ${_event?.name}");
  }

  void _onFavorite() {
    Analytics().logSelect(target: "Favorite: ${_event?.name}");
    Auth2().prefs?.toggleFavorite(_event);
  }

  void _onLaunchUrl(String? url, {BuildContext? context}) {
    if (StringUtils.isNotEmpty(url)) {
      if (UrlUtils.launchInternal(url)) {
        Navigator.push(context!, CupertinoPageRoute(builder: (context) => WebPanel(url: url)));
      } else {
        Uri? uri = Uri.tryParse(url!);
        if (uri != null) {
          launchUrl(uri);
        }
      }
    }
  }

  void _onWebButton(String? url, { String? analyticsName }) {
    if (analyticsName != null) {
      Analytics().logSelect(target: analyticsName);
    }
    if(StringUtils.isNotEmpty(url)){
      Navigator.push(context, CupertinoPageRoute(builder: (context) => WebPanel(url: url, analyticsName: "WebPanel($analyticsName)",)));
    }
  }
}
