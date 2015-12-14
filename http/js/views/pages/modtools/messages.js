Iznik.Views.ModTools.Message = IznikView.extend({
    rarelyUsed: function() {
        this.$('.js-rarelyused').fadeOut('slow');
        this.$('.js-stdmsgs li').fadeIn('slow');
    },

    restoreEditSubject: function() {
        var self = this;
        window.setTimeout(function() {
            self.$('.js-savesubj .glyphicon').removeClass('glyphicon-ok glyphicon-warning-sign error success').addClass('glyphicon-floppy-save');
        }, 5000);
    },

    saveSubject: function() {
        var self = this;
        self.listenToOnce(self.model,'editfailed', function() {
            console.log("Show failure");
            self.$('.js-savesubj .glyphicon').removeClass('glyphicon-refresh rotate').addClass('glyphicon-warning-sign error');
            self.restoreEditSubject();
        });

        self.listenToOnce(self.model,'editsucceeded', function() {
            console.log("Show success");
            self.$('.js-savesubj .glyphicon').removeClass('glyphicon-refresh rotate').addClass('glyphicon-ok success');
            self.restoreEditSubject();
        });

        self.$('.js-savesubj .glyphicon').removeClass('glyphicon-floppy-save').addClass('glyphicon-refresh rotate');

        self.model.edit(
            self.$('.js-subject').val(),
            self.model.get('textbody'),
            self.model.get('htmlbody')
        );
    },

    viewSource: function(e) {
        e.preventDefault();
        e.stopPropagation();

        var v = new Iznik.Views.ModTools.Message.ViewSource({
            model: this.model
        });
        v.render();
    },

    checkDuplicates: function() {
        var self = this;
        var id = self.model.get('id');
        var subj = canonSubj(self.model.get('subject'));
        var dups = [];

        _.each(self.model.get('fromuser').messagehistory, function(message) {
            if (message.id != id) {
                if (canonSubj(message.subject) == subj) {
                    // No point displaying any group tag in the duplicate.
                    message.subject = message.subject.replace(/\[.*\](.*)/, "$1");

                    var v = new Iznik.Views.ModTools.Message.Duplicate({
                        model: new IznikModel(message)
                    });
                    self.$('.js-duplist').append(v.render().el);

                    dups.push(message);
                }
            }
        });

        self.model.set('duplicates', dups);
    },

    checkMessage: function(config) {
        var self = this;

        this.checkDuplicates();

        // We colour code subjects according to a regular expression in the config.
        this.$('.js-coloursubj').addClass('success');

        if (config.get('coloursubj')) {
            var subjreg = config.get('subjreg');

            if (subjreg) {
                var re = new RegExp(subjreg);

                if (!re.test(this.model.get('subject'))) {
                    this.$('.js-coloursubj').removeClass('success').addClass('error');
                }
            }
        }
    },

    showRelated: function() {
        var self = this;

        _.each(self.model.get('related'), function(related) {
            // No point displaying any group tag in the duplicate.
            related.subject = related.subject.replace(/\[.*\](.*)/, "$1");

            var v = new Iznik.Views.ModTools.Message.Related({
                model: new IznikModel(related)
            });
            self.$('.js-relatedlist').append(v.render().el);
        });
    }
});

Iznik.Views.ModTools.Message.Photo = IznikView.extend({
    tagName: 'li',

    template: 'modtools_message_photo',

    events: {
        'click .js-img': 'click'
    },

    click: function(e) {
        e.preventDefault();
        e.stopPropagation();

        var v = new Iznik.Views.Modal({
            model: this.model
        });

        v.open('modtools_message_photozoom');
    }
});

