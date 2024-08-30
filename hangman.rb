require 'io/console'
require 'json'
require 'time'

class Hangman

  @@max_length = nil
  @@save_path = "./saves/"

  def initialize()
    @settings = {
      min_length: 5,
      max_length: 12,
      n_attempts: 11,
      mode: :computer,
    }
    @words = self.load_words("./google-10000-english-no-swears.txt")
    @words = @words.sort_by() { |w| w.length() }
  end

  def load_words(path)
    fd = IO.sysopen(path, 'r')
    wordsFile = IO.new(fd)
    words = []
    max_length = 0
    while !wordsFile.eof?()
      word = wordsFile.gets().chomp()
      words.append(word)
      max_length = [max_length, word.length()].max
    end
    @@max_length = max_length
    return words
  end

  def main()
      options = {
        0 => :game,
        1 => :load_game,
        2 => :choose_settings,
        3 => :exit,
      }
      pointer = 0
      self.render("main_menu#{pointer}")
      input = STDIN.getch()
      while !self.enter(input) && !self.cancel(input)
        if input === "\e"
          input += STDIN.getch + STDIN.getch
          if input === "\e[A"
            pointer = (pointer-1+options.length())%options.length()
          elsif input === "\e[B"
            pointer = (pointer+1)%options.length()
          end
          self.render("main_menu#{pointer}")
        end
        input = STDIN.getch()
      end
      if self.cancel(input)
        exit
      end
      send(options[pointer], @settings)
  end

  def guess(g, game)
    if game[:secret_word].include?(g)
      for i in 0...game[:secret_word].length() do
        if game[:secret_word][i] === g
          game[:progress].append(i)
        end
      end
    else
      game[:left] -= 1
    end
    game[:guessed].append(g)
  end

  def game(settings, game = nil)
    if !game
      game = {
        secret_word: "",
        progress: [],
        left: @settings[:n_attempts],
        guessed: [],
        n_attempts: @settings[:n_attempts],
      }
      if @settings[:mode] === :manual
        game[:secret_word] = self.manual_choose_word()
      else
        game[:secret_word] = self.auto_choose_word()
      end
    end
    def validate(c)
      if !self.is_letter(c)
        return "_"
      else
        return c.downcase()
      end
    end
    pinput = ""
    input = "_"
    while !self.eog?(game) && !self.cancel(input)
      render_game(game, validate(input))
      pinput = validate(input)
      input = STDIN.getch()
      if self.enter(input) && !game[:guessed].include?(pinput) && pinput != "_"
        self.guess(pinput, game)
      end
      if input === "."
        self.save_game(game)
      end
    end
    if self.cancel(input)
      main()
    end
    end_state = nil
    if self.win?(game)
      end_state = "win_screen0" 
    else
      end_state = "lose_screen0"
    end
    render(end_state + "-#{game[:secret_word]}-#{game[:n_attempts] - game[:left]}")
    option = 0
    input = STDIN.getch()
    while !self.enter(input) && !self.cancel(input)
      if input == "\e"
        input += STDIN.getch + STDIN.getch
        if input === "\e[C"
          option = 1
        elsif input === "\e[D"
          option = 0
        end
        end_state = end_state[0...(end_state.length()-1)] + option.to_s
        render(end_state + "-#{game[:secret_word]}-#{game[:n_attempts] - game[:left]}")
      end
      input = STDIN.getch()
    end
    if self.cancel(input)
      exit
    end
    if option === 0
      main()
    else
      return
    end
  end

  def auto_choose_word()
    min_i = 0
    max_i = @words.length()
    i = (min_i + Random.rand()*(max_i-min_i)).floor()
    secret_word = @words[i]
    while secret_word.length() >= @settings[:min_length] && secret_word.length() <= @settings[:max_length]
      if secret_word.length() > @settings[:max_length]
        max_i = i
      else
        min_i = i+1
      end
      i = (min_i + Random.rand()*(max_i-min_i)).floor()
      secret_word = @words[i]
    end
    return secret_word
  end

  def is_letter(c)
    return (c.ord >= "a".ord && c.ord <= "z".ord) || (c.ord >= "A".ord && c.ord <= "Z".ord)
  end

  def manual_choose_word()
    x = "Enter the word to be guessed (between #{@settings[:min_length]}-#{@settings[:max_length]} letters): ".length
    render("pick_a_word_screen", [x, 2])
    secret_word = ""
    input = STDIN.getch()
    while (!self.enter(input) || !(secret_word.length() >= @settings[:min_length] && secret_word.length() <= @settings[:max_length])) && (!self.cancel(input))
      if self.is_letter(input) && secret_word.length() < @@max_length
        input = input.downcase()
        secret_word += input
        print(input)
      elsif input.ord === 127 && secret_word.length > 0
        secret_word = secret_word[0...(secret_word.length()-1)]
        self.backspace()
      end
      input = STDIN.getch()
    end
    if self.cancel(input)
      main()
    end
    return secret_word
  end

  def eog?(game)
    return (game[:secret_word].length() === game[:progress].length()) || (game[:left] === 0)
  end

  def win?(game)
    return game[:secret_word].length() === game[:progress].length()
  end

  def process(game)
    ans = ""
    game[:secret_word].split("").each.with_index do |l, i|
      if game[:progress].include?(i)
        ans += l
      else
        ans += "_"
      end
    end
    return ans
  end

  def save_game(game)
    self.render("save_screen" + "-#{self.process(game)}-#{game[:left]}", [27, 4])
    input = STDIN.getch()
    save_name = ""
    allowed = [33, 126]
    while !self.cancel(input) && !self.enter(input)
      if input.ord >= allowed[0] && input.ord <= allowed[1]
        save_name += input
        print(input)
      elsif input.ord == 127 && save_name.length > 0
        save_name = save_name[0...(save_name.length()-1)]
        self.backspace()
      end
      input = STDIN.getch()
    end
    if self.cancel(input)
      return
    end
    Dir.mkdir(@@save_path) if !Dir.exist?(@@save_path)
    saves = Dir.open(@@save_path)
    save_name = save_name.length > 0 ? save_name : Time.now().to_s
    fd = IO.sysopen(@@save_path + save_name, "w+")
    newSave = IO.new(fd)
    newSave.print(JSON.generate(game))
    newSave.close
    saves.close
  end

  def load_game(settings)
    dir = Dir.open(@@save_path)
    filenames = []
    saves = Dir.children(@@save_path).map {
        |filename|
        filenames.append(filename)
        f = IO.readlines(@@save_path + filename);
        f = f.join("\n");
        f = JSON.parse(f);
        f = f.transform_keys(&:to_sym)
      
    }
    selected = 0
    render_saves(saves, filenames, selected)
    input = STDIN.getch()
    while !self.enter(input) && !self.cancel(input)
      if input == "\e"
        input += STDIN.getch + STDIN.getch
        if input === "\e[A"
          selected = (selected-1+saves.length()) % saves.length()
        elsif input === "\e[B"
          selected = (selected+1) % saves.length()
        end
        render_saves(saves, filenames, selected)
      end
      input = STDIN.getch()
    end
    if self.cancel(input)
      main()
    end
    game(settings, saves[selected])
  end

  def choose_settings(settings)
    options = [:change_min_length, :change_max_length, :change_n_attempts, :change_mode, :main]
    selected = 0
    while selected != options.length()-1
      render("settings_options#{selected}")
      input = STDIN.getch()
      while !self.enter(input) && !self.cancel(input)
        if input === "\e"
          input += STDIN.getch + STDIN.getch
          if input === "\e[A"
            selected = (selected-1+options.length()) % options.length()
            self.render("settings_options#{selected}")
          elsif input === "\e[B"
            selected = (selected+1) % options.length()
            self.render("settings_options#{selected}")
          end
        end
        input = STDIN.getch()
      end
      if self.cancel(input)
        main()
      end
      selected < options.length-1 ? send(options[selected], selected) : send(options[selected])
    end
  end

  def change_min_length(i)
    restore = @settings[:min_length]
    @settings[:min_length] = nil
    new_length = ""
    self.render("settings_options_selected#{i}-#{new_length}")
    input = STDIN.getch()
    def valid(num)
      return num <= @settings[:max_length]
    end
    while (!self.enter(input) || !valid(new_length.to_i)) && (!self.cancel(input))
      if input.ord >= "0".ord && input.ord <= "9".ord
        if new_length.length() < 2
          new_length += input
          @settings[:min_length] = new_length.to_i
        end
      end
      if input.ord === 127
        new_length = new_length[0...(new_length.length()-1)]
        @settings[:min_length] = new_length.to_i
      end
      self.render("settings_options_selected#{i}-#{new_length}")
      input = STDIN.getch()
    end
    if self.cancel(input)
      @settings[:min_length] = restore
    end
  end

  def change_max_length(i)
    restore = @settings[:max_length]
    @settings[:max_length] = nil
    new_length = ""
    self.render("settings_options_selected#{i}-#{new_length}")
    input = STDIN.getch()
    def valid(num)
      return num <= @@max_length
    end
    while (!self.enter(input) || !valid(new_length.to_i)) && (!self.cancel(input))
      if input.ord >= "0".ord && input.ord <= "9".ord
        if new_length.length() < 2
          new_length += input
          @settings[:max_length] = new_length.to_i
        end
      end
      if input.ord === 127
        new_length = new_length[0...(new_length.length()-1)]
        @settings[:max_length] = new_length.to_i
      end
      self.render("settings_options_selected#{i}-#{new_length}")
      input = STDIN.getch()
    end
    if self.cancel(input)
      @settings[:max_length] = restore
    end
  end

  def change_mode(i)
    @settings[:mode] = @settings[:mode] === :computer ? :manual : :computer
    self.render("settings_options_selected#{i}")
  end

  def change_n_attempts(i)
    restore = @settings[:n_attempts]
    @settings[:n_attempts] = nil
    new_attempts = ""
    self.render("settings_options_selected#{i}-#{new_attempts}")
    input = STDIN.getch()
    def valid(num)
      return num <= "z".ord - "a".ord + 1
    end
    while (!self.enter(input) || !valid(new_attempts.to_i)) && (!self.cancel(input))
      if input.ord >= "0".ord && input.ord <= "9".ord
        if new_attempts.length() < 2
          new_attempts += input
          @settings[:n_attempts] = new_attempts.to_i
        end
      end
      if input.ord === 127
        new_attempts = new_attempts[0...(new_attempts.length()-1)]
        @settings[:n_attempts] = new_attempts.to_i
      end
      self.render("settings_options_selected#{i}-#{new_attempts}")
      input = STDIN.getch()
    end
    if  self.cancel(input)
      @settings[:n_attempts] = restore
    end
  end

  def enter(input)
    return input.ord === 13 || input.ord === 32
  end

  def cancel(input)
    return input.ord === 3
  end

  def backspace()
    print("\033[D \033[D")
  end

  def exit(*none)
    abort("Exiting...")
  end
  
  def render(scene_name, coords = [0, 0])
    system('clear')
    scene = self.get_renders(scene_name)
    print(scene, "\n")
    print("\e[#{coords[1]}F")
    print("\e[#{coords[0]}C")
    return
  end

  def render_saves(saves, names, selected)
    system('clear')
    print("---------- Saved Games ----------", "\n")
    saves.each.with_index do |s, i|
      if i == selected
        print("> ")
      else
        print("  ")
      end
      print("#{names[i]}: ", self.process(s), " Attempts left: ", s[:left], "\n")
    end
    print("---------------------------------\n")
  end
  
  def render_game(game, input)
    system('clear')
    progress = self.process(game)
    left = game[:left]
    guessed = game[:guessed].join(", ") + ";"
    p = (left).to_f/(game[:n_attempts])
    case 1-p
    when -> (n) { n <= 0 }
      scene = "
