"""A Number Guessing Game"""

import random;


obj Game {
    has attempts: int, won: bool = False;

    def play {
        raise "Subclasses must implement this method." |> NotImplementedError ;
    }
}


obj GuessTheNumberGame (Game) {
    has attempts: int = 10, correct_number: int = (1, 10) |> random.randint;

    override def play {
        while self.attempts > 0 {
            guess = "Guess a number between 1 and 10: " |> input;
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

    def process_guess(guess: int) {
        if guess > self.correct_number {
            "Too high!" |> print;
            self.attempts -= 1;
        } elif guess < self.correct_number {
            "Too low!" |> print;
            self.attempts -= 1;
        } else {
            "Congratulations! You guessed correctly." |> print;
            self.won = True;
            self.attempts = 0;
            return;
        }
    f"You have {self.attempts} attempts left." |> print;
}

}


# Run the game
 with entry {
    game = |> GuessTheNumberGame;
    |> game.play;
}