Iznik.Views.ModTools.StdMessage.Modal = Iznik.Views.Modal.extend({
    recentDays: 31,

    keywordList: ['Offer', 'Taken', 'Wanted', 'Received', 'Other'],

    expand: function() {
        this.$el.html(window.template(this.template)(this.model.toJSON2()));

        // Apply standard message settings
        var stdmsg = this.options.stdmsg.attributes;
        var config = this.options.config ? this.options.config.attributes : null;

        var subj = this.model.get('subject');

        // Expand substitution strings in subject
        subj = this.substitutionStrings(subj, this.model.attributes, config, this.model.get('groups')[0])

        this.$('.js-subject').val((stdmsg.subjpref ? stdmsg.subjpref : 'Re') +
        ': ' + subj +
        (stdmsg.subjsuff ? stdmsg.subjsuff : ''));

        this.$('.js-myname').html(Iznik.Session.get('me').displayname);

        // Quote original message.
        var msg = this.model.get('textbody');
        msg = '> ' + msg.replace(/((\r\n)|\r|\n)/gm, '\n> ');

        // Add text
        msg = (stdmsg.body ? (stdmsg.body + '\n\n') : '') + msg;

        // Expand substitution strings in body
        msg = this.substitutionStrings(msg, this.model.attributes, config, this.model.get('groups')[0]);

        // Put it in
        this.$('.js-text').val(msg);

        this.open(null);
        $('.modal').on('shown.bs.modal', function () {
            $('.modal .js-text').focus();
        });
    },

    substitutionStrings: function(text, message, config, group) {
        var self = this;

        if (config) {
            text = text.replace(/\$networkname/g, config.network);
            text = text.replace(/\$groupnonetwork/g, group.nameshort.replace(config.network, ''));
        }

        text = text.replace(/\$groupname/g, group.nameshort);
        text = text.replace(/\$owneremail/g, group.nameshort + "-owner@yahoogroups.com");
        text = text.replace(/\$groupemail/g, group.nameshort + "@yahoogroups.com");
        text = text.replace(/\$groupurl/g, "https://groups.yahoo.com/neo/groups/" + group.nameshort + "/info");
        text = text.replace(/\$myname/g, Iznik.Session.get('me').displayname);
        text = text.replace(/\$nummembers/g, group.membercount);
        text = text.replace(/\$nummods/g, group.nummods);

        text = text.replace(/\$origsubj/g, message.subject);

        var history = message.fromuser.messagehistory;
        var recentmsg = '';
        var count = 0;
        _.each(history, function(msg) {
            if (msg.daysago < self.recentDays) {
                recentmsg += moment(msg.date).format('lll') + ' - ' + msg.subject + "\n";
                count++;
            }
        })
        text = text.replace(/\$recentmsg/gim, recentmsg);
        text = text.replace(/\$numrecentmsg/gim, count);

        _.each(this.keywordList, function(keyword) {
            var recentmsg = '';
            var count = 0;
            _.each(history, function(msg) {
                if (msg.type == keyword && msg.daysago < self.recentDays) {
                    recentmsg += moment(msg.date).format('lll') + ' - ' + msg.subject + "\n";
                    count++;
                }
            })

            text = text.replace(new RegExp('\\$recent' + keyword.toLowerCase(), 'gim'),recentmsg);
            text = text.replace(new RegExp('\\$numrecent' + keyword.toLowerCase(), 'gim'), count);
        });

        //if (message.hasOwnProperty('comment')) {
        //    text = text.replace(/\$memberreason/g, message['comment'].trim());
        // TODO }

        // TODO $otherapplied

        text = text.replace(/\$membermail/g, message.fromaddr);
        var from = message.fromuser.hasOwnProperty('realemail') ? message.fromuser.realemail : message.fromaddr;
        var fromid = from.substring(0, from.indexOf('@'));
        text = text.replace(/\$memberid/g, fromid);

        //if (message['headerdate']) {
        //    text = text.replace(/\$membersubdate/g, formatDate(message['headerdate'], false, false));
        //}
        //

        var summ = '';

        if (message.hasOwnProperty('duplicates')) {
            _.each(message.duplicates, function(m) {
                summ += moment(m.date).format('lll') + " - " + m.subject + "\n";
            });

            var regex = new RegExp("\\$duplicatemessages", "gim");
            text = text.replace(regex, summ);
        }

        return(text);
    },

    maybeSettingsChange: function(trigger, stdmsg, message, group) {
        var self = this;

        var dt = stdmsg.get('newdelstatus');
        var ps = stdmsg.get('newmodstatus');

        if (dt != 'UNCHANGED') {
            $.ajax({
                type: 'POST',
                url: API + '/user',
                data: {
                    groupid: group.groupid,
                    id: message.get('fromuser').id,
                    yahooDeliveryType: dt
                }, success: function(ret) {
                    IznikPlugin.checkPluginStatus();
                }
            });
        }

        if (ps != 'UNCHANGED') {
            $.ajax({
                type: 'POST',
                url: API + '/user',
                data: {
                    groupid: group.groupid,
                    id: message.get('fromuser').id,
                    yahooPostingStatus: ps
                }, success: function(ret) {
                    IznikPlugin.checkPluginStatus();
                }
            });
        }

        self.trigger(trigger);
        self.close();
    },

    closeWhenRequired: function() {
        var self = this;

        // If the underlying message is approved, rejected or deleted then:
        // - we may have actions to complete
        // - this modal should close.
        self.listenToOnce(self.model, 'approved', function() {
            console.log("Approved only");
            _.each(self.model.get('groups'), function(group, index, list) {
                self.maybeSettingsChange.call(self, 'approved', self.options.stdmsg, self.model, group);
            });
            self.close();
        });

        self.listenToOnce(self.model, 'rejected', function() {
            console.log("Rejected only");
            _.each(self.model.get('groups'), function(group, index, list) {
                self.maybeSettingsChange.call(self, 'rejected', self.options.stdmsg, self.model, group);
            });
            self.close();
        });

        self.listenToOnce(self.model, 'deleted', function() {
            console.log("Deleted only");
            _.each(self.model.get('groups'), function(group, index, list) {
                self.maybeSettingsChange.call(self, 'deleted', self.options.stdmsg, self.model, group);
            });
            self.close();
        });

        console.log("Autosend?", self.model.get('autosend'));
        if (self.model.get('autosend')) {
            self.$('.js-send').click();
        }
    }
});