---------------------- Hangman ----------------------

  
  
  
  
  
  
=========  #{progress} Attempts left: #{left}
           Guess: #{input}   (Press . to save your progress)
Guessed: #{guessed}
-----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 1/17.to_f }
      scene = "
---------------------- Hangman ----------------------

  
  
    
  

  |
=========  #{progress} Attempts left: #{left}
           Guess: #{input}   (Press . to save your progress)
Guessed: #{guessed}
-----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 2/17.to_f }
      scene = "
---------------------- Hangman ----------------------

  
     
         
    
  |  
  |
=========  #{progress} Attempts left: #{left}
           Guess: #{input}   (Press . to save your progress)
Guessed: #{guessed}
-----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 3/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      
         
             
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 4/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      
         
      |       
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 5/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      
      |   
      |       
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 6/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +
      |   
      |       
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 7/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +-
      |   
      |       
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 8/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +--
      |   
      |       
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 9/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---
      |   
      |       
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 10/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   
      |       
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 11/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   |
      |    
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 12/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   |
      |   o    
      |  
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 13/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   |
      |   o    
      |   |
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 14/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   |
      |   o    
      |  /|
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 15/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   |
      |   o    
      |  /|\\
      |  
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 16/17.to_f }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   |
      |   o    
      |  /|\\
      |  / 
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------
"
      print(scene, "\n") 
      return scene
    when -> (n) { n <= 1 }
      scene = "
    ---------------------- Hangman ----------------------
    
      +---+
      |   |
      |   o    
      |  /|\\
      |  / \\
      |
    =========  #{progress} Attempts left: #{left}
               Guess: #{input}   (Press . to save your progress)
    Guessed: #{guessed}
    -----------------------------------------------------"
      print(scene, "\n") 
      return scene
    else
      abort("The game has crashed")
    end
    return
  end

  def get_renders(name)
    case name
    when "main_menu0"
      "
