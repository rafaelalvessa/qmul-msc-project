import 'dart:async';
import 'dart:convert' show UTF8;
import 'dart:io';
import 'package:dart_feed/dart_feed.dart';
import 'package:sqljocky/sqljocky.dart';
import 'package:news_anchor/google_news.dart';

// MySQL connection pool.
final pool = new ConnectionPool(user: 'dev', password: 'dev',
    db: 'news_anchor');

/// Executes the option specified in [args].
/// Available options:
///
/// * add-topic <topic>: Adds the specified topic to the database.
/// * show-topics: Displays all the topics stored in the database.
/// * help: Displays usage instructions.
Future main(List<String> args) async {
  if (args.length < 1) {
    _invalidArgs();
  } else {
    switch (args[0]) {
      // Adds a topic to the database.
      case 'add-topic':
        if (args.length != 2) {
          _invalidArgs();
        } else {
          try {
            await _addTopic(args[1]);
          } catch (e) {
            print('Error adding topic: $e');
          }
        }
        break;

      // Displays all the topics stored in the database.
      case 'show-topics':
        try {
          var topics = await _getTopics();
          if (topics.length == 0) {
            print('There are no topics.');
          } else {
            for (var topic in topics) {
              print(topic);
            }
          }
        } catch (e) {
          print('Error showing topics: $e');
        }
        break;

      // Displays usage instructions.
      case 'help':
      default:
        _help();
    }
  }

  // Closes the MySQL connection pool.
  pool.closeConnectionsWhenNotInUse();
}

/// Displays a message informing the arguments are invalid, followed by usage
/// instructions.
void _invalidArgs() {
  print('Invalid arguments.\n');
  _help();
}

/// Displays usage instructions.
void _help() {
  print('Usage: dart google_news_server.dart <option>\n');
  print('Options:');
  print('\tadd-topic <topic>');
  print('\t\tAdd specified topic to the database.\n');
  print('\tshow-topics');
  print('\t\tDisplay all the topics stored in the database.\n');
  print('\thelp');
  print('\t\tDisplay usage instructions.');
}

/// Returns a [Future] with a list containing new Google News stories for all
/// the topics stored in the database.
///
/// Rethrows an [Exception] if there is an error retrieving topics from the
/// database.
/// Rethrows an [Exception] if there is an error parsing a Google News story.
/// Rethrows an [Exception] if there is an error retrieving stories from Google
/// News.
Future<List<GoogleNewsStory>> getGoogleNewsStories() async {
  print('Fetching updates from Google News...');
  var topics = await _getTopics();
  var stories = new List<GoogleNewsStory>();
  for (var topic in topics) {
    stories.addAll(await retrieveNewStories(topic));
  }
  return stories;
}

/// Adds all the Google News stories in the list [stories] to the database.
///
/// Rethrows an [Exception] if there is an error adding a Google News story to
/// the database.
Future addStories(List<GoogleNewsStory> stories) async {
  print('Adding Google News stories to database...');
  for (var story in stories) {
    await _addGoogleNewsStory(story);
  }
}

/// Adds Google News stories about the city, country or other area named
/// [location] to the database.
///
/// Throws an [Exception] if there is an error adding the Google News story to
/// the database.
Future addGeoGoogleNewsStories(String location) async {
  print('Adding Google News stories about location ' +
      '\'${capitalise(location)}\'...');

  try {
    // Requests the RSS feed with stories from Google News and parses it.
    var items = (await Feed.fromString(await _makeRequest('location',
        location))).items;

    var story;
    for (var item in items) {
      try {
        story = new GoogleNewsStory.parse(item);
      } catch (e) {
        print('Error parsing Google News story: $e');
        continue;
      }

      // Adds the Google News story to the database it if does not exist yet.
      if (!await _googleNewsStoryExists(story.guid)) {
        await _addGoogleNewsStory(story);
      }
    }
  } catch (e) {
    throw 'Error adding geographical Google News stories: $e';
  }
}

/// Returns a [GoogleNewsStory] object created from the [Story] retrieved from
/// the database row [row].
Future<GoogleNewsStory> createGoogleNewsStory(Row row) async {
  var story;
  try {
    var date = DateTime.parse('${row[7]}');
    story = new GoogleNewsStory(row[3], row[4], row[5], date, row[8], row[9],
        imageUrl: row[10], topic: row[11]);
  } catch (e) {
    throw 'Error creating Google News Story: $e';
  }
  return story;
}

/// Returns a list containing new stories from Google News about the topic
/// [topic] which do no exist in the database yet.
///
/// Throws an [Exception] if there is an error parsing a Google News story.
/// Throws an [Exception] if there is an error retrieving stories from Google
/// News.
Future <List<GoogleNewsStory>> retrieveNewStories(String topic) async {
  print('Fetching Google News stories about \'${capitalise(topic)}\'...');

  var stories = new List<GoogleNewsStory>();
  try {
    // Requests the RSS feed with stories from Google News and parses it.
    var items = (await Feed.fromString(await _makeRequest(topic))).items;

    // Parses stories from each RSS feed item.
    var story;
    for (var item in items) {
      try {
        story = new GoogleNewsStory.parse(item);
        story.topic = capitalise(topic);
      } catch (e) {
        print('Error parsing Google News story: $e');
        continue;
      }

      // Adds the Google News story to the list of stories if it does not exist.
      if (!await _googleNewsStoryExists(story.guid)) stories.add(story);
    }
  } catch (e) {
    throw 'Error retrieving stories from Google News: $e';
  }
  return stories;
}

