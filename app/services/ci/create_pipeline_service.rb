module Ci
  class CreatePipelineService < BaseService
    attr_reader :pipeline

    def execute(source, ignore_skip_ci: false, save_on_errors: true, trigger_request: nil, schedule: nil, mirror_update: false, &block)
      @pipeline = Ci::Pipeline.new(
        source: source,
        project: project,
        ref: ref,
        sha: sha,
        before_sha: before_sha,
        tag: tag?,
        trigger_requests: Array(trigger_request),
        user: current_user,
        pipeline_schedule: schedule
      )

      unless project.builds_enabled?
        return error('Pipeline is disabled')
      end

      unless project.mirror_trigger_builds?
        return error('Pipeline is disabled for mirror updates') if mirror_update
      end

      unless trigger_request || can?(current_user, :create_pipeline, project)
        return error('Insufficient permissions to create a new pipeline')
      end

      unless branch? || tag?
        return error('Reference not found')
      end

      unless commit
        return error('Commit not found')
      end

      unless pipeline.config_processor
        unless pipeline.ci_yaml_file
          return error('Missing .gitlab-ci.yml file')
        end
        return error(pipeline.yaml_errors, save: save_on_errors)
      end

      if !ignore_skip_ci && skip_ci?
        pipeline.skip if save_on_errors
        return pipeline
      end

      unless pipeline.has_stage_seeds?
        return error('No stages / jobs for this pipeline.')
      end

      _create_pipeline(source, &block)
    end

    private

    def _create_pipeline(source)
      Ci::Pipeline.transaction do
        update_merge_requests_head_pipeline if pipeline.save

        yield(pipeline) if block_given?

        Ci::CreatePipelineStagesService
          .new(project, current_user)
          .execute(pipeline)
      end

      cancel_pending_pipelines if project.auto_cancel_pending_pipelines?

      pipeline_created_counter.increment(source: source)

      pipeline.tap(&:process!)
    end

    def update_merge_requests_head_pipeline
      return unless pipeline.latest?

      MergeRequest.where(source_project: @pipeline.project, source_branch: @pipeline.ref).
        update_all(head_pipeline_id: @pipeline.id)
    end

    def skip_ci?
      return false unless pipeline.git_commit_message
      pipeline.git_commit_message =~ /\[(ci[ _-]skip|skip[ _-]ci)\]/i
    end

    def cancel_pending_pipelines
      Gitlab::OptimisticLocking.retry_lock(auto_cancelable_pipelines) do |cancelables|
        cancelables.find_each do |cancelable|
          cancelable.auto_cancel_running(pipeline)
        end
      end
    end

    def auto_cancelable_pipelines
      project.pipelines
        .where(ref: pipeline.ref)
        .where.not(id: pipeline.id)
        .where.not(sha: project.repository.sha_from_ref(pipeline.ref))
        .created_or_pending
    end

    def commit
      @commit ||= project.commit(origin_sha || origin_ref)
    end

    def sha
      commit.try(:id)
    end

    def before_sha
      params[:checkout_sha] || params[:before] || Gitlab::Git::BLANK_SHA
    end

    def origin_sha
      params[:checkout_sha] || params[:after]
    end

    def origin_ref
      params[:ref]
    end

    def branch?
      project.repository.ref_exists?(Gitlab::Git::BRANCH_REF_PREFIX + ref)
    end

    def tag?
      project.repository.ref_exists?(Gitlab::Git::TAG_REF_PREFIX + ref)
    end

    def ref
      Gitlab::Git.ref_name(origin_ref)
    end

    def valid_sha?
      origin_sha && origin_sha != Gitlab::Git::BLANK_SHA
    end

    def error(message, save: false)
      pipeline.errors.add(:base, message)
      pipeline.drop if save
      pipeline
    end

    def pipeline_created_counter
      @pipeline_created_counter ||= Gitlab::Metrics.counter(:pipelines_created_count, "Pipelines created count")
    end
  end
end
