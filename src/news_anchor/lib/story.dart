/// A Story can be a Tweet or a Google News Story.
///
/// A Tweet has type 'twitter' and a Google News Story has type 'googlenews'.
class Story {
  String type;

  /// Creates a new Story object with type [type], date [date], text [text] and
  /// URL [url].
  Story(this.type);
}
