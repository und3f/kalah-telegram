class Game
    def initialize(options = {})
        @houses = options[:houses] || 6
        @seedsPerHouse = options[:seedsPerHouse] || 4
        @captureEmpty = options[:captureEmpty] || true

        @totalHouses = @houses * 2 + 2
        if loadBoard = options[:board]
            if (loadBoard.size() != @totalHouses)
                raise ArumentError, "Wrong board size"
            end
            @board = loadBoard
        else
            @board = [0]
            for i in 1..@houses
                @board.unshift(@seedsPerHouse)
                @board.push(@seedsPerHouse)
            end
            @board.push(0)
        end

        @activePlayer = options[:activePlayer] || 0
    end

    attr_reader :houses
    attr_reader :seedsPerHouse
    attr_reader :captureEmpty
    attr_reader :totalHouses
    attr_accessor :board
    attr_accessor :activePlayer

    def turn(player = @activePlayer, index)
        unless player.equal?(@activePlayer)
            raise ArgumentError,"Wrong player"
        end

        unless index >= 0 && index < @houses
            raise ArgumentError, "Wrong index"
        end

        indexOffset = (@houses + 1) * @activePlayer
        playersHouse   = (@houses + indexOffset) % @totalHouses
        opponentsHouse = (playersHouse + 1 + @houses) % @totalHouses
        i = index + indexOffset
        seeds = @board[i]
        @board[i] = 0
        while (seeds > 0)
            i = (i+1) % @totalHouses
            if (i != opponentsHouse)
                if (@captureEmpty && seeds == 1 && i != playersHouse && @board[i] == 0)
                    mirrorHouse = (opponentsHouse - 1 - i + indexOffset) % @totalHouses
                    if (i >= indexOffset && i < playersHouse && @board[mirrorHouse] > 0)
                        @board[playersHouse] += 1 + @board[mirrorHouse]
                        @board[mirrorHouse] = 0
                        seeds -= 1
                        next
                    end
                end
                @board[i] += 1
                seeds -= 1
            end
        end

        if (i != playersHouse)
            @activePlayer = (@activePlayer + 1) % 2
        else
            if(_check_game_finished())
                @activePlayer = nil
            end
        end

        return @activePlayer
    end

    def score()
        captureHouse1 = @houses
        captureHouse2 = @houses * 2 + 1
        return [@board[captureHouse1], @board[captureHouse2]]
    end

    def _check_game_finished()
        captureHouse1 = @houses
        captureHouse2 = @houses * 2 + 1
        @board.each_with_index do |element, index|
            if (index == captureHouse1 || index == captureHouse2)
                next
            end
            if element > 0
                return false
            end
        end
        return true;
    end
end
