Iznik.Views.ModTools.Pages.ApprovedMembers = Iznik.Views.Page.extend({
    modtools: true,
    search: false,
    context: null,
    members: null,

    template: "modtools_members_approved_main",

    events: {
        'click .js-search': 'search',
        'keyup .js-searchterm': 'keyup',
        'click .js-sync': 'sync',
        'click .js-export': 'export'
    },

    fetching: null,
    context: null,

    keyup: function(e) {
        // Search on enter.
        if (e.which == 13) {
            this.$('.js-search').click();
        }
    },

    sync: function() {
        (new Iznik.Views.Plugin.Yahoo.SyncMembers.Approved({model: Iznik.Session.getGroup(this.selected)})).render();
    },

    exportChunk: function() {
        // We don't use the collection fetch because we're not interested in maintaining a collection, and it chews up
        // a lot of memory.
        var self = this;
        $.ajax({
            type: 'GET',
            url: API + 'memberships/' + self.selected,
            context: self,
            data: {
                limit: 1000,
                context: self.exportContext ? self.exportContext : null
            },
            success: function(ret) {
                var self = this;
                self.exportContext = ret.context;

                if (ret.members.length > 0) {
                    // We returned some - add them to the list.
                    _.each(ret.members, function(member) {
                        var otheremails = [];
                        _.each(member.otheremails, function(email) {
                            otheremails.push(email.email);
                        });

                        self.exportList.push([
                            member.id,
                            member.displayname,
                            member.email,
                            member.joined,
                            member.role,
                            otheremails.join(', '),
                            JSON.stringify(member.settings,null,0)
                        ]);
                    });

                    self.exportChunk.call(self);
                } else {
                    // We got them all.
                    // Loop through converting each to CSV.
                    var csv = new csvWriter();
                    csv.del = ',';
                    csv.enc = '"';
                    var list = [ [ 'Unique ID', 'Display Name', 'Email on Group', 'Joined', 'Role on Group', 'Other emails', 'Settings on Group' ] ];

                    var csvstr = csv.arrayToCSV(self.exportList);

                    self.exportWait.close();
                    var blob = new Blob([ csvstr ], {type: "text/csv;charset=utf-8"});
                    saveAs(blob, "members.csv");
                }
            }
        })
    },

    export: function() {
        // Get all the members.  Slow.
        if (this.selected > 0) {
            var v = new Iznik.Views.PleaseWait({
                timeout: 1
            });
            v.template = 'modtools_members_approved_exportwait';
            v.render();
            this.exportWait = v;
            this.exportList = [];
            this.exportContext = null;
            this.exportChunk();
        }
    },

    fetch: function() {
        var self = this;

        self.$('.js-none').hide();

        var data = {
            context: self.context
        };

        if (self.selected > 0) {
            // Specific group
            data.groupid = self.selected;
        }

        // Fetch more members - and leave the old ones in the collection
        if (self.fetching == self.selected) {
            // Already fetching the right group.
            return;
        } else {
            self.fetching = self.selected;
        }

        var v = new Iznik.Views.PleaseWait();
        v.render();

        this.members.fetch({
            data: data,
            remove: self.selected != self.lastFetched
        }).then(function() {
            v.close();

            self.fetching = null;
            self.lastFetched = self.selected;
            self.context = self.members.ret.context;

            if (self.members.length > 0) {
                // Peek into the underlying response to see if it returned anything and therefore whether it is
                // worth asking for more if we scroll that far.
                var gotsome = self.members.ret.members.length > 0;

                // Waypoints allow us to see when we have scrolled to the bottom.
                if (self.lastWaypoint) {
                    self.lastWaypoint.destroy();
                }

                if (gotsome) {
                    // We got some different members, so set up a scroll handler.  If we didn't get any different
                    // members, then there's no point - we could keep hitting the server with more requests
                    // and not getting any.
                    self.context = self.members.ret.context;
                    var vm = self.collectionView.viewManager;
                    var lastView = vm.last();

                    if (lastView) {
                        self.lastMember = lastView;
                        self.lastWaypoint = new Waypoint({
                            element: lastView.el,
                            handler: function(direction) {
                                if (direction == 'down') {
                                    // We have scrolled to the last view.  Fetch more as long as we've not switched
                                    // away to another page.
                                    if (jQuery.contains(document.documentElement, lastView.el)) {
                                        self.fetch();
                                    }
                                }
                            },
                            offset: '99%' // Fire as soon as this view becomes visible
                        });
                    }
                }
            } else {
                self.$('.js-none').fadeIn('slow');
            }
        });
    },

    search: function() {
        var term = this.$('.js-searchterm').val();

        if (term != '') {
            Router.navigate('/modtools/members/approved/' + encodeURIComponent(term), true);
        } else {
            Router.navigate('/modtools/members/approved', true);
        }
    },

    render: function() {
        var self = this;

        Iznik.Views.Page.prototype.render.call(this);

        var v = new Iznik.Views.Help.Box();
        v.template = 'modtools_members_approved_help';
        this.$('.js-help').html(v.render().el);

        self.groupSelect = new Iznik.Views.Group.Select({
            systemWide: false,
            all: true,
            mod: true,
            counts: [ 'approvedmembers', 'approvedmembersother' ],
            id: 'approvedGroupSelect'
        });

        self.listenTo(self.groupSelect, 'selected', function(selected) {
            // Change the group selected.
            self.selected = selected;

            // We haven't fetched anything for this group yet.
            self.lastFetched = null;
            self.context = null;

            // The type of collection we're using depends on whether we're searching.  It controls how we fetch.
            if (self.options.search) {
                self.members = new Iznik.Collections.Members.Search(null, {
                    groupid: self.selected,
                    group: Iznik.Session.get('groups').get(self.selected),
                    collection: 'Approved',
                    search: self.options.search
                });

                self.$('.js-searchterm').val(self.options.search);
            } else {
                self.members = new Iznik.Collections.Members(null, {
                    groupid: self.selected,
                    group: Iznik.Session.get('groups').get(self.selected),
                    collection: 'Approved'
                });
            }

            // CollectionView handles adding/removing/sorting for us.
            self.collectionView = new Backbone.CollectionView( {
                el : self.$('.js-list'),
                modelView : Iznik.Views.ModTools.Member.Approved,
                modelViewOptions: {
                    collection: self.members,
                    page: self
                },
                collection: self.members
            } );

            self.collectionView.render();

            // Do so.
            self.fetch();
        });

        // Render after the listen to as they are called during render.
        self.$('.js-groupselect').html(self.groupSelect.render().el);

        // If we detect that the pending counts have changed on the server, refetch the members so that we add/remove
        // appropriately.
        this.listenTo(Iznik.Session, 'approvedmemberscountschanged', _.bind(this.fetch, this));
        this.listenTo(Iznik.Session, 'approvedmemberscountschanged', _.bind(this.groupSelect.render, this.groupSelect));
        this.listenTo(Iznik.Session, 'approvedmembersothercountschanged', _.bind(this.groupSelect.render, this.groupSelect));

        // We seem to need to redelegate
        self.delegateEvents();
    }
});

