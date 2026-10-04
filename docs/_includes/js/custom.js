// Appended to just-the-docs.js, so it runs on the landing page and the inner pages.

jtd.onReady(function () {
  var header = document.getElementById('main-header');
  var menuButton = document.getElementById('menu-button');
  var searchInput = document.getElementById('search-input');

  // Header menu on narrow screens. With a sidebar nav just-the-docs toggles
  // #main-header itself; without one (the landing page) this does.
  if (header && menuButton) {
    var hasSiteNav = !!document.getElementById('site-nav');
    jtd.addEvent(menuButton, 'click', function (e) {
      if (!hasSiteNav) {
        e.preventDefault();
        header.classList.toggle('nav-open');
      }
      menuButton.setAttribute('aria-expanded', header.classList.contains('nav-open'));
    });
  }

  // "/" focuses the search, opening the header menu first when the search is folded into it.
  if (searchInput) {
    jtd.addEvent(document, 'keydown', function (e) {
      if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
      var target = e.target;
      if (target.closest && target.closest('input, textarea, select, [contenteditable]')) return;
      e.preventDefault();
      if (searchInput.offsetParent === null && menuButton) menuButton.click();
      searchInput.focus();
    });
  }

  // External links, including those in Markdown content, open in a new tab.
  var links = document.querySelectorAll('a[href]');
  for (var i = 0; i < links.length; i++) {
    var link = links[i];
    if (link.hostname && link.hostname !== window.location.hostname) {
      link.target = '_blank';
      link.relList.add('noopener');
    }
  }

  // Copy buttons next to the commands on the landing page.
  var copyButtons = document.querySelectorAll('.copy-button');
  for (var j = 0; j < copyButtons.length; j++) {
    jtd.addEvent(copyButtons[j], 'click', function (e) {
      var button = e.currentTarget;
      var code = button.previousElementSibling;
      navigator.clipboard.writeText(code.textContent).then(function () {
        button.textContent = 'copied';
        setTimeout(function () { button.textContent = 'copy'; }, 1500);
      }, function () {
        window.getSelection().selectAllChildren(code);
      });
    });
  }
});