-----------------Welcome to hangman!------------------
                                                 +---+
> Start new game                                 |   |
  Load saved game                                o   |
  Settings                                      /|\\  |
  Exit                                          / \\  |
                                                     |
(Press Enter or Spacebar to select an option)  =========
      "

    when "main_menu1"
      "
-----------------Welcome to hangman!------------------
                                                 +---+
  Start new game                                 |   |
> Load saved game                                o   |
  Settings                                      /|\\  |
  Exit                                          / \\  |
                                                     |
(Press Enter or Spacebar to select an option)  =========
            "

    when "main_menu2"
      "
-----------------Welcome to hangman!------------------
                                                 +---+
  Start new game                                 |   |
  Load saved game                                o   |
> Settings                                      /|\\  |
  Exit                                          / \\  |
                                                     |
(Press Enter or Spacebar to select an option)  =========
            "

    when "main_menu3"
      "
-----------------Welcome to hangman!------------------
                                                 +---+
  Start new game                                 |   |
  Load saved game                                o   |
  Settings                                      /|\\  |
> Exit                                          / \\  |
                                                     |
(Press Enter or Spacebar to select an option)  =========
            "

    when /^win_screen0/
      secret_word, remaining = name.split("-")[1..2]
      "
--------------------- You Won! ---------------------

