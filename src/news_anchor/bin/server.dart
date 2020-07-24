import 'dart:async';
import 'dart:io';
import 'dart:convert' show UTF8, JSON;
import 'package:sqljocky/sqljocky.dart';
import 'package:news_anchor/google_news.dart';
import 'package:news_anchor/story.dart';
import 'google_news_server.dart';
import 'twitter_server.dart';

// MySQL connection pool.
final pool = new ConnectionPool(user: 'dev', password: 'dev',
    db: 'news_anchor');

// The maximum number of results to send to the client at a time.
final loadLimit = 50;

/// The server listens to new HTTP requests and sends Tweets and Google News
/// stories matching the queries.
Future main() async {
  var server = await HttpServer.bind(InternetAddress.ANY_IP_V6, 8081);
  print('Server listening on port ${server.port}...');

  var client = 0;
  var parameters;

  await for (HttpRequest request in server) {
    print('\nProcessing client request #${++client}.');

    // Adds CORS headers.
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    parameters = request.uri.queryParameters;

    try {
      // Handles requests of topics and local stories.
      if (parameters.containsKey('topic')) {
        var query = await _getTopicQuery(parameters['topic'],
            parameters['location']);
        await request.response.write(await _encodeStories(query));

      // Updates stories reactions.
      } else if (parameters.containsKey('reaction')) {
        print('Updating story\'s reaction...');
        var id = parameters['id'];
        var type = parameters['type'];
        await request.response.write(await _setReaction(id, type,
            parameters['reaction']));

      // Returns the reaction of the story.
    } else if (parameters.containsKey('get-reaction')) {
        print('Retrieving story\'s reaction...');
        var result;
        if (await _hasPositiveReaction(parameters['id'], parameters['type'])) {
          result = 'positive';
        } else if ( await _hasNegativeReaction(parameters['id'],
            parameters['type'])) {
          result = 'negative';
        }
        await request.response.write(result);

      // Adds topics to the blacklist.
      } else if (parameters.containsKey('blacklist-add')) {
        var topic = capitalise(parameters['blacklist-add']);
        if (!await blacklistTopicExists(topic)) {
          var query = await pool.prepare('INSERT INTO blacklist (topic) ' +
              'VALUES (?)');
          await query.execute([topic]);
          print('Topic \'$topic\' added to blacklist.');
          await request.response.write('Topic added to the blacklist.');
        }

      // Returns all the topics in the blacklist.
      } else if (parameters.containsKey('get-blacklist')) {
        print('Retrieving topics in the blacklist...');
        var results = await pool.query('SELECT * FROM blacklist ORDER BY ' +
            'topic');
        var topics = new List<String>();
        for (var result in await results.toSet()) {
          topics.add(result.first);
        }
        await request.response.write(topics.toString());

      // Deletes a topic from the blacklist.
      } else if (parameters.containsKey('blacklist-delete')) {
        var topic = parameters['blacklist-delete'];
        if (!await blacklistTopicExists(topic)) {
          await request.response.write('The topic does not exist in the ' +
              'blacklist.');
        } else {
          var query = await pool.prepare('DELETE FROM blacklist WHERE ' +
              'topic = \'$topic\'');
          await query.execute();
          print('Topic \'$topic\' deleted from the blacklist.');
          await request.response.write('Topic deleted from the blacklist.');
        }
      }

      // Invalid parameters in request URL.
      else {
        print('The HTTP request URL contains invalid parameters.');
      }

      print('Completed client request #$client.');
    } catch (e) {
      print('Error handling request: $e');
    }

    await request.response.close();
  }
}

