class Projects::BoardsController < Projects::ApplicationController
  include IssuableCollections

  before_action :authorize_read_board!, only: [:index, :show]
  before_action :authorize_admin_board!, only: [:create, :update, :destroy]
  before_action :find_board, only: [:show, :update, :destroy]

  def index
    @boards = ::Boards::ListService.new(project, current_user).execute

    respond_to do |format|
      format.html
      format.json do
        render json: serialize_as_json(@boards)
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: serialize_as_json(@board)
      end
    end
  end

  def create
    board = ::Boards::CreateService.new(project, current_user, board_params).execute

    respond_to do |format|
      format.json do
        if board.valid?
          render json: serialize_as_json(board)
        else
          render json: board.errors, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    service = ::Boards::UpdateService.new(project, current_user, board_params)

    service.execute(@board)

    respond_to do |format|
      format.json do
        if @board.valid?
          render json: serialize_as_json(@board)
        else
          render json: @board.errors, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    service = ::Boards::DestroyService.new(project, current_user)
    service.execute(@board)

    respond_to do |format|
      format.html { redirect_to namespace_project_boards_path(@project.namespace, @project) }
    end
  end

  private

  def authorize_admin_board!
    return render_404 unless can?(current_user, :admin_board, project)
  end

  def authorize_read_board!
    return render_404 unless can?(current_user, :read_board, project)
  end

  def board_params
    params.require(:board).permit(:name, :milestone_id)
  end

  def find_board
    @board = project.boards.find(params[:id])
  end

  def serialize_as_json(resource)
    resource.as_json(
      only: [:id, :name],
      include: {
        milestone: { only: [:id, :title] }
      }
    )
  end
end
