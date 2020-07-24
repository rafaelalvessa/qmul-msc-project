import 'dart:async';
import 'dart:html';
import 'main.dart';
import 'package:core_elements/core_menu.dart';
import 'package:core_elements/core_overlay.dart';
import 'package:polymer/polymer.dart';

/// Defines a Polymer element [:story-element:].
@CustomTag('story-element')
class StoryElement extends PolymerElement {
  String id;
  String type;
  @observable String title;
  @observable String publisher;
  @observable String date;
  @observable String text;
  @observable String image;
  @observable String url;
  List<String> photos;
  int selectedPhoto;
  @observable String photo;
  String topic;
  String reaction;
  @observable String positiveIcon;
  @observable String negativeIcon;

  /// Calls the superclass constructor.
  StoryElement.created() : super.created();

  /// Factory to create new story elements.
  factory StoryElement() => new Element.tag('story-element');

  /// Calls the superclass's [attached] method.
  void attached() {
    super.attached();
  }

  /// Creates a story element from the object [story].
  Future update(dynamic story) async {
    id = story['id'];
    type = story['type'];
    date = story['date'].substring(0, 16);
    url = story['url'];
    selectedPhoto = 0;

    var response = await _getReaction();
    reaction = response == 'null' ? null : response;
    _updateReactionIcons();

    switch (type) {
      case 'googlenews':
        title = story['title'];
        publisher = story['publisher'];
        injectBoundHtml(story['text'], element: $['text']);
        image = story['imageUrl'];
        topic = story['topic'];
        break;

      case 'twitter':
        var user = story['user'];
        publisher = _getTwitterUser(user);
        injectBoundHtml(_parseText(story), element: $['text']);
        image = _getTwitterUserImage(user);
        photos = story['photos'];
        if (photos != null && photos.length > 0) {
          photo = photos[selectedPhoto];
          if (photos.length > 1) {
            shadowRoot.querySelector('#photo').setAttribute('class',
                'multiPhotos');
            shadowRoot.querySelector('#photo-label').setAttribute('label',
                'Click to see more photos');
          }
        }
        break;

      default:
        throw 'Invalid story type.';
    }
  }

  /// Returns the Twitter user in the object [user] in the format
  /// 'Name (@screenName)'.
  String _getTwitterUser(dynamic user) =>
      '${user['name']} (@${user['screenName']})';

  /// Parses the text in the [story] object.
  String _parseText(dynamic story) {
    var mediaUrl = story['mediaUrl'];
    var urls = story['urls'];
    var text = story['text']
        .replaceAll(' $mediaUrl', '')
        .replaceAll('$mediaUrl', '');
    if (urls != null) {
      for (var urlMap in urls) {
        text = text.replaceAll(urlMap['url'], _parseUrl(urlMap['displayUrl']));
      }
    }
    return text;
  }

  /// Parses the URL [url] to enclose it in an internal URL which can be used to
  /// redirect to the external website.
  String _parseUrl(String url) =>
      '<a href="redirect.html?url=' +
      ((url.indexOf('http://') < 0 && url.indexOf('https://') < 0)
          ? 'http://$url'
          : url) +
      '" target="_blank">$url</a>';

  /// Returns the URL of the Twitter user image from the [user] object.
  String _getTwitterUserImage(dynamic user) => '${user['profileImage']}';

  /// Selects the next photo.
  void nextPhoto(Event e, var detail, Node target) {
    photo = photos[(++selectedPhoto % photos.length).abs()];
  }

  /// Adds or removes the story from the positive reactions.
  Future positiveReaction(Event event, var details, Node target) async =>
      await _updateReaction(id, type, 'positive');

  /// Adds or removes the story from the negative reactions.
  Future negativeReaction(Event event, var details, Node target) async =>
      await _updateReaction(id, type, 'negative');

  /// Returns the story's current reaction.
  Future<String> _getReaction() async =>
      await HttpRequest.getString('http://localhost:8081' +
          '?get-reaction&id=$id&type=$type');

