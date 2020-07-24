import 'dart:html';

/// Redirects to an external website.
void main () {
  // Retrieves the URI parameters.
  var url = Uri.base.queryParameters['url'];

  querySelector('#redirect').children
    // Add spinner.
    ..add(new Element.tag('paper-spinner')
      ..setAttribute('id', 'spinner')
      ..setAttribute('active', 'true')
      ..setAttribute('alt', 'Redirecting'))

    // Add redirection message.
    ..add(new Element.div()
      ..setAttribute('id', 'message')
      ..text = 'You are being redirected...')

    // Add button.
    ..add(new Element.a()
      ..setAttribute('href', url)
      ..children.add(new Element.tag('paper-button')
        ..setAttribute('id', 'button')
        ..text = 'Go to website'));

  // Redirects to URL.
  window.location.href = url;
}
