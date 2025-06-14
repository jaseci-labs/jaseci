glob readline = require('readline');

# Set up command line input/output
 glob rl =
    readline.createInterface({"input" : process.stdin , "output" : process.stdout } );


def function(name: str) {
    if (name) {
        console.log("Hello, " + name + "!");
    } else {
        console.log("Hello, stranger!");
    }
    rl.close();
}


# Ask the user for their name
 with entry {
    rl.question("What is your name? ", );
}
