# Chapter 12: Advanced Object Spatial Operations

Now that you understand walkers, abilities, and basic graph operations, it's time to explore advanced patterns that unlock the full power of Object-Spatial Programming. This chapter covers sophisticated traversal patterns, filtering techniques, and complex graph algorithms using our familiar social network examples.

!!! topic "Advanced Graph Algorithms"
    Complex graph operations become surprisingly simple when computation moves to data. Instead of loading entire datasets, walkers intelligently navigate only the relevant portions of your graph.

## Visit Patterns

!!! topic "Intelligent Navigation"
    Advanced visit patterns allow walkers to make smart decisions about where to go next, enabling sophisticated algorithms with minimal code.

### Conditional Visit Patterns

!!! example "Smart Friend Discovery"
    === "Jac"
        <div class="code-block">
        ```jac
        node Person {
            has name: str;
            has age: int;
            has interests: list[str] = [];
            has city: str;
        }

        edge FriendsWith {
            has since: str;
            has closeness: int = 5;  # 1-10 scale
        }

        walker SmartFriendFinder {
            has target_age_range: tuple[int, int];
            has required_interests: list[str];
            has max_distance: int = 2;
            has current_distance: int = 0;
            has potential_friends: list[Person] = [];

            can find_compatible_friends with Person entry {
                # Check if this person matches our criteria
                if self.is_compatible(here) and self.current_distance > 0 {
                    self.potential_friends.append(here);
                    print(f"Found compatible friend: {here.name} (distance: {self.current_distance})");
                }

                # Continue searching if within distance limit
                if self.current_distance < self.max_distance {
                    # Only visit close friends (closeness >= 7)
                    close_friends = [-->:FriendsWith:(?closeness >= 7):-->];

                    if close_friends {
                        self.current_distance += 1;
                        visit close_friends;
                        self.current_distance -= 1;  # Backtrack
                    }
                }
            }

            def is_compatible(person: Person) -> bool {
                # Check age range
                min_age, max_age = self.target_age_range;
                if not (min_age <= person.age <= max_age) {
                    return False;
                }

                # Check common interests
                common_interests = set(person.interests) & set(self.required_interests);
                return len(common_interests) >= 1;
            }
        }

        with entry {
            # Create a social network
            alice = root ++> Person(name="Alice", age=25, interests=["coding", "music"], city="NYC");
            bob = root ++> Person(name="Bob", age=27, interests=["music", "sports"], city="NYC");
            charlie = root ++> Person(name="Charlie", age=24, interests=["coding", "art"], city="SF");
            diana = root ++> Person(name="Diana", age=26, interests=["music", "travel"], city="NYC");

            # Create friendships with different closeness levels
            alice ++>:FriendsWith(since="2023-01-01", closeness=8):++> bob;
            bob ++>:FriendsWith(since="2023-02-01", closeness=9):++> diana;
            alice ++>:FriendsWith(since="2023-03-01", closeness=6):++> charlie;

            # Find friends for Alice who like music and are 25-28 years old
            finder = SmartFriendFinder(
                target_age_range=(25, 28),
                required_interests=["music"],
                max_distance=2
            );

            alice spawn finder;

            print(f"Found {len(finder.potential_friends)} compatible friends");
            for friend in finder.potential_friends {
                print(f"  - {friend.name} (age {friend.age}) likes: {friend.interests}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Tuple, Set

        class Person:
            def __init__(self, name: str, age: int, interests: List[str], city: str):
                self.name = name
                self.age = age
                self.interests = interests
                self.city = city
                self.friends = []

        class Friendship:
            def __init__(self, person1: Person, person2: Person, since: str, closeness: int):
                self.person1 = person1
                self.person2 = person2
                self.since = since
                self.closeness = closeness

                # Add bidirectional friendship
                person1.friends.append((person2, self))
                person2.friends.append((person1, self))

        class SmartFriendFinder:
            def __init__(self, target_age_range: Tuple[int, int], required_interests: List[str], max_distance: int = 2):
                self.target_age_range = target_age_range
                self.required_interests = required_interests
                self.max_distance = max_distance
                self.potential_friends = []
                self.visited = set()

            def find_compatible_friends(self, start_person: Person):
                self._search_recursive(start_person, 0)

            def _search_recursive(self, person: Person, current_distance: int):
                if person in self.visited:
                    return

                self.visited.add(person)

                # Check if this person matches our criteria (but not starting person)
                if self.is_compatible(person) and current_distance > 0:
                    self.potential_friends.append(person)
                    print(f"Found compatible friend: {person.name} (distance: {current_distance})")

                # Continue searching if within distance limit
                if current_distance < self.max_distance:
                    # Only visit close friends (closeness >= 7)
                    for friend, friendship in person.friends:
                        if friendship.closeness >= 7 and friend not in self.visited:
                            self._search_recursive(friend, current_distance + 1)

            def is_compatible(self, person: Person) -> bool:
                # Check age range
                min_age, max_age = self.target_age_range
                if not (min_age <= person.age <= max_age):
                    return False

                # Check common interests
                common_interests = set(person.interests) & set(self.required_interests)
                return len(common_interests) >= 1

        if __name__ == "__main__":
            # Create a social network
            alice = Person("Alice", 25, ["coding", "music"], "NYC")
            bob = Person("Bob", 27, ["music", "sports"], "NYC")
            charlie = Person("Charlie", 24, ["coding", "art"], "SF")
            diana = Person("Diana", 26, ["music", "travel"], "NYC")

            # Create friendships with different closeness levels
            Friendship(alice, bob, "2023-01-01", 8)
            Friendship(bob, diana, "2023-02-01", 9)
            Friendship(alice, charlie, "2023-03-01", 6)

            # Find friends for Alice who like music and are 25-28 years old
            finder = SmartFriendFinder(
                target_age_range=(25, 28),
                required_interests=["music"],
                max_distance=2
            )

            finder.find_compatible_friends(alice)

            print(f"Found {len(finder.potential_friends)} compatible friends")
            for friend in finder.potential_friends:
                print(f"  - {friend.name} (age {friend.age}) likes: {friend.interests}")
        ```