/// Returns a MySQL query for the topic [topic], and if [location] is not null,
/// returns a MySQL query for stories about location [location].
///
/// Throws an [Exception] if there is an error retrieving stories about location
/// [location].
/// Throws an [Exception] if there is an error retrieving stories about custom
/// topic.
Future<String> _getTopicQuery(String topic, [String location]) async {
  var query;
  switch (topic) {
    case 'all':
      query = 'SELECT DISTINCT * FROM story WHERE story.id NOT IN ' +
          '(SELECT s.id FROM story s, blacklist b WHERE LOWER(s.title) LIKE ' +
          'CONCAT(\'%\', LOWER(b.topic), \'%\') OR LOWER(s.text) LIKE ' +
          'CONCAT(\'%\', LOWER(b.topic), \'%\')) AND story.id NOT IN ' +
          '(SELECT t.tweet FROM tweet_hashtag t, blacklist b WHERE ' +
          'LOWER(t.hashtag) LIKE CONCAT(\'%\', LOWER(b.topic), \'%\')) ORDER ' +
          'BY story.date DESC LIMIT $loadLimit';
      break;

    case 'top-stories':
      query = _getQuery('top stories');
      break;

    case 'location':
      if (location != null && !location.isEmpty) {
        try {
          await _searchTwitter(location);
          await addGeoGoogleNewsStories(location);
        } catch (e) {
          throw 'Error retrieving stories about location: $e';
        }
        query = _getQuery(location);
      }
      break;

    case 'world':
      query = _getQuery('world');
      break;

    case 'uk':
      query = _getQuery('u.k.');
      break;

    case 'business':
      query = _getQuery('business');
      break;

    case 'technology':
      query = _getQuery('technology');
      break;

    case 'entertainment':
      query = _getQuery('entertainment');
      break;

    case 'sports':
      query = _getQuery('sports');
      break;

    case 'science':
      query = _getQuery('science');
      break;

    case 'health':
      query = _getQuery('health');
      break;

    case 'positive-reactions':
      query = 'SELECT s.* FROM story s, reaction r WHERE ((r.type = ' +
          '\'twitter\' AND r.story = s.tweet_id) OR (r.type = \'googlenews\' ' +
          'AND r.story = s.google_news_id)) AND r.reaction = \'positive\' ' +
          'ORDER BY s.date DESC LIMIT $loadLimit';
      break;

    case 'negative-reactions':
      query = 'SELECT s.* FROM story s, reaction r WHERE ((r.type = ' +
          '\'twitter\' AND r.story = s.tweet_id) OR (r.type = \'googlenews\' ' +
          'AND r.story = s.google_news_id)) AND r.reaction = \'negative\' ' +
          'ORDER BY s.date DESC LIMIT $loadLimit';
      break;

    case 'blacklist':
      query = 'SELECT DISTINCT * FROM story WHERE story.id IN (SELECT s.id ' +
          'FROM story s, blacklist b WHERE LOWER(s.title) LIKE CONCAT(\'%\', ' +
          'LOWER(b.topic), \'%\') OR LOWER(s.text) LIKE CONCAT(\'%\', ' +
          'LOWER(b.topic), \'%\')) OR story.id IN (SELECT t.tweet FROM ' +
          'tweet_hashtag t, blacklist b WHERE LOWER(t.hashtag) LIKE ' +
          'CONCAT(\'%\', LOWER(b.topic), \'%\')) ORDER BY story.date DESC ' +
          'LIMIT $loadLimit';
      break;

    default:
      try {
        await _searchTwitter(topic);
        await _searchGoogleNews(topic);
      } catch(e) {
        throw 'Error retrieving stories about custom topic: $e';
      }
      query = _getQuery(topic);
  }

  return query;
}

/// Searches for Tweets about the topic [topic] and adds them to the database.
///
/// Throws and [Exception] if there is an error searching for Tweets.
Future _searchTwitter(String topic) async {
  try {
    await searchTwitter(topic);
  } catch(e) {
    print('Error searching on Twitter: $e');
  }
}

/// Searches for Google News stories about the topic [topic] and adds them to
/// the database.
///
/// Throws and [Exception] if there is an error searching for Google News
/// stories.
Future _searchGoogleNews(String topic) async {
  try {
    var stories = new List<GoogleNewsStory>();
    stories.addAll(await retrieveNewStories(topic));
    if (stories.length > 0) await addStories(stories);
  } catch(e) {
    print('Error searching for Google News stories: $e');
  }
}

/// Returns a MySQL query for the topic [topic].
String _getQuery(String topic) {
  var query;
  if (topic != null && !topic.isEmpty) {
    query = 'SELECT * FROM story s, tweet_hashtag h WHERE ' +
        'LOWER(topic) = \'${topic.toLowerCase()}\' OR (s.id = h.tweet AND ' +
        'LOWER(h.hashtag) = \'${topic.toLowerCase()}\') OR s.text LIKE ' +
        '\'%${topic.toLowerCase()}%\' GROUP BY s.id ORDER BY s.date DESC ' +
        'LIMIT $loadLimit';
  }
  return query;
}


/// Returns a JSON encoded object containing all the stories stored in the
/// database.
///
/// Throws an [Exception] if there is error encoding stories.
Future<String> _encodeStories(String query) async {
  print('Retrieving stories from the database...');

  var stories = new List<Story>();
  if (query != null) {
    try {
      var results = await pool.query(query);
      var rows = await results.toList();
      for (var row in rows) {
        stories.add(await _createStory(row));
      }
    } catch (e) {
      throw 'Error encoding stories: $e';
    }
  } else {
    print('No stories found.');
  }
  return JSON.encode(stories);
}

/// Returns a story created with the data retrieved from the database row [row].
///
/// Throws an [Exception] if the story type is invalid.
Future<Story> _createStory(Row row) async {
  var story;
  var type = row[1];
  switch (type) {
    // Creates a Tweet.
    case 'twitter':
      story = await createTweet(row);
      print('Encoding Tweet with ID ${story.id}...');
      break;

    // Creates a Google News story.
    case 'googlenews':
      story = await createGoogleNewsStory(row);
      print('Encoding Google News story with guid ${story.guid}...');
      break;

    // Invalid story type.
    default:
      throw 'Invalid story type: \'$type\'.';
  }
  return story;
}

