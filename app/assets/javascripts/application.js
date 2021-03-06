// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require rails-ujs
//= require activestorage
//= require jquery.cookie
//= require placeholder
//= require fastclick
//= require modernizr
//= require foundation.min
//= require jquery.slugit
//= require checkbox
//= require direct_uploads
//= require extensionShow
//= require extensionFollowing
//= require joinOrganization
//= require organizationRoles
//= require announcementBanner
//= require flash
//= require select2-full
//= require collaborators
//= require extensionDeprecate
//= require extensionInstallTabs
//= require organizations
//= require tools
//= require searchToggle
//= require vendor/bootstrap-tokenfield
//= require vendor/twitter-typeahead
//= require vendor/twitter-bloodhound

// Hack to resolve bug with Foundation. Resolved in master
// here: https://github.com/zurb/foundation/issues/4684 so
// this can go away when Foundation 5.2.3 is released.
Foundation.global.namespace = '';

$(function(){
  $(document).foundation();

  // Ensure client side validation isn't stronger
  // than serverside validation.
  jQuery.extend(window.Foundation.libs.abide.settings.patterns, {
    'password': /[a-zA-Z]+/,
  });

  // Autocomplete

  jQuery(".tokenfield").each(function(i, e) {
    var el = jQuery(e);
    var values = el.data("autofill");

    var engine = new Bloodhound({
      local: values,
      datumTokenizer: function(d) { return d.split(","); },
      queryTokenizer: function(v) { return v.split(",") }
    });

    engine.initialize();

    el.tokenfield({
      createTokensOnBlur: true,
      typeahead:          [null, {source: engine.ttAdapter()}]
    });
  });

  jQuery(".autofill").each(function(i, e) {
    var el = jQuery(e);
    var values = el.data("autofill");

    var engine = new Bloodhound({
      local: values,
      datumTokenizer: function(d) { return d.split(","); },
      queryTokenizer: function(v) { return v.split(",") }
    });

    engine.initialize();

    el.typeahead(null, { source: engine.ttAdapter() });
  });

  var tagEngine = new Bloodhound({
    datumTokenizer: function(d) { return [d]; },
    queryTokenizer: function(v) { return [v]; },
    identify: function(d) { return v; },
    remote: {
      url: "/api/v1/tags?q=%QUERY",
      wildcard: "%QUERY"
    },
  });

  tagEngine.initialize();

  jQuery(".extension_search_textfield").typeahead(null, { source: tagEngine.ttAdapter() });


  // Advanced search options

  jQuery("#advanced-search-toggle").click(function() {
    $("#advanced-search").slideToggle();
  });
});


