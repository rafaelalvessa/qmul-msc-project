import 'dart:async';
import 'dart:convert' show UTF8, JSON;
import 'dart:io';
import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:sqljocky/sqljocky.dart';
import 'package:news_anchor/twitter.dart';
import 'package:news_anchor/story.dart';

// MySQL connection pool.
final pool = new ConnectionPool(user: 'dev', password: 'dev',
    db: 'news_anchor');

/// Executes the option specified in [args].
/// Available options:
///
/// * add-users <user1 user2...>: Adds the specified users to the database.
/// * show-users: Displays all the users stored in the database.
/// * help: Displays usage instructions.
Future main(List<String> args) async {
  if (args.length == 0) {
    _invalidArgs();
  } else {
    switch (args[0]) {
      // Adds users to the database.
      case 'add-users':
        if (args.length < 2) {
          _invalidArgs();
        } else if (args.length > 101) {
          print('Only 100 users can be added at a time.');
        } else {
          try {
            await _addUsers(args.sublist(1).join(','));
          } catch (e) {
            print('Error adding users: $e');
          }
        }
        break;

      // Displays all the users stored in the database.
      case 'show-users':
      try {
        var users = await _getScreenNames();
        if (users.length == 0) {
          print('There are no users.');
        } else {
          for (var user in users) {
            print(user);
          }
        }
      } catch (e) {
        print('Error showing users: $e');
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

/// Displays usage instructions and shows all available options.
void _help() {
  print('Usage: dart twitter.dart <option>\n');
  print('Options:');
  print('\tadd-users <user1 user2 ...>');
  print('\t\tAdd specified users to the database.\n');
  print('\tshows-users');
  print('\t\tDisplay all the users stored in the database.\n');
  print('\thelp');
  print('\t\tDisplay usage instructions.');
}

/// Returns a list with new Tweets by all the users in the database.
Future<List<Tweet>> getTweets() async {
  print('Fetching updates from Twitter...');
  var users = await _getScreenNames();
  var tweets = new List<Tweet>();
  for (var user in users) {
    tweets.addAll(await _retrieveNewTweets(user));
  }
  return tweets;
}

/// Searches Twitter for Tweets about [query] and adds them to the database.
///
/// Throws an [Exception] if there is an error searching on Twitter.
Future searchTwitter(String query) async {
  print('Searching on Twitter...');
  var requestUrl = 'https://api.twitter.com/1.1/search/tweets.json?q=$query' +
      '&lang=en&count=10';
  try {
    // Requests Tweets in JSON, parses them and adds them to the database.
    await addTweets(await _parseTweets(await _makeRequest(requestUrl)));
  } catch (e) {
    throw 'Error adding searched Tweets: $e';
  }
}

/// Adds the Tweets in the list [tweets] to the database.
///
/// If a Tweet already exists in the database, that Tweet is skipped.
///
/// Throws an [Exception] if there is an error adding Tweets to the database.
Future addTweets(List<Tweet> tweets) async {
  print('Adding Tweets to database...');

  try {
    var query = await pool.prepare('INSERT INTO story (type, tweet_id, ' +
        'twitter_user, date, text, url, image_url) VALUES (?, ?, ?, ?, ?, ?, ' +
        '?)');
    var user;
    for (var tweet in tweets) {
      // Adds Twitter user if it does not exist yet.
      user = tweet.user.screenName;
      if (!await _userExists(user)) await _addUsers(user);

      // Skips Tweet if it already exists in the database.
      if (await _tweetExists(tweet.id)) {
        print('Tweet with ID ${tweet.id} already exists in the database.');
        continue;
      }

      await query.execute(['twitter', tweet.id, user, tweet.date, tweet.text,
          tweet.url, tweet.mediaUrl]);

      // Adds the Tweet's hashtags, URLs and photos URLs to the database.
      var storyId = await _getStoryId(tweet.id);
      if (tweet.hashtags.length > 0) {
        await _addHashtags(storyId, tweet.hashtags);
      }
      if (tweet.urls.length > 0) await _addUrls(storyId, tweet.urls);
      if (tweet.photos.length > 0) await _addPhotos(storyId, tweet.photos);

      print('Added Tweet by @$user with ID ${tweet.id}.');
    }
  } catch (e) {
    throw 'Error adding Tweets: $e';
  }
}

/// Adds up to 20 Tweets older than the oldest Tweet published by the user with
/// screen name [screenName] and stored in the database.
///
/// Rethrows an [Exception] if there is any error adding Tweets to the database.
Future addOlderTweetsBy(String screenName) async =>
    await addTweets(await _fetchOlderTweetsBy(screenName));

/// Returns a [Tweet] created from the [Story] retrieved from the database row
/// [row].
Future<Tweet> createTweet(Row row) async {
  var tweet;
  try {
    var id = row[0];
    var user = await _getUser(id);
    var date = DateTime.parse('${row[7]}');
    var hashtags = await _getHashtags(id);
    var urls = await _getUrls(id);
    var photos = await _getPhotos(id);
    tweet = new Tweet(row[2], user, date, row[8], row[9], hashtags, urls,
        row[10], photos);
  } catch (e) {
    throw 'Error creating Tweet: $e';
  }
  return tweet;
}

/// Returns the [User] who published the [Story] with ID [id].
///
/// Throws an [Exception] if there is an error retrieving the user from the
/// database.
Future<User> _getUser(int id) async {
  var user;
  try {
    var results = await pool.query('SELECT u.screen_name, u.name, ' +
        'u.profile_image, u.location FROM twitter_user u, story s WHERE ' +
        'u.screen_name = s.twitter_user AND s.id = $id');
    var rows = await results.toSet();
    if (rows != null && rows.length == 1) {
      var row = rows.first;
      if (row != null && row.length == 4) {
        user = new User(row[0], row[1], row[2], row[3]);
      }
    }
  } catch (e) {
    throw 'Error retrieving user from the database.';
  }
  return user;
}

/// Returns a list containing the hashtags for the [Story] with ID [id].
///
/// Throws an [Exception] if there is an error retrieving hashtags from the
/// database.
Future<List<String>> _getHashtags(int id) async {
  var hashtags = new List<String>();
  try {
    var results = await pool.query('SELECT DISTINCT(h.name) FROM hashtag h, ' +
        'tweet_hashtag t WHERE h.name = t.hashtag AND t.tweet = $id');
    await results.forEach((Row row) {
        if (row != null && row.length == 1) hashtags.add(row[0]);
    });
  } catch (e) {
    throw 'Error retrieving hashtags from the database.';
  }
  return hashtags;
}

/// Returns a map containing the URLs and display URLs for the [Story] with ID
/// [id].
///
/// Throws an [Exception] if there is an error retrieving URLs from the
/// database.
Future<Map<String, String>> _getUrls(int id) async {
  var urls = new Map<String, String>();
  try {
    var results = await pool.query('SELECT DISTINCT(u.url), u.display_url ' +
        'FROM url u, tweet_url t WHERE u.url = t.url AND t.tweet = $id');
    await results.forEach((Row row) {
      if (row != null && row.length == 2) urls[row[0]] = row[1];
    });
  } catch (e) {
    throw 'Error retrieving URLs from the database.';
  }
  return urls;
}

/// Returns a list containing the photos URLs for the [Story] with ID [id].
///
/// Throws an [Exception] if there is an error retrieving photos URLs from the
/// database.
Future<List<String>> _getPhotos(int id) async {
  var photos = new List<String>();
  try {
    var results = await pool.query('SELECT DISTINCT(p.url) FROM photo p, ' +
        'tweet_photo t WHERE p.url = t.photo AND t.tweet = $id');
    await results.forEach((Row row) {
        if (row != null && row.length == 1) photos.add(row[0]);
    });
  } catch (e) {
    throw 'Error retrieving photos URLs from the database.';
  }
  return photos;
}

/// Adds all the hashtags in [hashtags] to the database and associates them with
/// the Tweet with story ID [id].
///
/// Throws an [Exception] if there is an error adding the hashtags.
Future _addHashtags(int id, List<String> hashtags) async {
  try {
    for (var hashtag in hashtags) {
      await _addHashtag(hashtag);
      var query = await pool.prepare('INSERT INTO tweet_hashtag (tweet, ' +
        'hashtag) VALUES (?, ?)');
      await query.execute([id, hashtag]);
    }
  } catch (e) {
    throw 'Error adding hashtags: $e';
  }
}

/// Adds the hashtag [hashtag] to the database if it does not exist already.
///
/// Throws an [Exception] if there is an error adding the hashtag to the
/// database.
Future _addHashtag(String hashtag) async {
  try {
    var results = await pool.query('SELECT COUNT(*) FROM hashtag WHERE ' +
        'name = \'$hashtag\'');

    // Adds hashtag to the database if it does not exist already.
    if ((await results.first).first == 0) {
      var query = await pool.prepare('INSERT INTO hashtag (name) VALUES (?)');
      await query.execute([hashtag]);
    }
  } catch (e) {
    throw 'Error adding hashtag to database: $e';
  }
}

/// Adds all the URL in [urls] to the database and associates them with the
/// Tweet with story ID [id].
///
/// Throws an [Exception] if there is an error adding the URLs.
Future _addUrls(int id, Map<String, String> urls) async {
  try {
    urls.forEach((String url, String displayUrl) async {
      await _addUrl(url, displayUrl);
      var query = await pool.prepare('INSERT INTO tweet_url (tweet, url) ' +
          'VALUES (?, ?)');
      await query.execute([id, url]);
    });
  } catch (e) {
    throw 'Error adding URLs: $e';
  }
}

/// Adds the URL [url] with display URL [displayUrl] to the database if it does
/// not exist already.
///
/// Throws an [Exception] if there is an error adding the URL to the database.
Future _addUrl(String url, String displayUrl) async {
  try {
    var results = await pool.query('SELECT COUNT(*) FROM url WHERE url = ' +
        '\'$url\'');

    // Adds URL to the database if it does not exist already.
    if ((await results.first).first == 0) {
      var query = await pool.prepare('INSERT INTO url (url, display_url) ' +
          'VALUES (?, ?)');
      await query.execute([url, displayUrl]);
    }
  } catch (e) {
    throw 'Error adding URL to database: $e';
  }
}

/// Adds all the photos URLs in [photos] to the database and associates them
/// with the Tweet with story ID [id].
///
/// Throws an [Exception] if there is an error adding the photos URLs.
Future _addPhotos(int id, List<String> photos) async {
  try {
    for (var photo in photos) {
      await _addPhoto(photo);
      var query = await pool.prepare('INSERT INTO tweet_photo (tweet, photo)' +
        'VALUES (?, ?)');
      await query.execute([id, photo]);
    }
  } catch (e) {
    throw 'Error adding photos: $e';
  }
}

/// Adds the photo URL [photo] to the database if it does not exist already.
///
/// Throws an [Exception] if there is an error adding the photo URL to the
/// database.
Future _addPhoto(String photo) async {
  try {
    var results = await pool.query('SELECT COUNT(*) FROM photo WHERE ' +
        'url = \'$photo\'');

    // Adds photo URL to the database if it does not exist already.
    if ((await results.first).first == 0) {
      var query = await pool.prepare('INSERT INTO photo (url) VALUES (?)');
      await query.execute([photo]);
    }
  } catch (e) {
    throw 'Error adding photo to database: $e';
  }
}

/// Returns a list containing new Tweets published by the user with screen name
/// [screenName]
///
/// Throws an [Exception] if the JSON contains errors.
/// Throws an [Exception] if there is an error retrieving Tweets from Twitter.
Future<List<Tweet>> _retrieveNewTweets(String screenName) async {
  print('Fetching Tweets by @$screenName...');

  var count = await _countTweets(screenName);
  var requestUrl = 'https://api.twitter.com/1.1/statuses/user_timeline.json' +
      '?screen_name=$screenName' +
      '&exclude_replies=true' +
      '&include_rts=false' +
      (count != null && count > 0
          ? '&since_id=${await _getNewestTweetId(screenName)}'
          : '&count=20');

  var tweets = new List<Tweet>();
  try {
    // Requests a list of Tweets in JSON from Twitter and parses them.
    tweets = await _parseTweets(await _makeRequest(requestUrl));
  } catch (e) {
    throw 'Error parsing Tweets: $e';
  }
  return tweets;
}

/// Returns a list of [Tweet] objects parsed from [json].
///
/// Throws an [Exception] if none of the specified users exist.
List<Tweet> _parseTweets(String json) {
  var content = JSON.decode(json);
  if (content is !List) {
    if (content['statuses'] != null) {
      content = content['statuses'];

    // Errors found in JSON contents.
    } else if (content['errors'] != null) {
      throw 'JSON contains errors.\n' + _getJsonErrors(content['errors']);
    } else {
      throw 'JSON has an unknown format.';
    }
  }
  var tweets = new List<Tweet>();
  for (var object in content) {
    tweets.add(new Tweet.parse(object));
  }
  return tweets;
}

/// Returns a String with a list of all the error messages in [json].
String _getJsonErrors(Object json) {
  String errors = 'Error messages in JSON contents:';
  for (var error in json) {
    errors += '\n- ${error['message']}';
  }
  return errors;
}

/// Returns the number of Tweets published by the user with screen name
/// [screnName] stored in the database.
///
/// Throws an [Exception] if there is an error retrieving the number of Tweets
/// from the database.
Future<int> _countTweets(String screenName) async {
  var row;
  try {
    var results = await pool.query('SELECT COUNT(*) FROM story WHERE ' +
        'LOWER(twitter_user) = \'${screenName.toLowerCase()}\'');
    row = await results.first;
  } catch (e) {
    'Error retrieving number of Tweets from database: $e';
  }
  return row.first;
}

/// Returns the ID of the newest Tweet published by the Twitter account with
/// screen name [screenName] and stored in the database, or null if no Tweets
/// were found.
///
/// Throws an [Exception] if there is an error retrieving the ID of the newest
/// Tweet published by the user with screen name [screenName] and stored in the
/// database.
Future<int> _getNewestTweetId(String screenName) async {
  int tweetId;
  try {
    if (await _countTweets(screenName) > 0) {
      tweetId = await _getTweetId(screenName, false);
    }
  } catch (e) {
    throw 'Error retrieving newest Tweet ID from database: $e';
  }
  return tweetId;
}

/// Returns the ID of the oldest Tweet published by the Twitter account with
/// screen name [screenName] and stored in the database, or null if no Tweets
/// were found.
///
/// Throws an [Exception] if there is an error retrieving the ID of the oldest
/// Tweet published by the user with screen name [screenName] and stored in the
/// database.
Future<int> _getOldestTweetId(String screenName) async {
  var tweetId;
  try {
    if (await _countTweets(screenName) > 0) {
      tweetId = await _getTweetId(screenName);
    }
  } catch (e) {
    throw 'Error retrieving oldest Tweet ID from database: $e';
  }
  return tweetId;
}

/// By default, returns the ID of the oldest Tweet published by the user with
/// screen name [screenName] and stored in the database, or null if no Tweets
/// were found. If instead [alphabetically] is set to false, returns the ID of
/// the newest Tweet stored in the database.
///
/// This function provides support to [_getNewestTweetIdByUser] and
/// [_getOldestTweetByUser] and should not be used directly. Instead, use the
/// aforementioned functions.
///
/// Rethrows any [Exception] if there is an error retrieving the Tweet ID from
/// the database.
Future<int> _getTweetId(String screenName, [bool alphabetically = true]) async {
  var id;
  var results = await pool.query('SELECT tweet_id FROM story WHERE ' +
      'LOWER(twitter_user) = \'${screenName.toLowerCase()}\' ORDER BY ' +
      'tweet_id ' + (alphabetically ? '' : 'DESC ') + 'LIMIT 1');
  var rows = await results.toSet();
  if (rows.length == 1) id = rows.first.first;
  return id;
}

/// Returns the ID of the story with Tweet ID [id].
///
/// Throws an [Exception] if there is an error retrieving story IDs from the
/// database.
Future<int> _getStoryId(int id) async {
  var storyId;
  try {
    var results = await pool.query('SELECT id FROM story WHERE tweet_id = $id');
    var rows = await results.toSet();
    if (rows.length == 1) storyId = rows.first.first;
  } catch (e) {
    throw 'Error retrieving story IDs from the database: $e';
  }
  return storyId;
}

/// Returns a list of [User] objects parsed from [json].
///
/// Non-existent users are ignored.
///
/// Throws an [Exception] if none of the specified users exist.
List<User> _parseUsers(String json) {
  var content = JSON.decode(json);

  // Errors found in JSON contents.
  if (content is !List && content['errors'] != null) {
    throw 'Unable to parse specified users.\n' +
        _getJsonErrors(content['errors']);
  }

  var users = new List<User>();
  for (var object in content) {
    try {
      users.add(new User.parse(object));
    } catch (e) {
      throw 'Error creating Twitter user from JSON: $e';
    }
  }
  return users;
}

/// Returns a list containing all the user screen names stored in the database.
///
/// Throws an [Exception] if there is an error retrieving screen names from the
/// database.
Future<List<String>> _getScreenNames() async {
  var screenNames = new List<String>();
  try {
    var results = await pool.query('SELECT screen_name FROM twitter_user');
    await results.forEach((row) => screenNames.add(row[0]));
  } catch (e) {
    throw 'Error retrieving user screen names from the database: $e';
  }
  return screenNames;
}

/// Returns the authorisation credentials issued by Twitter and stored in
/// 'twitter_keys.json'.
///
/// Throws a [FileSystemException] if there is an error reading the file
/// 'twitter_keys.json'.
String _getCredentials() {
  var twitterKeys = new File('../twitter_keys.json');
  var content;
  try {
    content = JSON.decode(twitterKeys.readAsStringSync());
  } on FileSystemException catch (e) {
    throw new FileSystemException('Error reading file: $e');
  }
  return '${content['consumer_key']}:${content['consumer_secret']}';
}

/// Requests an access token from Twitter, returns it and saves it to the file
/// 'access_token' for following requests.
///
/// Throws an [Exception] if there is an error making a Twitter request.
/// Throws an [Exception] if there is an error retrieving content from Twitter.
/// Throws an [Exception] if the content retrieved from Twitter is invalid.
/// Throws a [FileSystemException] if there is an error creating the
/// file 'access_token'.
Future<String> _generateAccessToken() async {
  var accessTokenFile = new File('../access_token');

  // Converts a list of bytes with the credentials to Base64.
  var credentials = CryptoUtils.bytesToBase64(UTF8.encode(_getCredentials()));

  // Requests an OAuth 2 Bearer Token from Twitter.
  var client = new HttpClient();
  var request = await client.postUrl(Uri
      .parse('https://api.twitter.com/oauth2/token'));

  // Includes the encoded consumer key and secret in the request headers.
  try {
    request.headers
      ..add('host', 'api.twitter.com')
      ..removeAll('user-agent')
      ..add('user-agent', 'News Anchor')
      ..add('authorization', 'Basic $credentials')
      ..contentType = new ContentType('application',
          'x-www-form-urlencoded', charset: 'utf-8')
      ..contentLength = 29;
    } catch (e) {
      throw 'Error adding Twitter request headers: $e';
    }

  request.write('grant_type=client_credentials');

  // Waits until the request is complete and closes the connection.
  var contents;
  try {
    var response = await request.close();
    contents = await response.transform(UTF8.decoder).join();
  } catch (e) {
    throw 'Error retrieving content from Twitter: $e';
  }
  client.close();

  // Decodes the response and throws an exception if the type is not 'bearer'.
  var json = JSON.decode(contents);
  if (json['token_type'] != 'bearer') {
    throw 'OAuth 2 Bearer Token type is not \'bearer\'.';
  }

  // Creates a file 'access_token' with the access token.
  var accessToken = json['access_token'];
  try {
    accessTokenFile
      ..createSync()
      ..writeAsStringSync(accessToken);
  } on FileSystemException catch (e) {
    throw new FileSystemException('Error creating file \'access_token\': $e');
  }

  return accessToken;
}

/// Returns the access token issued by Twitter and retrieved from the file
/// 'access_token'.
///
/// It generates the file with the access token if it does not exist already.
///
/// Throws an [Exception] if there is an error retrieving the access token.
Future<String> _getAccessToken() async {
  var accessToken;
  var file = new File('../access_token');
  try {
    accessToken = file.existsSync()
        ? file.readAsStringSync()
        : await _generateAccessToken();
  } catch (e) {
    throw 'Error retrieving access token: $e';
  }
  return accessToken;
}

/// Makes a request to the Twitter API with the query specified in the [url] and
/// returns the response as a String.
///
/// Throws an [Exception] if unable to retrieve the access token used in the
/// request headers.
/// Throws an [Exception] if there is an error retrieving content from Twitter.
Future<String> _makeRequest(String url) async {
  var client = new HttpClient();
  var request = await client.getUrl(Uri.parse(url));

  // Includes the access token in the request headers.
  try {
    request.headers
      ..add('host', 'api.twitter.com')
      ..removeAll('user-agent')
      ..add('user-agent', 'News Anchor')
      ..add('authorization', 'Bearer ${await _getAccessToken()}');
  } catch (e) {
    throw 'Error adding Twitter request headers: $e';
  }

  // Waits until the request is complete and closes the connection.
  var contents;
  try {
    var response = await request.close();
    contents = await response.transform(UTF8.decoder).join();
  } catch (e) {
    throw 'Error retrieving content from Twitter: $e';
  }
  client.close();

  return contents;
}

/// Adds the Twitter accounts with the screen names specified in the
/// comma-separated [screenNames] to the database. If a user already exists in
/// the database, that user is skipped.
///
/// Throws an [Exception] if there is an error requesting data from Twitter.
/// Throws an [Exception] if there is an error parsing the Twitter response.
/// Throws an [Exception] if there is an error adding users to the database.
Future _addUsers(String screenNames) async {
  var json, users;

  print('Adding users to database...');

  // Request data about the [screenNames] from Twitter.
  try {
    json = await _makeRequest('https://api.twitter.com/1.1/users/lookup.json' +
        '?screen_name=$screenNames');
  } catch (e) {
    throw 'Error requesting data from Twitter: $e';
  }

  try {
    users = _parseUsers(json);
  } catch (e) {
    throw 'Error parsing the Twitter response: $e';
  }

  try {
    var query = await pool.prepare('INSERT INTO twitter_user (screen_name, ' +
        'name, profile_image, location) VALUES (?, ?, ?, ?)');

    for (var user in users) {
      // Skips user if it already exists in the database.
      if (await _userExists(user.screenName)) {
        print('User @${user.screenName} already exists in the database.');
        continue;
      }

      await query.execute([user.screenName, user.name, user.profileImage,
          user.location]);

      print('Added user @${user.screenName}.');
    }
  } catch (e) {
    throw 'Error adding users to database: $e';
  }
}

/// Returns true if the Twitter account with the screen name [screenName]
/// already exists in the database.
///
/// Throws an [Exception] if there is an error retrieving users from the
/// database.
Future<bool> _userExists(String screenName) async {
  var row;
  try {
    var results = await pool.query('SELECT COUNT(*) FROM twitter_user WHERE ' +
        'LOWER(screen_name) = \'${screenName.toLowerCase()}\'');
    row = await results.first;
  } catch (e) {
    throw 'Error retrieving users from database: $e';
  }
  return row.first > 0;
}

/// Returns true if the Tweet with ID [id] already exists in the database.
///
/// Throws an [Exception] if there is an error retrieving users from the
/// database.
Future<bool> _tweetExists(int id) async {
  var row;
  try {
    var results = await pool.query('SELECT COUNT(*) FROM story WHERE ' +
        'tweet_id = $id');
    row = await results.first;
  } catch (e) {
    throw 'Error retrieving Tweets from database: $e';
  }
  return row.first > 0;
}

/// Returns a list of older Tweets published by the user with screen name
/// [screenName].
///
/// It retrieves the oldest Tweet published by the user and stored in the
/// database, and requests up to 20 Tweets older than the oldest Tweet stored in
/// the database. If there were no previous Tweets by the user, it returns up to
/// 20 of its newest Tweets.
///
/// Throws an [Exception] if there is an error retrieving Tweets from Twitter.
Future<List<Tweet>> _fetchOlderTweetsBy(String screenName) async {
  var tweets = new List<Tweet>();

  print('Fetching Tweets by @{screenName}...');

  try {
    var oldestTweetId = await _getOldestTweetId(screenName);
    var requestUrl = 'https://api.twitter.com/1.1/statuses/user_timeline.json' +
        '?screen_name=$screenName' +
        '&exclude_replies=true' +
        '&include_rts=false' +
        '&count=20' +
        (oldestTweetId > -1 ? '&max_id=${oldestTweetId - 1}' : '');

    // Retrieve older Tweets by user.
    tweets.addAll(_parseTweets(await _makeRequest(requestUrl)));
  } catch (e) {
    throw 'Error retrieving Tweets from Twitter: $e';
  }

  return tweets;
}
