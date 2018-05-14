require "mancala/game.rb"
require "test/unit"

class TestGame < Test::Unit::TestCase
    def testBoard()
        board = Game.new(:houses => 6)
        assert_equal([4, 4, 4, 4, 4, 4, 0, 4, 4, 4, 4, 4, 4, 0],
                     board.board())

        assert_equal(0, board.activePlayer())
        board.turn(0, 2)

        assert_equal([4, 4, 0, 5, 5, 5, 1, 4, 4, 4, 4, 4, 4, 0],
                     board.board())
        assert_equal(0, board.activePlayer())

        board.turn(0, 5);
        assert_equal([4, 4, 0, 5, 5, 0, 2, 5, 5, 5, 5, 4, 4, 0],
                     board.board())
        assert_equal(1, board.activePlayer())

        board.turn(1, 1);
        assert_equal([4, 4, 0, 5, 5, 0, 2, 5, 0, 6, 6, 5, 5, 1],
                     board.board())
        assert_equal(1, board.activePlayer())

        assert_equal(0, board.turn(1, 0))
        assert_equal([4, 4, 0, 5, 5, 0, 2, 0, 1, 7, 7, 6, 6, 1],
                     board.board())
        assert_equal(0, board.activePlayer())

        assert_equal(1, board.turn(0, 1))
        assert_equal([4, 0, 1, 6, 6, 1, 2, 0, 1, 7, 7, 6, 6, 1],
                     board.board())
        assert_equal(1, board.activePlayer())

        assert_equal(0, board.turn(1, 1))
        assert_equal([4, 0, 1, 6, 6, 1, 2, 0, 0, 8, 7, 6, 6, 1],
                     board.board())
        assert_equal(0, board.activePlayer())

        assert_equal(1, board.turn(0, 0))
        assert_equal([0, 1, 2, 7, 7, 1, 2, 0, 0, 8, 7, 6, 6, 1],
                     board.board())
    end

    def testEndGame()
        board = Game.new(
            :houses => 3,
            :board => [0, 0, 0, 18, 0, 0, 1, 17],
            :activePlayer => 1
        )
        assert_equal(nil, board.turn(1, 2))
        assert_equal([18, 18], board.score())
    end

    def testCapture()
        board = Game.new(
            :houses => 6,
            :board => [1, 1, 0, 5, 10, 1, 7, 1, 0, 7, 7, 0, 0, 8],
            :activePlayer => 1
        )
        assert_equal(0, board.turn(1, 0))
        assert_equal([1, 1, 0, 5, 0, 1, 7, 0, 0, 7, 7, 0, 0, 19], board.board())
    end
end
