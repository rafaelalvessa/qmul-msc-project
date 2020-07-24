export 'package:polymer/init.dart';
import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';
import 'package:core_elements/core_menu.dart';
import 'package:core_elements/core_overlay.dart';
import 'package:paper_elements/paper_checkbox.dart';
import 'package:paper_elements/paper_toast.dart';
import 'package:polymer/polymer.dart';
import 'story_element.dart';

/// Default request timeout of 30 seconds.
final timeout = 30000;

String location;

/// Execution begins once Polymer is ready.
@whenPolymerReady
Future onReady() async {
  _loadSearch();
  _loadRefresh();
  _loadTopics();
  await _loadBlacklist();
  _showTopic('all');
}

/// Initiates search.
void _loadSearch() {
  var searchInput = querySelector('#search-input');
  searchInput.onKeyUp.listen((KeyboardEvent event) {
    if (event.keyCode == 27) searchInput.value = '';
    if (event.keyCode == 13) {
      _showTopic(searchInput.value);
    }
  });
}

/// Initiates the refresh button.
void _loadRefresh() {
  querySelector('#refresh-button').onClick.listen((event) => refresh());
}

/// Refreshes the current page with the most updated stories.
///
/// If a timer [timer] is specified, it gets cancelled.
Future refresh([Timer timer]) async {
  CoreMenu menu = querySelector('#topics');
  var selectedTopic = menu.selectedItem.id;
  if (selectedTopic == 'location') {
    await _showLocalStories();
  } else {
    await _showTopic(selectedTopic);
  }
  timer.cancel();
}

/// Initiates the topics.
void _loadTopics() {
  var topic;
  querySelectorAll('.topic').forEach((Element item) {
    item.onClick.listen((event) {
      topic = item.id;
      _changeTitle(item.text);
      if (topic == 'location') {
        _loadLocation();
      } else {
        _showTopic(topic);
      }
    });
  });
}

/// Initiates location searches.
void _loadLocation() {
  querySelector('core-drawer-panel').setAttribute('selected', 'main');
  var locationInput = querySelector('#location-input');
  locationInput.value = '';

  CoreOverlay overlay = querySelector('#location-overlay');
  overlay
    ..backdrop = true
    ..opened = true
    ..open();

  // Requests stories about the location once the dialog button is pressed.
  querySelector('#location-button').onClick.listen((event) {
    location = locationInput.value;
    _showLocalStories();
  });

  // Requests stories about the location once the enter key is pressed.
  locationInput.onKeyUp.listen((event) {
    if (event.keyCode == 13 && !locationInput.value.isEmpty) {
      location = locationInput.value;
      overlay
        ..opened = false
        ..close();
      _showLocalStories();
    }
  });
}

/// Initiates the blacklist.
Future _loadBlacklist() async {
  querySelector('#blacklist-settings-button').onClick.listen((event) async {
    var response = await HttpRequest
        .getString('http://localhost:8081?get-blacklist');
    _manageBlacklist(response);
  });
}

/// Shows the blacklisted topics in the comma-separated list [results] or a
/// message indicating that the blacklist is empty when [results] is empty.
void _manageBlacklist(String results) {
  querySelector('core-drawer-panel').setAttribute('selected', 'main');
  var topics = results == '[]'
      ? null
      : results.replaceAll('[', '').replaceAll(']', '').split(', ');
  var list = querySelector('#list-blacklist-topics');
  var items = list.children;
  if (items.length > 0) {
    for (var item in items) {
      item.remove();
    }
  }
  if (topics == null || topics.isEmpty) {
    list.appendHtml('<div>The blacklist is empty.</div>');
    querySelector('#manage-blacklist-button').innerHtml = 'OK';
  } else {
    var checkbox;
    for (var topic in topics) {
      checkbox = new PaperCheckbox();
      checkbox
        ..label = topic
        ..checked = false;
      list.append(checkbox);
    }
    querySelector('#manage-blacklist-button').innerHtml = 'Delete';
  }

  CoreOverlay overlay = querySelector('#manage-blacklist-overlay');
  overlay
    ..backdrop = true
    ..opened = true
    ..open();

  querySelector('#manage-blacklist-button').onClick.listen((event) {
    if (topics != null && !topics.isEmpty) _deleteBlacklistTopics();
  });
}

/// Deletes the selected topics from the blacklist.
Future _deleteBlacklistTopics() async {
  var items = querySelector('#list-blacklist-topics').children;
  var deleted = 0;
  for (var item in items) {
    if (item.checked) {
      await HttpRequest
          .getString('http://localhost:8081?blacklist-delete=${item.label}');
      deleted++;
    }
  }

  if (deleted > 0) {
    showNotification((deleted == 1 ? 'Topic' : 'Topics') +
        ' deleted from the database.');
  }

  refresh();
}

/// Displays local stories.
Future _showLocalStories() async {
  if (location != null && !location.isEmpty) {
    await _showTopic('location', location);
  }
}

/// Changes the menu title to [topic].
void _changeTitle(String topic) {
  querySelector('#title').text = topic == 'Most Recent' ? 'News' : topic;
}

/// Displays stories about the topic [topic], and local stories about the
/// location [location] if it is not empty and [topic] is 'location'.
Future _showTopic(String topic, [String location]) {
  hideStories();
  querySelector('#loading').hidden = false;
  querySelector('core-drawer-panel').setAttribute('selected', 'main');
  var url = 'http://localhost:8081?topic=$topic';
  var request;
  runZoned(() {
    request = new HttpRequest()
      ..timeout = timeout
      ..open('GET', location != null ? '$url&location=$location' : url)
      ..onLoad.listen((event) => _displayStories(event.target.responseText))
      ..onError.listen((event) => showNotification('Cannot reach the server.'))
      ..onTimeout.listen((event) => showNotification('Connection timeout.'))
      ..send();
  }, onError: (e) => print('Server error: $e'));
  return request;
}

/// Hides all the stories.
void hideStories() {
  querySelector('#stories').hidden = true;
}

/// Displays all the stories.
void _showStories() {
  querySelector('#stories').hidden = false;
}

/// Removes all the stories.
void _removeAllStories() {
  var stories = querySelector('#stories').children;
  for (var story in stories) {
    story.remove();
  }
}

/// Displays all the stories encoded in [json].
void _displayStories(String json) {
  if (json == null || json.isEmpty) {
    showNotification('Error retrieving stories from the server.');
  } else {
    var stories = JSON.decode(json);
    if (stories == null || stories.length == 0) {
      showNotification('No stories found.');
    } else {
      _removeAllStories();
      _showStories();
      var storiesDiv = querySelector('#stories');
      var element;
      querySelector('#loading').hidden = true;
      for (var story in stories) {
        element = new StoryElement();
        element.update(story);
        storiesDiv.children.add(element);
      }
    }
  }
}

/// Shows a notification with the message [message].
void showNotification(String message) {
  PaperToast notification = querySelector('#notification');
  notification
    ..text = message
    ..opened = true
    ..show();
  querySelector('#loading').hidden = true;
  _showStories();
}
