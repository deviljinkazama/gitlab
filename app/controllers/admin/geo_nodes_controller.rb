class Admin::GeoNodesController < Admin::ApplicationController
  before_action :check_license, except: [:index, :destroy]
  before_action :load_node, only: [:destroy, :repair, :toggle]

  def index
    @nodes = GeoNode.all.map(&:present)
    @node = GeoNode.new

    unless Gitlab::Geo.license_allows?
      flash.now[:alert] = 'You need a different license to enable Geo replication'
    end
  end

  def create
    @node = GeoNode.new(geo_node_params)

    if @node.save
      redirect_to admin_geo_nodes_path, notice: 'Node was successfully created.'
    else
      @nodes = GeoNode.all
      render :index
    end
  end

  def destroy
    @node.destroy

    redirect_to admin_geo_nodes_path, notice: 'Node was successfully removed.'
  end

  def repair
    if @node.primary? || !@node.missing_oauth_application?
      flash[:notice] = "This node doesn't need to be repaired."
    elsif @node.save
      flash[:notice] = 'Node Authentication was successfully repaired.'
    else
      flash[:alert] = 'There was a problem repairing Node Authentication.'
    end

    redirect_to admin_geo_nodes_path
  end

  def toggle
    if @node.primary?
      flash[:alert] = "Primary node can't be disabled."
    else
      @node.toggle!(:enabled)

      new_status = @node.enabled? ? 'enabled' : 'disabled'
      flash[:notice] = "Node #{@node.url} was successfully #{new_status}."
    end

    redirect_to admin_geo_nodes_path
  end

  private

  def geo_node_params
    params.require(:geo_node).permit(:url, :primary, geo_node_key_attributes: [:key])
  end

  def check_license
    unless Gitlab::Geo.license_allows?
      flash[:alert] = 'You need a different license to enable Geo replication'
      redirect_to admin_license_path
    end
  end

  def load_node
    @node = GeoNode.find(params[:id])
  end
end
