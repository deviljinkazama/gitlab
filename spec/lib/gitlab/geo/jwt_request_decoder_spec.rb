require 'spec_helper'

describe Gitlab::Geo::JwtRequestDecoder do
  let!(:primary_node) { FactoryGirl.create(:geo_node, :primary) }
  let(:data) { { input: 123 } }
  let(:request) { Gitlab::Geo::TransferRequest.new(data) }

  subject { described_class.new(request.header['Authorization']) }

  it '#decode' do
    expect(subject.decode).to eq(data)
  end
end
