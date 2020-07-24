# MSc Project

For my MSc Project, I developed a mobile-friendly Web application, News Anchor,
which aggregates and curates news articles from Google News and Twitter. News
Anchor uses the [Dart programming language](https://dart.dev) on both the back
end and front end, and a MySQL database. Some features include news article
reactions and a topics blacklist. Further documentation of the technical
architecture can be found in the [MSc Project Report](msc_project_report.pdf).

## Specification (Year 2014)

**Project Title as submitted**: News Aggregation and Content Curation (Digital
Ecosystems Ltd)

### Background and motivation

Currently, there are applications and services that use the device's location to
personalise news content, e.g. Google News. Content personalisation such as
topic and sources - be it news websites, magazines, blogs and social networks -
selection is also possible. Some services (e.g. Google Newsstand, Digg Reader
and Feedly) even allow adding RSS feeds to the content sources, which allows an
even more personal and broader content selection. Some of these services allow
different types of media content to be displayed, e.g. videos, but they usually
do not handle audio content very well, for example to allow the user to listen
to podcasts. The main problem, however, is the combination of all these
features, and many others, into a single application, and making it available on
all platforms, either on the Web or mobile devices.

### Project aims

The project aims to provide a Web application that allows the user to
personalise the content and the sources of the content he/she wants to view, and
how it is displayed and/or provided. This includes content based on the user's
location, his/her interests, finding content that is similar to the user's
interests and based on what has been previously viewed, content shared on social
networks by the user's friends, and being able to filter and better manage the
news sources and content displayed.

### Requirements (function & non-functional)

The system should allow the creation of user accounts that contain the user
preferences, such as the topics he/she is interested in and the sources from
where the content is retrieved. The content should be updated automatically at
regular times (to be defined). The user will be able to select his/her own
personal topics, and select from a list of common sources (e.g. BBC, The
Telegraph, etc.), as well as add his/her own sources among websites, blogs, etc.
which contain an RSS feed. This may include several types of media, from text to
images, to video, to audio.

The user should be able to filter and select which content he/she wished to
view. This could include a selection filtered by topic, source or both.

The system should detect the user's location if allowed by him/her, or allow the
user to manually set one or more locations. This is useful when the user is
travelling and wants to keep updated with his/her country's news, as well as the
local news in the foreign country where he/she is staying.

The system should display content shared by the user's friends on social
networks that have been linked to the application, and he/she should be able to
share content with his/her friends as well. The user should be able to decide
which content is shared, and with whom it is shared and where.

The system should be able to save/bookmark articles that the user wishes to read
later, and they should be cashed in order to be accessed even when offline.

The system should allow the user to create alerts/notifications for specific
topics or sources which should be sent (e.g. via email) at certain periods of
time as defined by the user, for example as they happen, once a day, once every
week, etc.

The content should be adapted to the user's device, and all content and features
should be accessible seamlessly across all devices.

### Proposed novelty/value-add

By the end of the project, my Web application should bring a seamless experience
across all devices that incorporates many of the currently existent features
into a single service, allowing the user to have a better management and
personalisation of the sources and news contents he/she wishes to view, how
he/she desires to share the content with friends and view his/her friends'
shared content, being able to receive alerts/notifications for specific topics
and/or sources, and save content that can be viewed later even when the device
is not connected to the Internet.

### Methodology/framework

In order to achieve my project aims, I will:

1. Research what external sources suitable for the application are available,
   and ways of extracting data from them.
2. Consider which are the best tools and programming languages to use for the
   development of the application.
3. Learn more about Web development, including browser cookies and cache.
4. Consider ways of implementing user accounts and storing data.
5. Select the main, fundamental functions that ought to be supported by the
   application.
6. Develop an early working prototype so that I can collect feedback from users
   and consider what features they would like the application to support.
7. Adopt an iterative and incremental model of development of the application,
   and improve the application based on iterative feedback and testing.

I still do not know which, if any, methods will be extended and/or reused.

I will be using an iterative and incremental development. This model has four
main steps followed iteratively before deployment:

1. Requirements and planning
2. Analysis and design followed by implementation
3. Testing
4. Evaluation

### Expected outcomes & project milestones

Throughout the development of this project, I plan on releasing several working
pieces of software, as well as reports with details of the development of the
application.

(Please find Gantt chart at the end of this document.)

By the end of the project I expect to have a fully-functional Web application
that works across all devices, that is more customisable than most of the
services that exist today, more interactive, informative and more enjoyable to
use. In terms of personal achievements, and as I wish to be a Web developer
professionally, I expect to have acquired many skills which are currently being
used in the industry, and which will be useful for my future career.

### Required skills/tools/resources

For this project I will need skills in Web development using HTML5, CSS and
another language such as Dart (in this case I will need to learn more about the
language), JavaScript or PHP, as well as a database (possibly). I will also need
a better understanding of how browser cookies and cache work (for making content
available offline). Furthermore, I will need to fetch content from external
sources, be it Google News, RSS feeds or Web crawling.

In terms of software, I will need a text editor and/or an IDE, a Dart compiler
or a Dart-to-JavaScript translator (in case I use Dart), a modern Web browser
and a DBMS (probably online). In terms of hardware, I will need a regular
computer connected to the Internet as well as mobile devices for testing,
although most testing and simulation can be performed on the Web browser, for
example using the Chrome Developer Tools or similar tools.
