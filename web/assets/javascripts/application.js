$(function() {
  $.timeago.settings.allowFuture = true;
  $.timeago.settings.refreshMillis = 0;
  $("time").timeago();
});

$(function() {
  $('.check_all').live('click', function() {
    var checked = $(this).attr('checked');
    if (checked == 'checked') {
      $('input[type=checkbox]', $(this).closest('table')).attr('checked', checked);
    } else {
      $('input[type=checkbox]', $(this).closest('table')).removeAttr('checked');
    }
  });
});

$(function() {
  function pad(n) { return ('0' + n).slice(-2); }

  $('a[name=poll]').data('polling', false);

  var pollStatus = $('.poll-status');

  var pollStatusText = pollStatus.find('.text');
  var pollStatusBadge = pollStatus.find('.badge');
  pollStatusBadge.hide();
  var pollStatusMarkup = pollStatus.html();

  $('a[name=poll]').on('click', function(e) {
    e.preventDefault();

    var pollLink = $(this);

    if (pollLink.data('polling')) {

      $(this).removeClass('active');

      clearInterval(pollLink.data('interval'));
      pollLink.text(pollLink.data('text'));

      pollStatus.html(pollStatusMarkup);
      pollStatusBadge.hide();

    } else {

      $(this).addClass('active');

      var href = pollLink.attr('href');

      pollLink.data('text', pollLink.text());
      pollLink.text('Stop Polling');
      pollLink.data('interval', setInterval(function(){
        livePoll(href);
      }, 2000));

      pollStatusText.text('Starting to poll...');
    }

    pollLink.data('polling', !pollLink.data('polling'));

  });

  livePoll = function livePoll(href){
    $.get(href, function(data) {
      var responseHtml = $(data);
      $('.summary').replaceWith(responseHtml.find('.summary'));
      $('.status').html(responseHtml.find('.status').html().toString());
      $('.workers').replaceWith(responseHtml.find('.workers'));
      $('.queues').replaceWith(responseHtml.find('.queues'));
      $('time').timeago();
    });
    var currentTime = new Date();
    $('.poll-status .text').text('Last polled: ');
    $('.poll-status .time').show().text(currentTime.getHours() + ':' + pad(currentTime.getMinutes()) + ':' + pad(currentTime.getSeconds()));
  };
});

$(function() {
  $(document).on("click", "[data-confirm]", function() {
    return confirm($(this).attr('data-confirm'));
  });
});
