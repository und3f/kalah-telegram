require 'telegram/bot'
require 'mancala/game.rb'

class Bot
    attr_accessor :games
    attr_accessor :users
    attr_accessor :gameId

    def initialize(token)
        @games = {}
        @users = {}
        @bot = Telegram::Bot::Client.new(token)
        @gameId = 1
    end

    def run()
        @bot.listen do |message|
            next unless message.text

            args = message.text.split(" ")
            command = args.shift()
            if command[0]=='/'
                command = command[1..-1]
            end

            case command.downcase
            when 'start'
                @bot.api.send_message(chat_id: message.chat.id, text: "Welcome!")
            when 'newgame'
                newGame(message.chat.id, args)
            when 'endgame'
                game = @users[message.chat.id]
                endGame(game) unless game.nil?
            when 'joingame'
                joinGame(message.chat.id, args[0])
            when 'sow'
                index = args[0] || -1
                turn(message.chat.id, index.to_i)
            else
                is_integer = Integer(command) rescue false
                if is_integer
                    index = command || -1
                    turn(message.chat.id, index.to_i)
                else
                    @bot.api.send_message(chat_id: message.chat.id, text: "Unknown command")
                end
            end
        end
    end

    def newGame(chatId, args)
        game = @users[chatId]
        if ! game.nil?
            @bot.api.send_message(chat_id: chatId, text: "Please end current game")
            return
        end

        board = Game.new()
        gameId = @gameId.to_s
        @gameId += 1
        @users[chatId] = @games[gameId] = {:board => board, :players => [chatId, nil], :id => gameId}
        @bot.api.send_message(chat_id: chatId, text: "Game #{gameId} created")
    end

    def joinGame(chatId, joiningGame)
        game = @games[joiningGame]

        if game.nil?
            _sendMessage(chatId, "Unknown game");
            return
        end

        if !@users[chatId].nil? and @users[chatId] != game
            @bot.api.send_message(chat_id: chatId, text: "Please end current game")
            return
        end

        game[:players][1] = chatId
        @users[chatId] = game
        @bot.api.send_message(chat_id: chatId, text: "You joined game with #{game[:players][0]}")

        for i in 0..1
            boardString = _prepareBoard(game[:board].board, i)
            chatId = game[:players][i]
            _sendMessage(chatId, "Game started!\nBoard:\n" + boardString)
        end
        _sendMessage(game[:players][0], "It is your turn, use /sow <index>");
    end

    def turn(chatId, houseIndex)
        game = @users[chatId]
        if game.nil?
            _sendMessage(chatId, "There are no game")
            return
        end

        if (houseIndex.nil?)
            _sendMessage(chatId, "Please use /sow [house]")
            return
        end

        board = game[:board]
        unless game[:players][board.activePlayer] == chatId
            _sendMessage(chatId, "It is opponent's turn")
            return
        end
        player = board.activePlayer

        begin
            nextPlayer = board.turn(houseIndex);
        rescue ArgumentError => error
            _sendMessage(chatId, "Please validate your command, /sow <index>")
            return
        end

        _sendMessage(chatId, _prepareBoard(game[:board].board, player))
        opponent = (player + 1) % 2
        _sendMessage(game[:players][opponent], "Opponent sowed #{houseIndex}, board:\n" + _prepareBoard(game[:board].board, opponent));
        if nextPlayer.nil?
            endGame(game)
            return
        end

        chatIdNextPlayer = game[:players][nextPlayer]
        _sendMessage(chatIdNextPlayer, "Your turn, /sow <index>")
    end

    def endGame(game)
        for i in 0..1
            chatId = game[:players][i]
            next if chatId.nil?
            _sendMessage(chatId, "Game ended.")
            @users.delete(chatId)
        end
        @games.delete(game[:id])
        return
    end

    def _prepareBoard(board, player)
        boardString = ""
        store = board.size / 2 
        playerStore = store * (1 + player) - 1
        playerStart = board.size * player
        opponentStore = store * (1 + (player + 1) % 2) - 1
        boardString += "   #{board[opponentStore]} -- Opponent\n"

        mirrorHouse = board.size() / 2
        offset = store * player
        for i in 0 .. board.size() / 2 - 2
            boardString += "#{i}: (#{board[(i + offset)]}) (#{board[(store+offset+i) % board.size]})\n"
        end
        boardString += "   #{board[playerStore]} -- Own\n"
        return boardString
    end

    def _sendMessage(chatId, message)
        @bot.api.send_message(chat_id: chatId, text: message)
    end
end