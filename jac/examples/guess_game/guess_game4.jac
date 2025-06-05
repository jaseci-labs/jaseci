"""A Number Guessing Game"""
import random;


obj Game {
    has correct_number: int;
    has attempts: int;
    has won: bool = False;
    
    def play;
}


obj GuessTheNumberGame (Game) {    
    def init;
    override def play;
    def process_guess(guess: int);
}




# Run the game
 with entry {
    game = |> GuessTheNumberGame;
    |> game.play;
}
