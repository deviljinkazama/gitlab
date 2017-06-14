class SystemNoteMetadata < ActiveRecord::Base
  ICON_TYPES = %w[
    commit description merge confidential visible label assignee cross_reference
    title time_tracking branch milestone discussion task moved opened closed merged
    outdated
<<<<<<< HEAD
    approved unapproved relate unrelate
=======
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  ].freeze

  validates :note, presence: true
  validates :action, inclusion: ICON_TYPES, allow_nil: true

  belongs_to :note
end
