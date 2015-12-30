require 'zendesk_api/resources/web_portal/topic'

module ZendeskAPI
  class UserField < Resource; end

  class User < Resource
    self.resource_name = 'users'
    self.singular_resource_name = 'user'

    self.resource_paths = [
      'users/%{id}'
    ]

    self.collection_paths = [
      'users'
    ]

    extend CreateMany
    extend UpdateMany
    extend DestroyMany

    class TopicComment < TopicComment
      include Read
    end

    class Identity < Resource
      # Makes this identity the primary one bumping all other identities down one
      put :make_primary

      # Verifies this identity
      put :verify

      # Requests verification for this identity
      put :request_verification
    end

    any :password

    # Set a user's password
    def set_password(opts = {})
      password(opts.merge(:verb => :post))
    end

    # Change a user's password
    def change_password(opts = {})
      password(opts.merge(:verb => :put))
    end

    # Set a user's password
    def set_password!(opts = {})
      password!(opts.merge(:verb => :post))
    end

    # Change a user's password
    def change_password!(opts = {})
      password!(opts.merge(:verb => :put))
    end

    # Gets a incremental export of users from the start_time until now.
    # @param [Client] client The {Client} object to be used
    # @param [Integer] start_time The start_time parameter
    # @return [Collection] Collection of {User}
    def self.incremental_export(client, start_time)
      ZendeskAPI::Collection.new(client, self, :path => "incremental/users?start_time=#{start_time.to_i}")
    end

    has :organization, class: 'Organization'

    class Session < Resource
    end

    class CurrentSession < SingularResource
      class << self
        def singular_resource_name
          'session'
        end

        alias :resource_name :singular_resource_name
      end
    end

    has_many :sessions, class: 'Session'

    def current_session
      ZendeskAPI::User::CurrentSession.find(@client, :user_id => 'me')
    end

    delete :logout

    def clear_sessions!
      @client.connection.delete(path + '/sessions')
    end

    def clear_sessions
      clear_sessions!
    rescue ZendeskAPI::Error::ClientError
      false
    end

    has :custom_role, class: 'CustomRole', inline: true, include: :roles
    has :role, class: 'Role', inline: true, include_key: :name
    has :ability, class: 'Ability', inline: true

    has_many :identities, class: 'Identity'

    has_many :requests, class: 'Request'
    has_many :requested_tickets, class: 'Ticket', :path => 'tickets/requested'
    has_many :ccd_tickets, class: 'Ticket', :path => 'tickets/ccd'

    has_many :groups, class: 'Group'
    has_many :group_memberships, class: 'GroupMembership'

    has_many :organization_memberships, class: 'OrganizationMembership'

    has_many :forum_subscriptions, class: 'ForumSubscription'
    has_many :topic_subscriptions, class: 'TopicSubscription'

    has_many :topics, class: 'Topic'
    has_many :topic_comments, class: 'User::TopicComment'
    has_many :topic_votes, class: 'Topic::TopicVote'

    has_many :settings, class: 'Setting'
    has_many :tags, class: 'Tag', extend: 'Tag::Update', inline: :create

    def attributes_for_save
      # Don't send role_id, it's necessary
      # for side-loading, but causes problems on save
      # see #initialize
      attrs = attributes.changes.delete_if do |k, _|
        k == "role_id"
      end

      { self.class.singular_resource_name => attrs }
    end

    def handle_response(*)
      super

      # Needed for proper Role sideloading
      self.role_id = role.name if key?(:role)
    end
  end
end