module LicenseHelpers
  def enable_licensed_feature(feature)
    allow(License).to receive(:feature_available?).and_call_original
    allow(License).to receive(:feature_available?).with(feature) { true }
  end
end
