import 'dart:async';
import 'story.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// A Tweet.
///
/// A Tweet thats extends [Story].
class Tweet extends Story {
  num id;
  User user;
  DateTime date;
  String text;
  String url;
  List<String> hashtags;
  Map<String, String> urls;
  String mediaUrl;
  List<String> photos;

  /// Creates a new Tweet object with ID [id], Twitter account [user], date
  /// published [date], Tweet content [text], URL [url] and, optionally, list of
  /// hashtags [hashtags], list of URL mappings [urls], media URL [mediaUrl] and
  /// list of photos [photos].
  ///
  /// It extends the class [Story] with type 'twitter'.
  Tweet(this.id, this.user, this.date, this.text, this.url, [this.hashtags,
      this.urls, this.mediaUrl, this.photos]) : super('twitter');

  /// Creates a new Tweet object from the JSON object [json].
  /// It extends the class [Story] with type 'twitter'.
  ///
  /// Throws an [Exception] if there is an error parsing the date.
  Tweet.parse(dynamic json) : super('twitter') {
    id = json['id'];
    user = new User.parse(json['user']);

    runZoned(() =>
      initializeDateFormatting("en_GB", null).then((_) =>
        date = new DateFormat('EEE MMM dd HH:mm:ss yyyy')
            .parse(_removeTimezone(json['created_at']))),
      onError: (e) => 'Error parsing Tweet date: $e');

    text = json['text'];
    url = (user != null)
        ? 'https://twitter.com/${user.screenName}/status/$id'
        : null;
    hashtags = new List<String>();
    urls = new Map<String, String>();

    var entities = json['entities'];
    if (entities != null) {
      if (entities['hashtags'] != null) {
        for (var hashtag in entities['hashtags']) {
          hashtags.add(hashtag['text']);
        }
      }

      if (entities['urls'] != null) {
        for (var url in entities['urls']) {
          urls[url['url']] = url['display_url'];
        }
      }

      if (entities['media'] != null) {
        mediaUrl = entities['media'][0]['url'];
      }
    }

    photos = new List<String>();

    var extendedEntities = json['extended_entities'];
    if (extendedEntities != null) {
      if (extendedEntities['media'] != null) {
        for (var media in extendedEntities['media']) {
          photos.add(media['media_url_https']);
        }
      }
    }
  }

  /// Returns the date [date] without the timezone.
  String _removeTimezone(String date) =>
      date.replaceAll(new RegExp(r'(\+|-)\d{4} '), '');

  /// Used to concert this Tweet object into a JSON string.
  Map toJson() {
    var json = new Map();
    json['type'] = type;
    if (id != null) json['id'] = id;
    if (user != null) json['user'] = user;
    if (date != null) json['date'] = date.toString();
    if (text != null) json['text'] = text;
    if (url != null) json['url'] = url;
    if (hashtags != null && hashtags.length > 0) json['hashtags'] = hashtags;
    if (urls != null && urls.length > 0) json['urls'] = _urlsToJson();
    if (mediaUrl != null) json['mediaUrl'] = mediaUrl;
    if (photos != null && photos.length > 0) json['photos'] = photos;
    return json;
  }

  /// Used to convert this Tweet's URLs into a JSON string.
  List<Map<String, String>> _urlsToJson() {
    var json = new List<Map<String, String>>();
    urls.forEach((String url, String displayUrl) {
      json.add({
        'url': url,
        'displayUrl': displayUrl
      });
    });
    return json;
  }

  /// Returns a textual representation of this Tweet with the Twitter account,
  /// date published and text.
  @override
  String toString() =>
      'Twitter user: $user\n\n' +
      'Date: $date\n\n' +
      'Tweet: $text';
}

/// A Twitter user.
///
/// A user has a screen name, which is a unique identifier on Twitter, a name,
/// a profile image, a location and a unique URL, based on its screen name, in
/// the format 'https://twitter.com/<screenName>'.
class User {
  String screenName;
  String name;
  String profileImage;
  String location;
  String url;

  /// Creates a new User object with screen name [screenName], name [name],
  /// profile image URL [profileImage] and, optionally, location [location].
  User(this.screenName, this.name, this.profileImage, [this.location]) {
    this.url = screenName != null ? 'https://twitter.com/$screenName' : null;
  }

  /// Creates a new User object from the JSON object [json].
  User.parse(dynamic json) {
    screenName = json['screen_name'];
    name = json['name'];
    profileImage = json['profile_image_url_https'];
    location = json['location'];
    url = screenName != null ? 'https://twitter.com/$screenName' : null;
  }

  /// Used to convert this User object into a JSON string.
  Map toJson() {
    var json = new Map();
    if (screenName != null) json['screenName'] = screenName;
    if (name != null) json['name'] = name;
    if (profileImage != null) json['profileImage'] = profileImage;
    if (location != null) json['location'] = location;
    if (url != null) json['url'] = url;
    return json;
  }

  /// Returns a textual representation of this User with the name and screen
  /// name.
  @override
  String toString() => '$name (@$screenName)';
}
