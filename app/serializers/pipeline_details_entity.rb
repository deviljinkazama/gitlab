class PipelineDetailsEntity < PipelineEntity
  expose :details do
<<<<<<< HEAD
    expose :stages, using: StageEntity
    expose :artifacts, using: BuildArtifactEntity
    expose :manual_actions, using: BuildActionEntity
  end

  expose :triggered_by_pipeline, as: :triggered_by, with: TriggeredPipelineEntity
  expose :triggered_pipelines, as: :triggered, using: TriggeredPipelineEntity
=======
    expose :legacy_stages, as: :stages, using: StageEntity
    expose :artifacts, using: BuildArtifactEntity
    expose :manual_actions, using: BuildActionEntity
  end
>>>>>>> ce/9-3-stable
end
