module Boards
  class CreateService < BaseService
    def execute
      board = project.boards.create(params)

<<<<<<< HEAD
      if board.persisted?
        board.lists.create(list_type: :closed)
      end
=======
    private

    def create_board!
      board = project.boards.create
      board.lists.create(list_type: :backlog)
      board.lists.create(list_type: :closed)
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81

      board
    end
  end
end