Iznik.Views.ModTools.Message.ViewSource = Iznik.Views.Modal.extend({
    template: 'modtools_pending_viewsource',

    render: function() {
        var self = this;
        this.open(this.template);

        // Fetch the individual message, which gives us access to the full message (which isn't returned
        // in the normal messages call to save bandwidth.
        var m = new Iznik.Models.Message({
            id: this.model.get('id')
        });

        m.fetch().then(function() {
            self.$('.js-source').text(m.get('message'));
        });
        return(this);
    }
});

Iznik.Views.ModTools.StdMessage.Edit = Iznik.Views.Modal.extend({
    template: 'modtools_message_edit',

    events: function () {
        return _.extend({}, _.result(Iznik.Views.Modal, 'events'), {
            'click .js-save': 'save'
        });
    },

    save: function() {
        var self = this;

        self.$('.js-editfailed').hide();

        self.listenToOnce(self.model, 'editsucceeded', function() {
            self.close();
        });

        self.listenToOnce(self.model, 'editfailed', function() {
            self.$('.js-editfailed').fadeIn('slow');
        });

        var html = tinyMCE.activeEditor.getContent({format : 'raw'});
        console.log("Edited HTML", html);
        var text = tinyMCE.activeEditor.getContent({format : 'text'});
        console.log("Edited text", text);

        self.model.edit(
            self.$('.js-subject').val(),
            text,
            html
        );
    },

    render: function() {
        var self = this;
        this.open(this.template, this.model);

        var body = self.model.get('htmlbody');
        body = body ? body : self.model.get('textbody');
        self.$('.js-text').val(body);

        tinymce.init({
            selector: '.js-text',
            height: 300,
            plugins: [
                'advlist autolink lists link image charmap print preview anchor',
                'searchreplace visualblocks code fullscreen',
                'insertdatetime media table contextmenu paste code'
            ],
            menubar: 'edit insert format tools',
            statusbar: false,
            toolbar: 'bold italic | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | link image'
        });
    }
});

Iznik.Views.ModTools.StdMessage.Button = IznikView.extend({
    template: 'modtools_message_stdmsg',

    tagName: 'li',

    events: {
        'click .js-approve': 'approve',
        'click .js-reject': 'reject',
        'click .js-delete': 'deleteMe',
        'click .js-hold': 'hold',
        'click .js-release': 'release'
    },

    hold: function() {
        var self = this;
        var message = self.model.get('message');
        message.hold();
    },

    release: function() {
        var self = this;
        var message = self.model.get('message');
        message.release();
    },

    approve: function() {
        var self = this;
        var message = self.model.get('message');

        if (this.options.config) {
            // This is a configured button; open the modal.
            var v = new Iznik.Views.ModTools.StdMessage.Pending.Approve({
                model: message,
                stdmsg: this.model,
                config: this.options.config
            });

            v.render();
        } else {
            // No popup to show.
            message.approve();
        }
    },

    reject: function() {
        var self = this;
        var message = self.model.get('message');

        var v = new Iznik.Views.ModTools.StdMessage.Pending.Reject({
            model: message,
            stdmsg: this.model,
            config: this.options.config
        });

        v.render();
    },

    deleteMe: function() {
        var self = this;
        var message = self.model.get('message');
        message.delete();
    }
});

Iznik.Views.ModTools.Message.Duplicate = IznikView.extend({
    template: 'modtools_message_duplicate',

    render: function() {
        var self = this;
        self.$el.html(window.template(self.template)(self.model.toJSON2()));
        this.$('.timeago').timeago();
        return(this);
    }
});

Iznik.Views.ModTools.Message.Related = IznikView.extend({
    template: 'modtools_message_related',

    render: function() {
        var self = this;
        self.$el.html(window.template(self.template)(self.model.toJSON2()));
        this.$('.timeago').timeago();
        return(this);
    }
});