You guessed #{secret_word} in #{remaining} mistakes!

          > Play Again          Exit

----------------------------------------------------
      "

    when /^win_screen1/
      secret_word, remaining = name.split("-")[1..2]
      "
--------------------- You Won! ---------------------

You guessed #{secret_word} in #{remaining} mistakes!

            Play Again        > Exit

---------------------------------------------------
      "

    when /^lose_screen0/
      secret_word, remaining = name.split("-")[1..2]
      "
--------------------- You Lost! ---------------------

You ran out of guesses. The word was #{secret_word}.

          > Play Again          Exit

-----------------------------------------------------
      "

    when /^lose_screen1/
      secret_word, remaining = name.split("-")[1..2]
      "
--------------------- You Lost! ---------------------

You ran out of guesses. The word was #{secret_word}.

            Play Again        > Exit

-----------------------------------------------------
      "

    when "pick_a_word_screen"
      min_letters, max_letters = @settings[:min_length], @settings[:max_length]
      "
(Make sure your friend isn't watching ^_- )
Enter the word to be guessed (between #{min_letters}-#{max_letters} letters):  
      "

    when /^save_screen/
      progress, left = name.split("-")[1..2]
      "
------------------------------------------------------
Saving: #{progress} #{left}
Pick a name for this save:  
(Press Enter or Space to confirm and Ctrl+C to cancel)
------------------------------------------------------
"

    when "settings_options0"
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
      "
--------------Settings--------------

> Minimum word length: #{min_length}
  Maximum word length: #{max_length}
  Number of attempts: #{n_attempts}
  Mode: #{mode.capitalize}
  Exit Settings
------------------------------------
      "
    when "settings_options1"
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
"
--------------Settings--------------

  Minimum word length: #{min_length}
> Maximum word length: #{max_length}
  Number of attempts: #{n_attempts}
  Mode: #{mode.capitalize}
  Exit Settings
------------------------------------
      "
    when "settings_options2"
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
"
--------------Settings--------------

  Minimum word length: #{min_length}
  Maximum word length: #{max_length}
> Number of attempts: #{n_attempts}
  Mode: #{mode.capitalize}
  Exit Settings
------------------------------------
      "
    when "settings_options3"
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
"
--------------Settings--------------

  Minimum word length: #{min_length}
  Maximum word length: #{max_length}
  Number of attempts: #{n_attempts}
> Mode: #{mode.capitalize}
  Exit Settings
------------------------------------
      "
    when "settings_options4"
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
"
--------------Settings--------------

  Minimum word length: #{min_length}
  Maximum word length: #{max_length}
  Number of attempts: #{n_attempts}
  Mode: #{mode.capitalize}
> Exit Settings
------------------------------------
      "
    when /settings_options_selected0/
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
      "
--------------Settings--------------

> Minimum word length:  #{min_length}
  Maximum word length: #{max_length}
  Number of attempts: #{n_attempts}
  Mode: #{mode.capitalize}
  Exit Settings
------------------------------------
      "
    when /settings_options_selected1/
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
      "
--------------Settings--------------

  Minimum word length: #{min_length}
> Maximum word length:  #{max_length}
  Number of attempts: #{n_attempts}
  Mode: #{mode.capitalize}
  Exit Settings
------------------------------------
      "

    when /settings_options_selected2/
      min_length, max_length, n_attempts, mode = @settings[:min_length], @settings[:max_length], @settings[:n_attempts], @settings[:mode]
      "
--------------Settings--------------

  Minimum word length: #{min_length}
  Maximum word length: #{max_length}
> Number of attempts:  #{n_attempts}
  Mode: #{mode.capitalize}
  Exit Settings
------------------------------------
      "
    
    else
      "Error - Scene doesn't exist"
    end
  end

end

game = Hangman.new()
game.main()

