import 'dart:async';
import 'google_news_server.dart';
import 'twitter_server.dart';

// Default frequency of updates set to 5 minutes.
const frequency = const Duration(minutes: 5);

/// Starts crawler and fetches new content every [frequency] minutes.
void main() {
  _fetchUpdates();
  new Timer.periodic(frequency, (timer) => _fetchUpdates());
}

/// Retrieves new content from Twitter and Google News and stores it in the
/// database.
Future _fetchUpdates() async {
  //Fetch updates from Twitter.
  try {
    await _fetchTwitterUpdates();
  } catch (e) {
    print('Error fetching Twitter updates: $e');
  }

  // Fetch updates from Google News.
  try {
    await _fetchGoogleNewsUpdates();
  } catch (e) {
    print('Error fetching Google News updates: $e');
  }

  var present = new DateTime.now();
  var minutes = present.minute;
  print('Completed at ${present.hour}:' +
      (minutes < 10 ? '0$minutes' : '$minutes') + '.\n');
  print('Next update in ${frequency.inMinutes} minutes...');
}

/// Returns a list containing the newest Tweets since the last update. If there
/// were no previous Tweets by a user, it returns up to 20 of its newest Tweets.
///
/// Rethrows an [Exception] if there is an error retrieving Tweets from Twitter.
Future _fetchTwitterUpdates() async {
  var tweets = await getTweets();
  if (tweets.length == 0) {
    print('No new stories.');
  } else {
    await addTweets(tweets);
  }
}

/// Retrieves new stories from Google News for all the topics stored in the
/// database and adds them to the database.
///
/// Rethrows an [Exception] if there is an error fetching updates from Google
/// News.
Future _fetchGoogleNewsUpdates() async {
  var stories = await getGoogleNewsStories();
  if (stories.length == 0) {
    print('No new stories.');
  } else {
    await addStories(stories);
  }
}
