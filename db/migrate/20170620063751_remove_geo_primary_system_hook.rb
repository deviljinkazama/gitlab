class RemoveGeoPrimarySystemHook < ActiveRecord::Migration
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  # Older version of Geo added push and tag push events to the
  # primary system hook. This would cause unnecessary hooks to be
  # fired.
  def up
    return unless geo_enabled?

    execute <<-SQL
      DELETE FROM web_hooks WHERE
      type = 'SystemHook' AND
      id IN (
      SELECT system_hook_id FROM geo_nodes WHERE
        "primary" = #{true_value}
      );
    SQL
 end

  def geo_enabled?
    select_all("SELECT 1 FROM geo_nodes").present?
  end
end
