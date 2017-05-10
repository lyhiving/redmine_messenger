# Redmine Messenger plugin for Redmine

module RedmineMessenger
  module Patches
    module IssuePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create :send_messenger_create
          after_save :send_messenger_save
        end
      end

      module InstanceMethods
        def send_messenger_create
          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project
          post_private_issues = Messenger.post_private_issues_for_project(project)

          return unless channels.present? && url
          return if is_private? && post_private_issues != '1'

          msg = "[#{ERB::Util.html_escape(project)}] #{ERB::Util.html_escape(author)} created <#{Messenger.object_url(self)}|#{ERB::Util.html_escape(self)}>#{Messenger.mentions description if RedmineMessenger.settings[:auto_mentions] == '1'}"

          attachment = {}
          attachment[:text] = ERB::Util.html_escape(description) if description && RedmineMessenger.settings[:new_include_description] == '1'
          attachment[:fields] = [{
            title: I18n.t(:field_status),
            value: ERB::Util.html_escape(status.to_s),
            short: true
          }, {
            title: I18n.t(:field_priority),
            value: ERB::Util.html_escape(priority.to_s),
            short: true
          }, {
            title: I18n.t(:field_assigned_to),
            value: ERB::Util.html_escape(assigned_to.to_s),
            short: true
          }]

          if RedmineMessenger.settings[:display_watchers] == '1'
            attachment[:fields] << {
              title: I18n.t(:field_watcher),
              value: ERB::Util.html_escape(watcher_users.join(', ')),
              short: true
            }
          end

          Messenger.speak msg, channels, attachment, url
        end

        def send_messenger_save
          return if current_journal.nil?

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project
          post_private_issues = Messenger.post_private_issues_for_project(project)
          post_private_notes = Messenger.post_private_notes_for_project(project)

          return unless channels.present? && url && RedmineMessenger.settings[:post_updates] == '1'
          return if is_private? && post_private_issues != '1'
          return if current_journal.private_notes? && post_private_notes != '1'

          msg = "[#{ERB::Util.html_escape(project)}] #{ERB::Util.html_escape(current_journal.user.to_s)} updated <#{Messenger.object_url self}|#{ERB::Util.html_escape(self)}>#{Messenger.mentions current_journal.notes if RedmineMessenger.settings[:auto_mentions] == '1'}"

          attachment = {}
          if current_journal.notes && RedmineMessenger.settings[:updated_include_description] == '1'
            attachment[:text] = ERB::Util.html_escape(current_journal.notes)
          end
          attachment[:fields] = current_journal.details.map { |d| Messenger.detail_to_field d }

          Messenger.speak msg, channels, attachment, url
        end
      end
    end
  end
end

unless Issue.included_modules.include? RedmineMessenger::Patches::IssuePatch
  Issue.send(:include, RedmineMessenger::Patches::IssuePatch)
end
