require 'spec_helper'

describe Ci::Sources::Pipeline, models: true do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:pipeline) }

  it { is_expected.to belong_to(:source_project) }
  it { is_expected.to belong_to(:source_job) }
  it { is_expected.to belong_to(:source_pipeline) }
  
  it { is_expected.to validate_presence_of(:project) }
  it { is_expected.to validate_presence_of(:pipeline) }

  it { is_expected.to validate_presence_of(:source_project) }
  it { is_expected.to validate_presence_of(:source_job) }
  it { is_expected.to validate_presence_of(:source_pipeline) }
end
