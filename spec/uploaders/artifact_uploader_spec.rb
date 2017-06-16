require 'rails_helper'

describe ArtifactUploader do
  let(:store) { described_class::LOCAL_STORE }
  let(:job) { create(:ci_build, artifacts_file_store: store) }
  let(:uploader) { described_class.new(job, :artifacts_file) }
  let(:local_path) { Gitlab.config.artifacts.path }

  describe '.local_artifacts_store' do
    subject { described_class.local_artifacts_store }

    it "delegate to artifacts path" do
      expect(Gitlab.config.artifacts).to receive(:path)

      subject
    end
  end

  describe '.artifacts_upload_path' do
    subject { described_class.artifacts_upload_path }
<<<<<<< HEAD
    
    it { is_expected.to start_with(local_path) }
=======

    it { is_expected.to start_with(path) }
>>>>>>> upstream/master
    it { is_expected.to end_with('tmp/uploads/') }
  end

  describe '#store_dir' do
    subject { uploader.store_dir }

<<<<<<< HEAD
    let(:path) { "#{job.created_at.utc.strftime('%Y_%m')}/#{job.project_id}/#{job.id}" }

    context 'when using local storage' do
      it { is_expected.to start_with(local_path) }
      it { is_expected.to end_with(path) }
    end

    context 'when using remote storage' do
      let(:store) { described_class::REMOTE_STORE }
      
      before do
        stub_artifacts_object_storage
      end

      it { is_expected.to eq(path) }
    end
=======
    it { is_expected.to start_with(path) }
    it { is_expected.to end_with("#{job.project_id}/#{job.id}") }
>>>>>>> upstream/master
  end

  describe '#cache_dir' do
    subject { uploader.cache_dir }
<<<<<<< HEAD
    
    it { is_expected.to start_with(local_path) }
    it { is_expected.to end_with('tmp/cache') }
=======

    it { is_expected.to start_with(path) }
    it { is_expected.to end_with('/tmp/cache') }
  end

  describe '#work_dir' do
    subject { uploader.work_dir }

    it { is_expected.to start_with(path) }
    it { is_expected.to end_with('/tmp/work') }
  end

  describe '#filename' do
    # we need to use uploader, as this makes to use mounter
    # which initialises uploader.file object
    let(:uploader) { job.artifacts_file }

    subject { uploader.filename }

    it { is_expected.to be_nil }

    context 'with artifacts' do
      let(:job) { create(:ci_build, :artifacts) }

      it { is_expected.not_to be_nil }
    end
>>>>>>> upstream/master
  end
end
