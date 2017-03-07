module Elastic
  module IssuesSearch
    extend ActiveSupport::Concern

    included do
      include ApplicationSearch

      mappings _parent: { type: 'project' } do
        indexes :id,          type: :integer
        indexes :iid,         type: :integer
        indexes :title,       type: :text,
                              index_options: 'offsets'
        indexes :description, type: :text,
                              index_options: 'offsets'
        indexes :created_at,  type: :date
        indexes :updated_at,  type: :date
        indexes :state,       type: :text
        indexes :project_id,  type: :integer
        indexes :author_id,   type: :integer
        indexes :assignee_id, type: :integer
        indexes :confidential, type: :boolean
      end

      def as_indexed_json(options = {})
        data = {}

        # We don't use as_json(only: ...) because it calls all virtual and serialized attributtes
        # https://gitlab.com/gitlab-org/gitlab-ee/issues/349
        [:id, :iid, :title, :description, :created_at, :updated_at, :state, :project_id, :author_id, :assignee_id, :confidential].each do |attr|
          data[attr.to_s] = safely_read_attribute_for_elasticsearch(attr)
        end

        data
      end

      def self.nested?
        true
      end

      def self.elastic_search(query, options: {})
        query_hash =
          if query =~ /#(\d+)\z/
            iid_query_hash(query_hash, $1)
          else
            basic_query_hash(%w(title^2 description), query)
          end

        query_hash = project_ids_filter(query_hash, options)
        query_hash = confidentiality_filter(query_hash, options[:current_user])

        self.__elasticsearch__.search(query_hash)
      end

      def self.confidentiality_filter(query_hash, current_user)
        return query_hash if current_user && current_user.admin?

        filter = if current_user
                   {
                     bool: {
                       should: [
                         { term: { confidential: false } },
                         {
                           bool: {
                             must: [
                               { term: { confidential: true } },
                               {
                                 bool: {
                                   should: [
                                     { term: { author_id: current_user.id } },
                                     { term: { assignee_id: current_user.id } },
                                     { terms: { project_id: current_user.authorized_projects(Gitlab::Access::REPORTER).pluck(:id) } }
                                   ]
                                 }
                               }
                             ]
                           }
                         }
                       ]
                     }
                   }
                 else
                   { term: { confidential: false } }
                 end

        query_hash[:query][:bool][:filter] << filter
        query_hash
      end
    end
  end
end
