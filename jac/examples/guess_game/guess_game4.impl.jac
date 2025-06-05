impl Game.play {
    raise "Subclasses must implement this method." |> NotImplementedError ;
}


impl GuessTheNumberGame.init {
    self.attempts = 10;
    self.correct_number = (1, 100) |> random.randint;
}


impl GuessTheNumberGame.play {
    while self.attempts > 0 {
        guess = "Guess a number between 1 and 100: " |> input;
        if |> guess.isdigit {
            guess |> int |> self.process_guess;
        } else {
            "That's not a valid number! Try again." |> print;
        }
    }
    if not self.won {
        "Sorry, you didn't guess the number. Better luck next time!" |> print;
    }
}


impl GuessTheNumberGame.process_guess (guess: int) {
    if guess > self.correct_number {
        "Too high!" |> print;
    } elif guess < self.correct_number {
        "Too low!" |> print;
    } else {
        "Congratulations! You guessed correctly." |> print;
        self.attempts = 0;
        # end the game
        self.won = True;
        return;
    }
    self.attempts -= 1;
    f"You have {self.attempts} attempts left." |> print;
}