/// Adds the Google News story [story] to the database if it does not exist yet.
///
/// Throws an [Exception] if there is an error adding the Google News story to
/// the database.
Future _addGoogleNewsStory(GoogleNewsStory story) async {
  try {
    if (await _googleNewsStoryExists(story.guid)) {
      print('Google News story with ID #${story.guid} already exists in the ' +
          'database.');
    } else {
      var query = await pool.prepare('INSERT INTO story (type, ' +
          'google_news_id, title, publisher, date, text, url, image_url, ' +
          'topic) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');

      await query.execute(['googlenews', story.guid, story.title,
          story.publisher, story.date, story.headline, story.url,
          story.imageUrl, story.topic]);

      print('Added Google News story with guid ${story.guid}.');
    }
  } catch (e) {
    throw 'Error adding Google News story to database: $e';
  }
}

/// Returns the contents of a Google News RSS feed for the topic [topic].
///
/// If [topic] is 'Location', then [location] must be specified with the name of
/// a city, country or other area.
///
/// Throws an [Exception] if there is an error preparing the Google News
/// request.
/// Throws an [Exception] if there is an error retrieving content from Google
/// News.
Future<String> _makeRequest(String topic, [String location]) async {
  var client = new HttpClient();
  var contents;

  // Waits until the request is complete and closes the connection.
  try {
    var request = await client.getUrl(_getRequestUrl(topic, location));
    var response = await request.close();
    contents = await response.transform(UTF8.decoder).join();
  } catch (e) {
    throw 'Error retrieving content from Google News: $e';
  }
  client.close();

  return contents;
}

/// Returns the URI to request stories from Google News about the topic [topic].
///
/// If the [topic] is 'Location', [location] must be specified with the name of
/// a city, country or other area.
///
/// Throws an [Exception] if [location] is not specified for geographical
/// stories.
Uri _getRequestUrl(String topic, [String location]) {
  var url = 'https://news.google.co.uk/news/section?cf=all&hl=en&pz=1&ned=uk';

  switch (topic.toLowerCase()) {
    // Top stories.
    case 'top stories':
      break;

    // Local stories for specified location.
    case 'location':
      if (location == null) throw 'Location not specified.';
      url += '&geo=${capitalise(location)}';
      break;

    // World.
    case 'world':
      url += '&topic=w';
      break;

    // U.K.
    case 'u.k.':
      url += '&topic=n';
      break;

    // Business.
    case 'business':
      url += '&topic=b';
      break;

    // Technology.
    case 'technology':
      url += '&topic=tc';
      break;

    // Entertainment.
    case 'entertainment':
      url += '&topic=e';
      break;

    // Sports.
    case 'sports':
      url += '&topic=s';
      break;

    // Science.
    case 'science':
      url += '&topic=snc';
      break;

    // Health.
    case 'health':
      url += '&topic=m';
      break;

    // Custom topic.
    default:
      url += '&q=${capitalise(topic)}';
  }

  return Uri.parse('$url&output=rss');
}

/// Returns true if the Google News story with guid [guid] already exists in the
/// database.
///
/// Throws an [Exception] if there is an error retrieving Google News stories
/// from the database.
Future<bool> _googleNewsStoryExists(String guid) async {
  var row;
  try {
    var results = await pool.query('SELECT COUNT(*) FROM story WHERE ' +
        'google_news_id = \'$guid\'');
    row = await results.first;
  } catch (e) {
    'Error retrieving Google News stories from database: $e';
  }
  return row.first > 0;
}

/// Adds the topic [topic] to the database if it does not exist already.
///
/// Throws and [Exception] if there is an error adding the topic to the
/// database.
Future _addTopic(String topic) async {
  var name = capitalise(topic);
  try {
    if (await _topicExists(topic)) {
      print('Topic \'$name\' already exists in the database.');
    } else {
      await pool.query('INSERT INTO topic (name) VALUES (\'$name\')');
      print('Topic \'$name\' added to database.');
    }
  } catch (e) {
    throw 'Error adding topic to database: $e';
  }
}

/// Returns true if the topic [topic] already exists in the database.
///
/// Throws an [Exception] if there is an error retrieving topics from the
/// database.
Future<bool> _topicExists(String topic) async {
  var row;
  try {
    var results = await pool.query('SELECT COUNT(*) FROM topic WHERE ' +
        'LOWER(name) = \'${topic.toLowerCase()}\'');
    row = await results.first;
  } catch (e) {
    throw 'Error retrieving topics from database: $e';
  }
  return row.first > 0;
}

/// Returns the [text] without any leading and trailing whitespace, with the
/// initial letter of each word capitalised, and the rest of the word in lower
/// case.
///
/// For example, ' CAPITALISE this text ' becomes 'Capitalise This Text'.
String capitalise(String text) {
  return text.trim().toLowerCase().replaceAllMapped(new RegExp(r'(\w{1})(\w*)'),
      (Match match) => '${match[1].toUpperCase()}${match[2]}');
}

/// Returns a list containing all the topics stored in the database.
///
/// Throws an [Exception] if there is an error retrieving topics from the
/// database.
Future<List<String>> _getTopics() async {
  var topics = new List<String>();
  try {
    var results = await pool.query('SELECT name FROM topic');
    await results.forEach((Row row) {
      topics.add(row.first);
    });
  } catch (e) {
    throw 'Error retrieving topics from database: $e';
  }
  return topics;
}
