CREATE TABLE twitter_user(
    screen_name VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    profile_image VARCHAR(500),
    location VARCHAR(255),
    PRIMARY KEY (screen_name),
    UNIQUE (screen_name)
);

CREATE TABLE topic(
    name VARCHAR(255) NOT NULL,
    PRIMARY KEY (name),
    UNIQUE (name)
);

CREATE TABLE blacklist(
    topic VARCHAR(255) NOT NULL,
    PRIMARY KEY (topic),
    UNIQUE (topic)
);

CREATE TABLE reaction(
    story VARCHAR(255) NOT NULL,
    type VARCHAR(10) NOT NULL,
    reaction VARCHAR(8) NOT NULL,
    PRIMARY KEY (story, type)
);

CREATE TABLE story(
    id INT NOT NULL AUTO_INCREMENT,
    type VARCHAR(10) NOT NULL,
    tweet_id BIGINT,
    google_news_id VARCHAR(255),
    title VARCHAR(255),
    publisher VARCHAR(255),
    twitter_user VARCHAR(255),
    date DATETIME NOT NULL,
    text VARCHAR(500) NOT NULL,
    url VARCHAR(500) NOT NULL,
    image_url VARCHAR(500),
    topic VARCHAR(255),
    PRIMARY KEY (id),
    UNIQUE (id, tweet_id, google_news_id),
    FOREIGN KEY (twitter_user) REFERENCES twitter_user(screen_name)
);

CREATE TABLE hashtag(
    name VARCHAR(255) NOT NULL,
    PRIMARY KEY (name),
    UNIQUE (name)
);

CREATE TABLE tweet_hashtag(
    tweet INT NOT NULL,
    hashtag VARCHAR(255) NOT NULL,
    PRIMARY KEY (tweet, hashtag),
    FOREIGN KEY (tweet) REFERENCES story(id),
    FOREIGN KEY (hashtag) REFERENCES hashtag(name)
);

CREATE TABLE url(
    url VARCHAR(255) NOT NULL,
    display_url VARCHAR(255) NOT NULL,
    PRIMARY KEY (url),
    UNIQUE (url)
);

CREATE TABLE tweet_url(
    tweet INT NOT NULL,
    url VARCHAR(255) NOT NULL,
    PRIMARY KEY (tweet, url),
    FOREIGN KEY (tweet) REFERENCES story(id),
    FOREIGN KEY (url) REFERENCES url(url)
);

CREATE TABLE photo(
    url VARCHAR(255) NOT NULL,
    PRIMARY KEY (url),
    UNIQUE (url)
);

CREATE TABLE tweet_photo(
    tweet INT NOT NULL,
    photo VARCHAR(255) NOT NULL,
    PRIMARY KEY (tweet, photo),
    FOREIGN KEY (tweet) REFERENCES story(id),
    FOREIGN KEY (photo) REFERENCES photo(url)
);