### Multi-Path Exploration

!!! example "Finding Alternative Paths"
    === "Jac"
        <div class="code-block">
        ```jac
        walker PathFinder {
            has target_person: str;
            has current_path: list[str] = [];
            has all_paths: list[list[str]] = [];
            has max_depth: int = 4;

            can explore_paths with Person entry {
                # Add current person to path
                self.current_path.append(here.name);

                # Found target!
                if here.name == self.target_person {
                    # Save a copy of current path
                    path_copy = self.current_path.copy();
                    self.all_paths.append(path_copy);
                    print(f"Path found: {' -> '.join(path_copy)}");

                    # Remove from path and return
                    self.current_path.pop();
                    return;
                }

                # Continue exploring if not too deep
                if len(self.current_path) < self.max_depth {
                    # Get all friends we haven't visited in current path
                    friends = [-->:FriendsWith:-->];
                    unvisited_friends = [f for f in friends if f.name not in self.current_path];

                    # Visit each unvisited friend
                    for friend in unvisited_friends {
                        visit friend;
                    }
                }

                # Backtrack: remove current person from path
                self.current_path.pop();
            }
        }

        with entry {
            # Create a more complex network
            alice = root ++> Person(name="Alice", age=25, interests=["coding"], city="NYC");
            bob = root ++> Person(name="Bob", age=27, interests=["music"], city="NYC");
            charlie = root ++> Person(name="Charlie", age=24, interests=["art"], city="SF");
            diana = root ++> Person(name="Diana", age=26, interests=["travel"], city="NYC");
            eve = root ++> Person(name="Eve", age=23, interests=["coding"], city="LA");

            # Create multiple connection paths
            alice ++>:FriendsWith(since="2023-01-01", closeness=8):++> bob;
            alice ++>:FriendsWith(since="2023-02-01", closeness=7):++> charlie;
            bob ++>:FriendsWith(since="2023-03-01", closeness=9):++> diana;
            charlie ++>:FriendsWith(since="2023-04-01", closeness=6):++> eve;
            diana ++>:FriendsWith(since="2023-05-01", closeness=8):++> eve;

            # Find all paths from Alice to Eve
            path_finder = PathFinder(target_person="Eve", max_depth=4);
            alice spawn path_finder;

            print(f"\nFound {len(path_finder.all_paths)} different paths:");
            for i, path in enumerate(path_finder.all_paths, 1) {
                print(f"  Path {i}: {' -> '.join(path)}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        class PathFinder:
            def __init__(self, target_person: str, max_depth: int = 4):
                self.target_person = target_person
                self.max_depth = max_depth
                self.all_paths = []

            def find_all_paths(self, start_person: Person):
                current_path = []
                self._explore_recursive(start_person, current_path)

            def _explore_recursive(self, person: Person, current_path: List[str]):
                # Add current person to path
                current_path.append(person.name)

                # Found target!
                if person.name == self.target_person:
                    # Save a copy of current path
                    self.all_paths.append(current_path.copy())
                    print(f"Path found: {' -> '.join(current_path)}")

                    # Remove from path and return
                    current_path.pop()
                    return

                # Continue exploring if not too deep
                if len(current_path) < self.max_depth:
                    # Get all friends we haven't visited in current path
                    unvisited_friends = [
                        friend for friend, _ in person.friends
                        if friend.name not in current_path
                    ]

                    # Visit each unvisited friend
                    for friend in unvisited_friends:
                        self._explore_recursive(friend, current_path)

                # Backtrack: remove current person from path
                current_path.pop()

        if __name__ == "__main__":
            # Create a more complex network
            alice = Person("Alice", 25, ["coding"], "NYC")
            bob = Person("Bob", 27, ["music"], "NYC")
            charlie = Person("Charlie", 24, ["art"], "SF")
            diana = Person("Diana", 26, ["travel"], "NYC")
            eve = Person("Eve", 23, ["coding"], "LA")

            # Create multiple connection paths
            Friendship(alice, bob, "2023-01-01", 8)
            Friendship(alice, charlie, "2023-02-01", 7)
            Friendship(bob, diana, "2023-03-01", 9)
            Friendship(charlie, eve, "2023-04-01", 6)
            Friendship(diana, eve, "2023-05-01", 8)

            # Find all paths from Alice to Eve
            path_finder = PathFinder(target_person="Eve", max_depth=4)
            path_finder.find_all_paths(alice)

            print(f"\nFound {len(path_finder.all_paths)} different paths:")
            for i, path in enumerate(path_finder.all_paths, 1):
                print(f"  Path {i}: {' -> '.join(path)}")
        ```