  /// Updates the story with ID [id] and type [type] to the reaction [reaction].
  Future _updateReaction(String id, String type, String reaction) async {
    try {
      var url = 'http://localhost:8081?reaction=$reaction&id=$id&type=$type';
      var results = await HttpRequest.getString(url);
      _updateReactionIcons(reaction);
      if (results != null && results != '') {
        showNotification(results);
      }
      CoreMenu menu = querySelector('#topics');
      var selectedItem = menu.selectedItem.id;
      if (selectedItem == 'positive-reactions' ||
          selectedItem == 'negative-reactions') {
        new Timer.periodic(const Duration(milliseconds: 500),
            (timer) => refresh(timer));
      }
    } catch (e) {
      print('Server error: $e');
    }
  }

  /// Updates the reaction icons, where [selected] is the new reaction selected.
  void _updateReactionIcons([String selected]) {
    var positiveButton = shadowRoot.querySelector('#positive-button');
    var negativeButton = shadowRoot.querySelector('#negative-button');

    if (selected == null) {
      positiveIcon = 'add-circle-outline';
      _removeClass(positiveButton);
      negativeIcon = 'remove-circle-outline';
      _removeClass(negativeButton);
      if (reaction == 'positive') {
        positiveIcon = 'add-circle';
        _fillColour(positiveButton, 'positive');
      }
      if (reaction == 'negative') {
        negativeIcon = 'remove-circle';
        _fillColour(negativeButton, 'negative');
      }
    } else if (selected == 'positive') {
      if (reaction == 'positive') {
        positiveIcon = 'add-circle-outline';
        _removeClass(positiveButton);
        reaction = null;
      } else {
        positiveIcon = 'add-circle';
        _fillColour(positiveButton, 'positive');
        if (reaction == 'negative') {
          negativeIcon = 'remove-circle-outline';
          _removeClass(negativeButton);
        }
        reaction = 'positive';
      }
    } else if (selected == 'negative') {
      if (reaction == 'negative') {
        negativeIcon = 'remove-circle-outline';
        _removeClass(negativeButton);
        reaction = null;
      } else {
        if (reaction == 'positive') {
          positiveIcon = 'add-circle-outline';
          _removeClass(positiveButton);
        }
        negativeIcon = 'remove-circle';
        _fillColour(negativeButton, 'negative');
        reaction = 'negative';
      }
    }
  }

  /// Fills the reaction button when it is selected.
  void _fillColour(Element element, String reaction) {
    element.setAttribute('class', '$reaction-button-selected');
  }

  /// Deselects a reaction button.
  void _removeClass(Element element) {
    element.attributes.remove('class');
  }

  /// Dialog to add a new topic to the blacklist.
  void blacklist(Event event, var details, Node target) {
    // Fills the blacklist input whenever a topic is detected.
    var blacklistInput = querySelector('#add-blacklist-input');
    if (topic != null) {
      blacklistInput.value = topic;
    } else {
      blacklistInput.value = '';
    }

    CoreOverlay overlay = querySelector('#add-blacklist-overlay');
    overlay
      ..backdrop = true
      ..opened = true
      ..open();

    // Adds the topic to the blacklist when the key enter is pressed.
    blacklistInput.onKeyUp.listen((event) {
      if (event.keyCode == 13 && !blacklistInput.value.isEmpty) {
        overlay
          ..opened = false
          ..close();
        _updateBlacklist(blacklistInput.value);
      }
    });

    // Adds the topic to the blacklist when the dialog button is pressed.
    querySelector('#add-blacklist-button').onClick.listen((event) =>
      _updateBlacklist(blacklistInput.value));
  }

  /// Adds the topic [topic] to the blacklist in the database.
  void _updateBlacklist(String topic) {
    runZoned(() {
      new HttpRequest()
        ..timeout = timeout
        ..open('GET', 'http://localhost:8081?blacklist-add=$topic')
        ..onLoad.listen((event) {
          var message = event.target.responseText;
          if (message != null && message != '') {
            showNotification(event.target.responseText);
          }
          refresh();
        })
        ..onError.listen((event) =>
            showNotification('Cannot reach the server.'))
        ..onTimeout.listen((event) => showNotification('Connection timeout.'))
        ..send();
    }, onError: (e) => print('Server error: $e'));
  }
}
