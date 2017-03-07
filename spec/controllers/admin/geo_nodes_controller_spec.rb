require 'spec_helper'

describe Admin::GeoNodesController do
  shared_examples 'unlicensed geo action' do
    it 'redirects to the license page' do
      expect(response).to redirect_to(admin_license_path)
    end

    it 'displays a flash message' do
      expect(controller).to set_flash[:alert].to('You need a different license to enable Geo replication')
    end
  end

  let(:user) { create(:user) }
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe '#index' do
    render_views
    subject { get :index }

    context 'with add-on license available' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
      end

      it 'renders creation form' do
        expect(subject).to render_template(partial: 'admin/geo_nodes/_form')
      end
    end

    context 'without add-on license available' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(false)
      end

      it 'does not render the creation form' do
        expect(subject).not_to render_template(partial: 'admin/geo_nodes/_form')
      end

      it 'displays a flash message' do
        subject
        expect(controller).to set_flash.now[:alert].to('You need a different license to enable Geo replication')
      end

      it 'does not redirects to the license page' do
        subject
        expect(response).not_to redirect_to(admin_license_path)
      end
    end
  end

  describe '#destroy' do
    let!(:geo_node) { create(:geo_node) }
    subject do
      delete(:destroy, id: geo_node)
    end

    context 'without add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(false)
      end

      it 'deletes the node' do
        expect { subject }.to change { GeoNode.count }.by(-1)
      end
    end

    context 'with add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
      end

      it 'deletes the node' do
        expect { subject }.to change { GeoNode.count }.by(-1)
      end
    end
  end

  describe '#create' do
    let(:geo_node_attributes) { { url: 'http://example.com', geo_node_key_attributes: { key: SSHKeygen.generate } } }
    subject { post :create, geo_node: geo_node_attributes }

    context 'without add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?) { false }
        subject
      end

      it_behaves_like 'unlicensed geo action'
    end

    context 'with add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
      end

      it 'creates the node' do
        expect { subject }.to change { GeoNode.count }.by(1)
      end
    end
  end

  describe '#repair' do
    let(:geo_node) { create(:geo_node) }
    subject { post :repair, id: geo_node }

    before do
      allow(Gitlab::Geo).to receive(:license_allows?) { false }
      subject
    end

    it_behaves_like 'unlicensed geo action'
  end

  describe '#toggle' do
    context 'without add-on license' do
      let(:geo_node) { create(:geo_node) }

      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(false)
        post :toggle, id: geo_node
      end

      it_behaves_like 'unlicensed geo action'
    end

    context 'with add-on license' do
      before do
        allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
        post :toggle, id: geo_node
      end

      context 'with a primary node' do
        let(:geo_node) { create(:geo_node, :primary, enabled: true) }

        it 'does not disable the node' do
          expect(geo_node.reload).to be_enabled
        end

        it 'displays a flash message' do
          expect(controller).to set_flash.now[:alert].to("Primary node can't be disabled.")
        end

        it 'redirects to the geo nodes page' do
          expect(response).to redirect_to(admin_geo_nodes_path)
        end
      end

      context 'with a secondary node' do
        let(:geo_node) { create(:geo_node, host: 'example.com', port: 80, enabled: true) }

        it 'disables the node' do
          expect(geo_node.reload).not_to be_enabled
        end

        it 'displays a flash message' do
          expect(controller).to set_flash.now[:notice].to('Node http://example.com/ was successfully disabled.')
        end

        it 'redirects to the geo nodes page' do
          expect(response).to redirect_to(admin_geo_nodes_path)
        end
      end
    end
  end
end
