Iznik.Views.Infinite = IznikView.extend({
    context: null,
    fetching: null,

    fetch: function() {
        var self = this;

        self.$('.js-loading').removeClass('hidden');
        self.$('.js-none').hide();

        var data = {
            context: self.context
        };

        if (!self.context) {
            // We're at the top.
            $('.js-scrolltop').addClass('hidden');
        }

        if (self.selected > 0) {
            // Specific group
            data.groupid = self.selected;
        }

        // Fetch more - and leave the old ones in the collection
        if (self.fetching == self.selected) {
            // Already fetching the right group.
            return;
        } else {
            self.fetching = self.selected;
        }

        var v = new Iznik.Views.PleaseWait();
        v.render();

        self.collectionView.on('add', function(modelView) {
            self.$('.js-none').hide();

            var pos = modelView.collection.indexOf(modelView.model);
            //console.log("Added", pos, modelView.collection.length);

            if (pos + 1 == modelView.collection.length) {
                // This is the last one.
                //console.log("Last one", modelView.el, jQuery.contains(document.documentElement, modelView.el));

                // Waypoints allow us to see when we have scrolled to the bottom.
                if (self.lastWaypoint) {
                    //console.log("Destroy last");
                    self.lastWaypoint.destroy();
                }

                self.lastWaypoint = new Waypoint({
                    element: modelView.el,
                    handler: function(direction) {
                        //console.log("Scrolled to");
                        if (direction == 'down') {
                            $('.js-scrolltop').removeClass('hidden');
                            $('.js-scrolltop').click(function() {
                                $('html,body').animate({scrollTop:0},'slow', function() {
                                    $('.scrolltop').addClass('hidden');
                                });
                            });

                            // We have scrolled to the last view.  Fetch more as long as we've not switched
                            // away to another page.
                            if (jQuery.contains(document.documentElement, modelView.el)) {
                                //console.log("Fetch");
                                self.fetch();
                            }
                        }
                    },
                    offset: '99%' // Fire as soon as this view becomes visible
                });
            }
        });

        self.collectionView.on('remove', function() {
            if (self.collectionView.collection.length == 0) {
                self.$('.js-none').fadeIn('slow');
                $('.js-scrolltop').addClass('hidden');
            }
        });

        this.collection.fetch({
            data: data,
            remove: self.selected != self.lastFetched,
            success: function(collection, response, options) {
                v.close();

                self.$('.js-loading').addClass('hidden');
                self.fetching = null;
                self.lastFetched = self.selected;
                self.context = response.context;

                //console.log("Fetched length", collection.length);
                if (collection.length == 0) {
                    self.$('.js-none').fadeIn('slow');
                } else {
                    self.$('.js-none').hide();
                }
            }
        });
    }
});

$(document).ready(function() {
    // We add informatin dynamically after the render, and this messes up waypoints, so we need to regularly
    // tell them to sort themselves out.
    window.setInterval(Waypoint.refreshAll, 1000);
})
