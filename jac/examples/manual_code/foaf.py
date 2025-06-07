# Traditional Python approach
class User:
    def __init__(self, name):
        self.name = name
        self.friends = []

    def add_friend(self, friend):
        self.friends.append(friend)
        friend.friends.append(self)

# Processing requires external traversal logic
def find_friends_of_friends(user):
    fof = set()
    for friend in user.friends:
        for friend_of_friend in friend.friends:
            if friend_of_friend != user:
                fof.add(friend_of_friend)


    print(f"Friends of {user.name}'s friends:", [user.name for user in fof])
    return fof


# Create users
alice = User("Alice")
bob = User("Bob")
carol = User("Carol")
dave = User("Dave")

# Build friendship connections
alice.add_friend(bob)   
bob.add_friend(carol)   
carol.add_friend(dave)

# Test the function
find_friends_of_friends(alice)