/// Sets the reaction of the story with ID [id] and type [type].
///
/// If the story already has reaction  [reaction] it is deleted. If the story
/// already has a previous reaction it is updated to [reaction]. Otherwise, a
/// new reaction [reaction] is added to the story.
///
/// Throws an [Exception] if there the arguments are invalid.
/// Throws an [Exception] if there is an error setting the story reaction.
Future<String> _setReaction(String id, String type, String reaction) async {
  var message;
  try {
    if (reaction == 'positive' && await _hasPositiveReaction(id, type)) {
      _deleteReaction(id, type);
      message = 'Story deleted from Positive Reactions.';
    } else if (reaction == 'positive' && await _hasNegativeReaction(id, type)) {
      _updateReaction(id, type, reaction);
      message = 'Story updated to Positive Reactions.';
    } else if (reaction == 'positive') {
      _addReaction(id, type, reaction);
      message = 'Story added to Positive Reactions.';
    } else if (reaction == 'negative' && await _hasNegativeReaction(id, type)) {
      _deleteReaction(id, type);
      message = 'Story deleted from Negative Reactions.';
    } else if (reaction == 'negative' && await _hasPositiveReaction(id, type)) {
      _updateReaction(id, type, reaction);
      message = 'Story updated to Negative Reactions.';
    } else if (reaction == 'negative') {
      _addReaction(id, type, reaction);
      message = 'Story added to Negative Reactions.';
    } else {
      throw 'Invalid arguments to set reaction';
    }
    print(message);
  } catch (e) {
    throw 'Error setting story reaction: $e';
  }
  return message;
}

/// Adds the reaction [reaction] to the story with ID [id] and type [type] to
/// the database.
///
/// Throws an [Exception] if there is an error adding the story reaction.
Future _addReaction(String id, String type, String reaction) async {
  try {
    var query = await pool.prepare('INSERT INTO reaction (story, type, ' +
        'reaction) VALUES (?, ?, ?)');
    await query.execute([id, type, reaction]);
  } catch (e) {
    throw 'Error adding story reaction: $e';
  }
}

/// Updates the reaction of the story with ID [id] and type [type] to [reaction]
/// in the database.
///
/// Throws an [Exception] if there is an error updating the story reaction.
Future _updateReaction(String id, String type, String reaction) async {
  try {
    var query = await pool.prepare('UPDATE reaction SET reaction = (?) ' +
        'WHERE story = \'$id\' AND type = \'$type\'');
    await query.execute([reaction]);
  } catch (e) {
    throw 'Error updating story reaction: $e';
  }
}

/// Deletes a reaction from the story with ID [id] and type [type] from the
/// database.
///
/// Throws an [Exception] if there is an error deleting the story reaction.
Future _deleteReaction(String id, String type) async {
  try {
    var query = await pool.prepare('DELETE FROM reaction WHERE story = ' +
        '\'$id\' AND type = \'$type\'');
    await query.execute();
  } catch (e) {
    throw 'Error deleting story reaction: $e';
  }
}

/// Returns true if the story with ID [id] and type [type] has a positive
/// reaction.
///
/// Rethrows an [Exception] if there is an error counting the stories reactions.
Future<bool> _hasPositiveReaction(String id,  String type) async {
  return await _hasReaction(id, type, 'positive');
}

/// Returns true if the story with ID [id] and type [type] has a negative
/// reaction.
///
/// Rethrows an [Exception] if there is an error counting the stories reactions.
Future<bool> _hasNegativeReaction(String id,  String type) async {
  return await _hasReaction(id, type, 'negative');
}

/// Returns true if the story with ID [id] and type [type] has the reaction
/// [reaction].
///
/// This is a generic function which should not be called directly. Please use
/// the functions [_hasPositiveReaction] and [_hadNegativeReaction] instead.
///
/// Throws an [Exception] if there is an error counting the stories reactions.
Future<bool> _hasReaction(String id,  String type, String reaction) async {
  var row;
  try {
    var results = await pool.query('SELECT COUNT(*) FROM reaction WHERE ' +
        'story = \'$id\' AND type = \'${type.toLowerCase()}\' AND reaction = ' +
        '\'$reaction\'');
    row = await results.first;
  } catch (e) {
    throw 'Error counting stories reactions: $e';
  }
  return row.first > 0;
}

/// Returns true if the topic [topic] is already in the blacklist.
///
/// Throws an [Exception] if there is an error retrieving blacklisted topics
/// from the database.
Future<bool> blacklistTopicExists(String topic) async {
  var row;
  try {
    var results = await pool.query('SELECT COUNT(*) FROM blacklist WHERE ' +
        'LOWER(topic) = \'${topic.toLowerCase()}\'');
    row = await results.first;
  } catch (e) {
    throw 'Error retrieving blacklisted topics from database: $e';
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
