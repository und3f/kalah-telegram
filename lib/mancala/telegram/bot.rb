require 'telegram/bot'
require 'mancala/game.rb'

class Integer
    def digits(base: 10)
        quotient, remainder = divmod(base)
        quotient == 0 ? [remainder] : [*quotient.digits(base: base), remainder]
    end

    def to_s_fw()
        digits.map { |c| (c + "\uff10".ord()).chr("utf-8") }.join
    end
end

class Bot
    attr_reader   :botName
    attr_accessor :games
    attr_accessor :users
    attr_accessor :gameId

    def initialize(token, botName)
        @botName = botName
        @games = {}
        @users = {}
        @bot = Telegram::Bot::Client.new(token, logger: Logger.new($stderr))
        @gameId = 1
    end

    def run()
        @bot.listen do |message|
            begin
                _process_message(message)
            rescue
            end
        end
    end

    def _process_message(message)
        case message

        when Telegram::Bot::Types::Message
            return if message.text.nil?
            args = message.text.split(" ")
            chatId = message.chat.id
        when Telegram::Bot::Types::CallbackQuery
            return if message.data.nil?
            args = message.data.split(" ")
            command = args.shift()
            chatId = message.from.id
            @bot.api.answer_callback_query(callback_query_id: message.id)
        end

        command = args.shift()
        if command[0]=='/'
            command = command[1..-1]
        end

        return if command.nil?

        case command.downcase
        when 'start'
            unless args[0].nil?
                joinGame(chatId, args[0])
            else
                @bot.api.send_message(chat_id: chatId, text: "Welcome!")
            end
        when 'newgame'
            newGame(chatId, args)
        when 'endgame'
            game = @users[chatId]
            endGame(game) unless game.nil?
        when 'joingame'
            joinGame(chatId, args[0])
        when 'sow'
            turn(chatId, args[0].to_i - 1)
        else
            is_integer = Integer(command) rescue false
            if is_integer
                turn(chatId, command.to_i - 1)
            else
                @bot.api.send_message(chat_id: chatId, text: "Unknown command")
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
        gameId = @gameId.to_s + "-" + rand(1000).to_s
        @gameId += 1
        @users[chatId] = @games[gameId] = {:board => board, :players => [chatId, nil], :id => gameId}

        url = "https://t.me/#{@botName}?start=#{gameId}"
        @bot.api.send_message(chat_id: chatId, text: "Game created, forward link to a friend #{url}")
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

        unless game[:players][1].nil?
            _sendMessage(chatId, "Game already started")
            return
        end

        game[:players][1] = chatId
        game[:players] = game[:players].reverse
        @users[chatId] = game
        @bot.api.send_message(chat_id: chatId, text: "You joined game with #{game[:players][0]}")

        for i in 0..1
            boardString = _prepareBoard(game[:board], i)
            chatId = game[:players][i]
            _sendMessage(chatId, "Game started!\nBoard:\n" + boardString, parse_mode: 'HTML')
        end
        _sowMessage(game[:players][0], game[:board])
    end

    def turn(chatId, houseIndex)
        game = @users[chatId]
        if game.nil?
            _sendMessage(chatId, "There is no game")
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
            nextPlayer,trace = board.turn(houseIndex);
        rescue ArgumentError
            _sendMessage(chatId, "Please validate your command, /sow <index>")
            return
        end

        _sendMessage(chatId, _prepareBoard(game[:board], player, trace), parse_mode: 'HTML')
        opponent = (player + 1) % 2
        houses = board.board.size() / 2 - 1
        _sendMessage(
            game[:players][opponent],
            "Opponent sowed from the house ##{houses-houseIndex}:\n" + 
            _prepareBoard(game[:board], opponent, trace),
            parse_mode: "HTML");

        if nextPlayer.nil?
            score = board.score()
            _sendScoreStatistic(game[:players][0], score)
            _sendScoreStatistic(game[:players][1], score.reverse)

            endGame(game)
            return
        end

        chatIdNextPlayer = game[:players][nextPlayer]

        _sowMessage(chatIdNextPlayer, board)
    end

    def _sendScoreStatistic(chatId, score)
        message = ""
        if score[0] == score[1]
            message += "Draw!"
        elsif score[0] > score[1]
            message += "You win!"
        else
            message += "You lose. Better luck next time!!"
        end

        message += "\nYou #{score[0]} - Opponent #{score[1]}"
        _sendMessage(chatId, message)
    end

    def _sowMessage(chatId, board)
        _sendMessage(chatId, "Your turn, choose the house to sow from", 
                     reply_markup: _prepareSowKeyboard(board))
    end

    def _prepareSowKeyboard(board)
        houses = board.board.size() / 2 - 1
        kb = []
        for i in 1..houses
            kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: i, callback_data: "sow #{i}"))
        end
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [kb], one_time_keyboard: true, resize_keyboard: true)
        return markup
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

    def _prepareBoard(game, player, trace=[])
        board=game.board
        boardString = ""
        store = board.size / 2 
        playerStore = store * (1 + player) - 1
        opponentStore = store * (1 + (player + 1) % 2) - 1

        playersStart = (1 + opponentStore) % board.size
        playersEnd   = (opponentStore - 1) % board.size
        spaceInterval = board[playersStart, playersEnd].max.digits.size+1

        boardString += _boardStore(board[opponentStore], "Opponent", trace.include?(opponentStore))

        for i in 0 .. board.size() / 2 - 2
            playerIndex = (i + 1 + opponentStore) % board.size

            boardString += "#{(i+1).to_s_fw}\u3000"

            boardString += _boardHouse(board[playerIndex], trace.include?(playerIndex))

            currentSpace = spaceInterval - board[playerIndex].digits.size
            currentSpace.times {
                boardString += "\u3000"
            }

            opponentIndex = (playerStore + store - 1 - i) % board.size
            boardString += _boardHouse(board[opponentIndex], trace.include?(opponentIndex))
            boardString += "\n"
        end

        boardString += _boardStore(board[playerStore], "Own", trace.include?(playerStore))
        return boardString
    end

    def _boardHouse(value, emphasis)
        str = ""
        str += "<strong>" if emphasis
        str += "（#{value.to_s_fw}）"
        str += "</strong>" if emphasis
        return str
    end

    def _boardStore(value, caption, emphasis)
        spacing = "\u3000\u3000\u3000\u3000"
        boardString = "#{spacing}"
        boardString += "<b>" if (emphasis)
        boardString += "（#{value.to_s_fw}）"
        boardString += "</b>" if (emphasis)
        boardString += " #{caption}\n"
        return boardString
    end

    def _sendMessage(chatId, message, opts = {})
        @bot.api.send_message({chat_id: chatId, text: message}.merge(opts))
    end
end
