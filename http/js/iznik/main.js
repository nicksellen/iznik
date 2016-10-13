var API = 'https://www.ilovefreegle.org/api/'; // CC
var YAHOOAPI = 'https://groups.yahoo.com/api/v1/';
var YAHOOAPIv2 = 'https://groups.yahoo.com/api/v2/';

var isiOS = false; // CC
var initialURL = false;
var hammertime = false;

function panicReload() {
    // This is used when we fear something has gone wrong with our fetching of the code, and want to bomb out and
    // reload from scratch.
    console.error("Panic and reload");
    /* try { // CC
        // If we have a service worker, tell it to clear its cache in case we have bad scripts.
        navigator.serviceWorker.controller.postMessage({
            type: 'clearcache'
        });
    } catch (e) {}

    window.setTimeout(function() {
        window.location.reload();
    }, 1000);*/
}

requirejs.onError = function (err) {
    console.log("Require Error", err);
    alert("Require Error " + err);
    var mods = err.requireModules;
    var msg = err.message;
    if (msg && msg.indexOf('showFirst') !== -1) {
        // TODO There's something weird about this plugin which means it sometimes doesn't load.  Ignore this until
        // we replace it.
        console.log("showFirst error - ignore for now");
    } else if (mods && mods.length == 1 && mods[0] === "ga") {
        // Analytics can be blocked by privacy tools.
        console.log("Analytics - ignore");
    } else {
        // Any require errors are most likely either due to flaky networks (so we should retry), bad code (which we'll
        // surely fix very soon now), or Service Worker issues with registering a new one while a fetch is outstanding.
        //
        // In all cases, reloading the page will help.  Delay slightly to avoid hammering the server.
        console.error("One we care about");
        panicReload();
    }
};

// Global error catcher so that we log to the server.
window.onerror = function(message, file, line) {
	console.error(message, file, line);
	/*$.ajax({
		url: API + 'error',
		type: 'PUT',
		data: {
			'errortype': 'Exception',
			'errortext': message + ' in ' + file + ' line ' + line
		}
	});*/
};

function mobileRefresh() {
    var repeat = $('#refresh span');
    repeat.addClass("no-before");
    var spinner = $("<img src='" + iznikroot+"images/pageloader.gif' style='height:14px;' />");
    $(repeat).html(spinner);
    Backbone.history.loadUrl();
    return false;
}

// Called when app starts - and when it restarts when Router.mobileReload() called

function mainOnAppStart() { // CC
console.log("main boot");	// CC
isiOS = (window.device.platform === 'iOS'); // CC
if (!initialURL) {
    initialURL = window.location.href;
}

require([
    'jquery',
    'underscore',
    'backbone',
    'iznik/router',
    'hammer'   // CC
], function($, _, Backbone) {
    console.log("starting Backbone");	// CC
	  if (!Backbone) {
        // Something has gone unpleasantly wrong.
        console.error("Backbone failed to fetch");
        panicReload();
    }

      // http://hammerjs.github.io/getting-started/
	  hammertime = new Hammer(window);

	  if (isiOS) {  // vertical swipe on iOS stops scrolling
	      //hammertime.get('swipe').set({ direction: Hammer.DIRECTION_HORIZONTAL });
	  } else {
	      //hammertime.get('swipe').set({ direction: Hammer.DIRECTION_ALL });
	      hammertime.get('swipe').set({ direction: Hammer.DIRECTION_VERTICAL });
      }
	  hammertime.on('swipedown', function (ev) {
	      //console.log(ev);
	      var posn = $(window).scrollTop();
	      //console.log("posn=" + posn);
	      //$('.navbar-title').text("D " + ev.deltaY + " " + posn);
	      if (posn === 0) {
	          mobileRefresh();
	      }
	  });
	  /*hammertime.on('swipeleft swiperight', function (ev) {
	      console.log(ev);
	      $('.navbar-title').text("LR " + ev.deltaX + " " + ev.direction);
	  });*/

      // Catch back button and clear chats
	  window.addEventListener('popstate', function (e) {    // CC
	      try {
	          var ChatHolder = new Iznik.Views.Chat.Holder();
	          ChatHolder.minimiseall();
	      } catch (e) { }
	  });

    Backbone.emulateJSON = true;
    
    // We have a busy indicator.
    $(document).ajaxStop(function () {
        $('#spinner').hide();

        // We might have added a class to indicate that we were waiting for an AJAX call to complete.
        $('.showclicked').removeClass('showclicked');
    });

    $(document).ajaxStart(function () {
        $('#spinner').show();
    });

    // We want to retry AJAX requests automatically, because we might have a flaky network.  This also covers us for
    // Backbone fetches.
    var _ajax = $.ajax;

    function sliceArgs() {
        return(Array.prototype.slice.call(arguments, 0));
    }

    function delay(errors) {
        // Exponential backoff upto a limit.
        return(Math.min(Math.pow(2, errors) * 1000, 30000));
    }

    function retryIt(jqXHR) {
        var self = this;
        this.errors = this.errors === undefined ? 0 : this.errors + 1;
        var thedelay = delay(this.errors);
        console.log("retryIt", thedelay, this, arguments);
        // CC setTimeout(function () {
        // CC    $.ajax(self);
        // CC }, thedelay);
    }

    function extendIt(args, options) {
        _.extend(args[0], options && typeof options === 'object' ? options : {}, {
            error:   function () { retryIt.apply(this, arguments); }
        });
    }
    
    $.ajax = function (options) {
        var url = options.url;

        // There are some cases we don't want to subject to automatic retrying:
        // - Yahoo can validly return errors as part of its API, and we handle retrying via the plugin work.
        // - Where the context is set to a different object, we'd need to figure out how to implement the retry.
        // - File uploads, because we might have cancelled it.
        if (!options.hasOwnProperty('context') && url && url.indexOf('groups.yahoo.com') == -1 && url != API + 'upload') {
            // We wrap the AJAX call in our own, with our own error handler.
            var args;
            if (typeof options === 'string') {
                arguments[1].url = options;
                args = sliceArgs(arguments[1]);
            } else {
                args = sliceArgs(arguments);
            }

            extendIt(args, options);

            return _ajax.apply($, args);
        } else {
            return(_ajax.apply($, arguments));
        }
    };
});

}; // CC