## Advanced Filtering

!!! topic "Sophisticated Query Patterns"
    Advanced filtering combines multiple criteria and complex logic to find exactly the data you need, making database-like queries natural in graph structures.

### Complex Multi-Criteria Filtering

!!! example "Advanced Friend Matching"
    === "Jac"
        <div class="code-block">
        ```jac
        node Post {
            has content: str;
            has timestamp: str;
            has likes: int = 0;
            has tags: list[str] = [];
        }

        edge Posted {
            has device: str = "web";
        }

        edge Likes {
            has timestamp: str;
        }

        walker InfluencerFinder {
            has min_followers: int;
            has min_engagement: float;
            has required_interests: list[str];
            has influencers: list[Person] = [];

            can find_influencers with Person entry {
                # Count followers
                followers = [<--:FriendsWith:<--];
                follower_count = len(followers);

                if follower_count < self.min_followers {
                    return;  # Skip if not enough followers
                }

                # Check interests overlap
                common_interests = set(here.interests) & set(self.required_interests);
                if len(common_interests) == 0 {
                    return;  # Skip if no common interests
                }

                # Calculate engagement rate
                posts = [-->:Posted:-->:Post:];
                if len(posts) == 0 {
                    return;  # Skip if no posts
                }

                total_likes = sum(post.likes for post in posts);
                engagement_rate = total_likes / (follower_count * len(posts));

                if engagement_rate >= self.min_engagement {
                    self.influencers.append(here);
                    print(f"Found influencer: {here.name}");
                    print(f"  Followers: {follower_count}");
                    print(f"  Posts: {len(posts)}");
                    print(f"  Engagement Rate: {engagement_rate:.2f}");
                    print(f"  Common interests: {list(common_interests)}");
                }
            }
        }

        with entry {
            # Create people with different follower counts and engagement
            alice = root ++> Person(name="Alice", age=28, interests=["tech", "music"], city="SF");
            bob = root ++> Person(name="Bob", age=25, interests=["music", "travel"], city="NYC");
            charlie = root ++> Person(name="Charlie", age=30, interests=["tech", "sports"], city="LA");

            # Create followers
            follower1 = root ++> Person(name="Fan1", age=22, interests=["music"], city="NYC");
            follower2 = root ++> Person(name="Fan2", age=24, interests=["tech"], city="SF");
            follower3 = root ++> Person(name="Fan3", age=26, interests=["travel"], city="LA");
            follower4 = root ++> Person(name="Fan4", age=21, interests=["sports"], city="NYC");

            # Create follow relationships
            follower1 ++>:FriendsWith(since="2023-01-01", closeness=6):++> alice;
            follower2 ++>:FriendsWith(since="2023-01-15", closeness=7):++> alice;
            follower3 ++>:FriendsWith(since="2023-02-01", closeness=5):++> bob;
            follower4 ++>:FriendsWith(since="2023-02-15", closeness=8):++> charlie;

            # Create posts with different engagement
            alice ++>:Posted(device="mobile"):++> Post(content="Tech tips!", likes=50, tags=["tech"]);
            alice ++>:Posted(device="web"):++> Post(content="Music review", likes=30, tags=["music"]);
            bob ++>:Posted(device="mobile"):++> Post(content="Travel blog", likes=10, tags=["travel"]);
            charlie ++>:Posted(device="web"):++> Post(content="Sports update", likes=5, tags=["sports"]);

            # Find influencers with at least 2 followers, 2.0 engagement rate, interested in tech
            finder = InfluencerFinder(
                min_followers=2,
                min_engagement=2.0,
                required_interests=["tech"]
            );

            # Check all people
            all_people = [root-->:Person:];
            for person in all_people {
                person spawn finder;
            }

            print(f"\nFound {len(finder.influencers)} influencers matching criteria");
        }
        ```
        </div>
    === "Python"
        ```python
        class Post:
            def __init__(self, content: str, likes: int = 0, tags: List[str] = None):
                self.content = content
                self.likes = likes
                self.tags = tags or []

        class InfluencerFinder:
            def __init__(self, min_followers: int, min_engagement: float, required_interests: List[str]):
                self.min_followers = min_followers
                self.min_engagement = min_engagement
                self.required_interests = required_interests
                self.influencers = []

            def evaluate_person(self, person: Person, all_people: List[Person], posts_by_person: dict):
                # Count followers (people who follow this person)
                followers = [
                    p for p in all_people
                    for friend, _ in p.friends
                    if friend == person
                ]
                follower_count = len(followers)

                if follower_count < self.min_followers:
                    return  # Skip if not enough followers

                # Check interests overlap
                common_interests = set(person.interests) & set(self.required_interests)
                if len(common_interests) == 0:
                    return  # Skip if no common interests

                # Calculate engagement rate
                posts = posts_by_person.get(person, [])
                if len(posts) == 0:
                    return  # Skip if no posts

                total_likes = sum(post.likes for post in posts)
                engagement_rate = total_likes / (follower_count * len(posts))

                if engagement_rate >= self.min_engagement:
                    self.influencers.append(person)
                    print(f"Found influencer: {person.name}")
                    print(f"  Followers: {follower_count}")
                    print(f"  Posts: {len(posts)}")
                    print(f"  Engagement Rate: {engagement_rate:.2f}")
                    print(f"  Common interests: {list(common_interests)}")

        if __name__ == "__main__":
            # Create people with different follower counts and engagement
            alice = Person("Alice", 28, ["tech", "music"], "SF")
            bob = Person("Bob", 25, ["music", "travel"], "NYC")
            charlie = Person("Charlie", 30, ["tech", "sports"], "LA")

            # Create followers
            follower1 = Person("Fan1", 22, ["music"], "NYC")
            follower2 = Person("Fan2", 24, ["tech"], "SF")
            follower3 = Person("Fan3", 26, ["travel"], "LA")
            follower4 = Person("Fan4", 21, ["sports"], "NYC")

            # Create follow relationships
            Friendship(follower1, alice, "2023-01-01", 6)
            Friendship(follower2, alice, "2023-01-15", 7)
            Friendship(follower3, bob, "2023-02-01", 5)
            Friendship(follower4, charlie, "2023-02-15", 8)

            # Create posts with different engagement
            posts_by_person = {
                alice: [
                    Post("Tech tips!", 50, ["tech"]),
                    Post("Music review", 30, ["music"])
                ],
                bob: [Post("Travel blog", 10, ["travel"])],
                charlie: [Post("Sports update", 5, ["sports"])]
            }

            # Find influencers with at least 2 followers, 2.0 engagement rate, interested in tech
            finder = InfluencerFinder(
                min_followers=2,
                min_engagement=2.0,
                required_interests=["tech"]
            )

            # Check all people
            all_people = [alice, bob, charlie, follower1, follower2, follower3, follower4]
            for person in all_people:
                finder.evaluate_person(person, all_people, posts_by_person)

            print(f"\nFound {len(finder.influencers)} influencers matching criteria")
        ```

