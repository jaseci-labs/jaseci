# Jac's Data Spatial approach
node User {
    has name: str;
}

edge Friendship {}

walker FindFriendsOfFriends {
    has visited: set = set();
    has friends_of_friends: set = set();

    can traverse with entry {
        if here in self.visited { return; }
        self.visited.add(here);

        # First hop: direct friends
        for friend in [->:Friendship:->(`?User)] {
            # Second hop: friends of friends
            for fof in [friend->:Friendship:->(`?User)] {
                if fof != root {  # root is the starting user
                    self.friends_of_friends.add(fof);
                }
            }
        }

        print(f"Friends of {here.name}'s friends:", 
              [fof.name for foaf in self.friends_of_friends]);
    }
}

with entry {
    alice = User(name = "Alice");

    # Build friendship connections
    alice +>:Friendship:+> User(name = "Bob")
          +>:Friendship:+> User(name = "Carol")
          +>:Friendship:+> User(name = "Dave");


    FindFriendsOfFriends() spawn alice;
}