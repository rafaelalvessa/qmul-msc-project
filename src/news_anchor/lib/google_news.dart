import 'story.dart';
import 'package:dart_feed/dart_feed.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

/// A Google News Story that extends [Story].
class GoogleNewsStory extends Story {
  String guid;
  String title;
  String publisher;
  DateTime date;
  String headline;
  String imageUrl;
  String url;
  String topic;

  /// Creates a new GoogleNewsStory object with guid [guid], title [title],
  /// publisher [publisher], date [date], headline [headline], URL [url] and,
  /// optionally, image URL [imageUrl] and topic [topic].
  ///
  /// It extends the class [Story] with type 'googlenews'.
  GoogleNewsStory(this.guid, this.title, this.publisher, this.date,
      this.headline, this.url, {this.imageUrl, this.topic}) :
      super('googlenews');

  /// Creates a new Google News Story object from the RSS feed item [item]. It
  /// expects [item] to be formatted in the correct way, otherwise an
  /// [Exception] will be thrown when trying to parse the content.
  ///
  /// It extends the class [Story] with type 'googlenews'.
  GoogleNewsStory.parse(Item item) : super('googlenews') {
    guid = _parseId(item.guid);
    var titlePublisher = _parseTitlePublisher(item.title);
    title = titlePublisher['title'];
    publisher = titlePublisher['publisher'];
    date = item.pubDate;
    Document document = parse(item.description);
    headline = _parseHeadline(document);
    imageUrl = _parseImageUrl(document);
    url = _parseUrl(item.link);
  }

  /// Returns the guid extracted from [guid].
  String _parseId(Guid guid) => guid.guid
      .replaceAllMapped(new RegExp(r'(.*)(cluster=)(\w)'),
      (Match match) => "${match[3]}");

  /// Returns a [Map] with the title and publisher extracted from the item's
  /// title [title]. The value of the key 'title' is the title of the item. The
  /// value of the key 'publisher' is the publisher of the item.
  Map<String, String> _parseTitlePublisher(String title) {
    var separator = title.lastIndexOf('-');
    return {
      'title': title.substring(0, separator - 1),
      'publisher': title.substring(separator + 2)
    };
  }

  /// Returns the headline of the story extracted from the HTML document
  /// [document].
  String _parseHeadline(Document document) =>
      document.getElementsByClassName('lh').first
          .getElementsByTagName('font')[2].innerHtml;

  /// Returns the URL for the image of the story extracted from the HTML
  /// document [document].
  String _parseImageUrl(Document document) {
    var url;
    var img = document.querySelector('img');
    if (img != null) {
      var src = img.attributes['src'];
      url = src != null
          ? src
          : '//lh3.googleusercontent.com/WDtkBc_' +
          'UXsX7NfsYVrV5nK9hXj6OH2ficlRFCOuGV52vk_PaHJHNSTeQpE0ioV2G4j0_=w100';
    }
    return 'https:$url';
  }

  /// Returns the URL of the story that is embedded in the Google News URL
  /// [url].
  /// The value of the parameter 'url' is extracted from [url].
  String _parseUrl(Uri url) => url.queryParameters['url'];

  /// Used to convert this Google News story object into a JSON string.
  Map toJson() {
    var json = new Map();
    json['type'] = type;
    if (guid != null) json['id'] = guid;
    if (title != null) json['title'] = title;
    if (publisher != null) json['publisher'] = publisher;
    if (date != null) json['date'] = date.toString();
    if (headline != null) json['text'] = headline;
    if (imageUrl != null) json['imageUrl'] = imageUrl;
    if (url != null) json['url'] = url;
    if (topic != null) json['topic'] = topic;
    return json;
  }

  /// Returns a textual representation of this Google News story with the
  /// story's title, publisher, date and headline.
  String toString() =>
      'Title: $title\n\n' +
      'Publisher: $publisher\n\n' +
      'Date: $date\n\n' +
      'Headline: $headline';
}