## Complex Traversal Patterns

!!! topic "Sophisticated Graph Algorithms"
    Complex traversal patterns enable advanced algorithms like recommendation systems, community detection, and influence analysis with surprisingly simple code.

### Social Recommendation System

!!! example "Friend-of-Friend Recommendations"
    === "Jac"
        <div class="code-block">
        ```jac
        walker RecommendationEngine {
            has user_interests: list[str];
            has user_location: str;
            has recommendations: list[dict] = [];
            has visited_friends: set[str] = {};

            can analyze_user with Person entry {
                # Store user's profile for comparison
                self.user_interests = here.interests;
                self.user_location = here.city;

                # Get direct friends
                direct_friends = [-->:FriendsWith:-->];
                for friend in direct_friends {
                    self.visited_friends.add(friend.name);
                }

                print(f"Analyzing recommendations for {here.name}");
                print(f"  Interests: {self.user_interests}");
                print(f"  Location: {self.user_location}");
                print(f"  Current friends: {[f.name for f in direct_friends]}");

                # Explore friends of friends
                visit direct_friends;
            }

            can explore_network with Person entry {
                # Look at this person's friends (potential recommendations)
                friends_of_friend = [-->:FriendsWith:-->];

                for potential_friend in friends_of_friend {
                    # Skip if already a direct friend
                    if potential_friend.name in self.visited_friends {
                        continue;
                    }

                    # Calculate recommendation score
                    score = self.calculate_compatibility_score(potential_friend);

                    if score > 0.5 {  # Threshold for recommendation
                        # Find mutual friends
                        mutual_friends = self.find_mutual_connections(potential_friend);

                        recommendation = {
                            "name": potential_friend.name,
                            "age": potential_friend.age,
                            "city": potential_friend.city,
                            "interests": potential_friend.interests,
                            "score": score,
                            "mutual_friends": mutual_friends,
                            "reason": self.generate_reason(potential_friend, score)
                        };

                        self.recommendations.append(recommendation);
                        print(f"  Potential friend: {potential_friend.name} (score: {score:.2f})");
                }
            }

            def calculate_compatibility_score(person: Person) -> float {
                score = 0.0;

                # Interest similarity (40% weight)
                common_interests = set(self.user_interests) & set(person.interests);
                interest_score = len(common_interests) / max(len(self.user_interests), 1);
                score += interest_score * 0.4;

                # Location proximity (30% weight)
                if person.city == self.user_location {
                    score += 0.3;
                }

                # Age similarity (30% weight) - within 5 years
                # Note: We'll assume user age for this simple example
                age_diff = abs(person.age - 26);  # Assuming user is 26
                if age_diff <= 5 {
                    age_score = (5 - age_diff) / 5;
                    score += age_score * 0.3;
                }

                return score;
            }

            def find_mutual_connections(person: Person) -> list[str] {
                # This is simplified - in real implementation would traverse graph
                return ["mutual friend example"];
            }

            def generate_reason(person: Person, score: float) -> str {
                common_interests = set(self.user_interests) & set(person.interests);
                reasons = [];

                if common_interests {
                    reasons.append(f"shares interests in {', '.join(list(common_interests))}");
                }

                if person.city == self.user_location {
                    reasons.append(f"lives in {person.city}");
                }

                return "; ".join(reasons) if reasons else "general compatibility";
            }
        }

        with entry {
            # Create a social network for recommendations
            user = root ++> Person(name="User", age=26, interests=["tech", "music"], city="SF");

            # Direct friends
            friend1 = root ++> Person(name="Alice", age=25, interests=["tech", "art"], city="SF");
            friend2 = root ++> Person(name="Bob", age=28, interests=["music", "sports"], city="NYC");

            # Friends of friends (potential recommendations)
            potential1 = root ++> Person(name="Charlie", age=24, interests=["tech", "music"], city="SF");
            potential2 = root ++> Person(name="Diana", age=30, interests=["art", "travel"], city="SF");
            potential3 = root ++> Person(name="Eve", age=27, interests=["music", "cooking"], city="LA");

            # Create friendship network
            user ++>:FriendsWith(since="2023-01-01", closeness=8):++> friend1;
            user ++>:FriendsWith(since="2023-02-01", closeness=7):++> friend2;

            # Friends of friends
            friend1 ++>:FriendsWith(since="2023-03-01", closeness=9):++> potential1;
            friend1 ++>:FriendsWith(since="2023-04-01", closeness=6):++> potential2;
            friend2 ++>:FriendsWith(since="2023-05-01", closeness=8):++> potential3;

            # Generate recommendations
            engine = RecommendationEngine();
            user spawn engine;

            # Sort recommendations by score
            engine.recommendations.sort(key=lambda r: dict -> float : r["score"], reverse=True);

            print(f"\n=== Top Recommendations ===");
            for i, rec in enumerate(engine.recommendations[:3], 1) {
                print(f"{i}. {rec['name']} (Score: {rec['score']:.2f})");
                print(f"   Age: {rec['age']}, City: {rec['city']}");
                print(f"   Interests: {rec['interests']}");
                print(f"   Reason: {rec['reason']}");
                print();
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Dict, Set

        class RecommendationEngine:
            def __init__(self):
                self.user_interests = []
                self.user_location = ""
                self.recommendations = []
                self.visited_friends = set()

            def generate_recommendations(self, user: Person, network: List[Person], friendships: List[Friendship]):
                self.user_interests = user.interests
                self.user_location = user.city

                # Get direct friends
                direct_friends = []
                for friendship in friendships:
                    if friendship.person1 == user:
                        direct_friends.append(friendship.person2)
                        self.visited_friends.add(friendship.person2.name)
                    elif friendship.person2 == user:
                        direct_friends.append(friendship.person1)
                        self.visited_friends.add(friendship.person1.name)

                print(f"Analyzing recommendations for {user.name}")
                print(f"  Interests: {self.user_interests}")
                print(f"  Location: {self.user_location}")
                print(f"  Current friends: {[f.name for f in direct_friends]}")

                # Explore friends of friends
                for friend in direct_friends:
                    self.explore_friend_network(friend, friendships)

            def explore_friend_network(self, friend: Person, friendships: List[Friendship]):
                # Get this friend's connections
                for friendship in friendships:
                    potential_friend = None
                    if friendship.person1 == friend:
                        potential_friend = friendship.person2
                    elif friendship.person2 == friend:
                        potential_friend = friendship.person1

                    if potential_friend and potential_friend.name not in self.visited_friends:
                        score = self.calculate_compatibility_score(potential_friend)

                        if score > 0.5:
                            recommendation = {
                                "name": potential_friend.name,
                                "age": potential_friend.age,
                                "city": potential_friend.city,
                                "interests": potential_friend.interests,
                                "score": score,
                                "mutual_friends": ["mutual friend example"],
                                "reason": self.generate_reason(potential_friend, score)
                            }

                            self.recommendations.append(recommendation)
                            print(f"  Potential friend: {potential_friend.name} (score: {score:.2f})")

            def calculate_compatibility_score(self, person: Person) -> float:
                score = 0.0

                # Interest similarity (40% weight)
                common_interests = set(self.user_interests) & set(person.interests)
                interest_score = len(common_interests) / max(len(self.user_interests), 1)
                score += interest_score * 0.4

                # Location proximity (30% weight)
                if person.city == self.user_location:
                    score += 0.3

                # Age similarity (30% weight) - within 5 years
                age_diff = abs(person.age - 26)  # Assuming user is 26
                if age_diff <= 5:
                    age_score = (5 - age_diff) / 5
                    score += age_score * 0.3

                return score

            def generate_reason(self, person: Person, score: float) -> str:
                common_interests = set(self.user_interests) & set(person.interests)
                reasons = []

                if common_interests:
                    reasons.append(f"shares interests in {', '.join(list(common_interests))}")

                if person.city == self.user_location:
                    reasons.append(f"lives in {person.city}")

                return "; ".join(reasons) if reasons else "general compatibility"

        if __name__ == "__main__":
            # Create a social network for recommendations
            user = Person("User", 26, ["tech", "music"], "SF")

            # Direct friends
            friend1 = Person("Alice", 25, ["tech", "art"], "SF")
            friend2 = Person("Bob", 28, ["music", "sports"], "NYC")

            # Friends of friends (potential recommendations)
            potential1 = Person("Charlie", 24, ["tech", "music"], "SF")
            potential2 = Person("Diana", 30, ["art", "travel"], "SF")
            potential3 = Person("Eve", 27, ["music", "cooking"], "LA")

            # Create friendship network
            friendships = [
                Friendship(user, friend1, "2023-01-01", 8),
                Friendship(user, friend2, "2023-02-01", 7),
                Friendship(friend1, potential1, "2023-03-01", 9),
                Friendship(friend1, potential2, "2023-04-01", 6),
                Friendship(friend2, potential3, "2023-05-01", 8)
            ]

            # Generate recommendations
            engine = RecommendationEngine()
            all_people = [user, friend1, friend2, potential1, potential2, potential3]
            engine.generate_recommendations(user, all_people, friendships)

            # Sort recommendations by score
            engine.recommendations.sort(key=lambda r: r["score"], reverse=True)

            print(f"\n=== Top Recommendations ===")
            for i, rec in enumerate(engine.recommendations[:3], 1):
                print(f"{i}. {rec['name']} (Score: {rec['score']:.2f})")
                print(f"   Age: {rec['age']}, City: {rec['city']}")
                print(f"   Interests: {rec['interests']}")
                print(f"   Reason: {rec['reason']}")
                print()
        ```

## Best Practices for Advanced Operations

!!! summary "Design Guidelines"
    - **Plan traversal depth**: Use depth limits to prevent infinite loops
    - **Cache expensive calculations**: Store results in walker state
    - **Use early returns**: Skip unnecessary processing with guards
    - **Implement backtracking**: Remove items from paths when backtracking
    - **Optimize filters**: Apply most selective filters first

## Key Takeaways

!!! summary "Chapter Summary"
    - **Smart visiting patterns** enable conditional and multi-path exploration
    - **Advanced filtering** combines multiple criteria for sophisticated queries
    - **Complex traversals** make advanced algorithms like recommendations simple
    - **Walker state management** enables backtracking and path discovery
    - **Object-spatial operations** naturally express graph algorithms

Advanced object-spatial operations transform complex graph problems into intuitive, maintainable code. By moving computation to data and leveraging spatial relationships, algorithms that would require hundreds of lines in traditional approaches become concise and expressive.

In the next chapter, we'll explore persistence and the root node - features that make your spatial programs automatically persist state and scale from single-user scripts to multi-user applications.