Iznik.Views.ModTools.Member.Approved = Iznik.Views.ModTools.Member.extend({
    template: 'modtools_members_approved_member',

    events: {
        'click .js-rarelyused': 'rarelyUsed'
    },

    render: function() {
        var self = this;

        self.$el.html(window.template(self.template)(self.model.toJSON2()));
        var mom = new moment(this.model.get('joined'));
        this.$('.js-joined').html(mom.format('llll'));

        self.addOtherEmails();

        // Get the group from the collection.
        var group = self.model.collection.options.group;

        // Our user
        var v = new Iznik.Views.ModTools.User({
            model: self.model
        });

        self.$('.js-user').html(v.render().el);

        // Delay getting the Yahoo info slightly to improve apparent render speed.
        _.delay(function() {
            // The Yahoo part of the user
            var mod = IznikYahooUsers.findUser({
                email: self.model.get('email'),
                group: group.get('nameshort'),
                groupid: group.get('id')
            });

            mod.fetch().then(function() {
                // We don't want to show the Yahoo joined date because we have our own.
                mod.clear('date');
                var v = new Iznik.Views.ModTools.Yahoo.User({
                    model: mod
                });
                self.$('.js-yahoo').append(v.render().el);
            });
        }, 200);

        // Add the default standard actions.
        var configs = Iznik.Session.get('configs');
        var sessgroup = Iznik.Session.get('groups').get(group.id);
        var config = configs.get(sessgroup.get('configid'));

        // Save off the groups in the member ready for the standard message
        // TODO Hacky.  Should we split the StdMessage.Button code into one for members and one for messages?
        self.model.set('groups', [ group.attributes ]);
        self.model.set('fromname', self.model.get('displayname'));
        self.model.set('fromaddr', self.model.get('email'));
        self.model.set('fromuser', self.model);

        self.$('.js-stdmsgs').append(new Iznik.Views.ModTools.StdMessage.Button({
            model: new IznikModel({
                title: 'Mail',
                action: 'Leave Approved Member',
                member: self.model,
                config: config
            })
        }).render().el);

        if (config) {
            // Add the other standard messages, in the order requested.
            var sortmsgs = orderedMessages(config.get('stdmsgs'), config.get('messageorder'));
            var anyrare = false;

            _.each(sortmsgs, function (stdmsg) {
                if (_.contains(['Leave Approved Member', 'Delete Approved Member'], stdmsg.action)) {
                    stdmsg.groups = [ group ];
                    stdmsg.member = self.model;
                    var v = new Iznik.Views.ModTools.StdMessage.Button({
                        model: new IznikModel(stdmsg),
                        config: config
                    });

                    var el = v.render().el;
                    self.$('.js-stdmsgs').append(el);

                    if (stdmsg.rarelyused) {
                        anyrare = true;
                        $(el).hide();
                    }
                }
            });

            if (!anyrare) {
                self.$('.js-rarelyholder').hide();
            }
        }

        this.$('.timeago').timeago();

        // If we delete this member then the view should go.
        this.listenToOnce(self.model, 'removed', function() {
            self.$el.fadeOut('slow', function() {
                self.remove();
            });
        });

        return(this);
    }
});

