#FILES = ["A_2.csv", "B_2.csv"]
POS_MAX = [2, 2, 2, 4, 2, 2]
 
memo = {}
 
invocations = 0
 
def get_players():
    players = []
 
    with open(FILES[0], "r") as f_1:
        positions = f_1.readlines()
 
    with open(FILES[1], "r") as f_2:
        points = f_2.readlines()
 
    for i in range(len(positions)):
        players.append({
            "idx": i,
            "pos":  [int(x) for x in positions[i].split(',')],
            "pts": float(points[i].strip())
        })
 
    return players
 
def filter_players(players, filter):
    filtered_list = []
 
    for p in players:
        for i in range(len(filter)):
            if p["pos"][i] == 1 and filter[i] == 1:
                filtered_list.append(p)
                break
 
    return filtered_list
 
 
def is_player_in_list(player_list, player):
    for p in player_list:
        if p == player["idx"]:
            return True
 
    return False
 
 
def get_max(one_pts, one_players, two_pts, two_players):
    if one_pts > two_pts:
        return one_pts, one_players
 
    return two_pts, two_players
 
# def print_data(chosen):
#     length = len(chosen)
#     global invocations
#     invocations += 1
 
#     if invocations % 1000000 == 0:
#         print("Chosen Length:", length, " - Invocations:", invocations)
#         print(chosen)
 
#     if length > 14:
#         print("Problem: ", length)
 
 
def get_unique_string(chosen, positions):
    chosen.sort()
 
    return ', '.join(map(str, chosen)) + ', '.join(map(str, positions))
 
 
 
def choose_roster(chosen, positions, players):
    if len(chosen) == 14:
        return 0, []
 
    uuid = get_unique_string(chosen, positions)
 
    if memo.get(uuid) is not None:
        return memo.get(uuid)
 
    # print_data(chosen)
 
    max_pts = 0
    chosen_players = chosen.copy()
 
    # Loop over all players
    for p in players:
 
        # Ignore players already "chosen"
        if is_player_in_list(chosen, p):
            continue
 
        # Try and fit current player into any of their available positions
        for idx in range(len(positions)):
 
            # Ignore the positions they cannot go into either by 1. Not being available for that position, or no room left for that position
            if p["pos"][idx] == 0 or positions[idx] < 1:
                continue
 
            # Copy this current list of chosen people and append the current player to it
            this_chosen = chosen.copy()
            this_chosen.append(p["idx"])
 
            # Copy the positions and account for the new player added to the roster
            this_positions = positions.copy()
            this_positions[idx] -= 1
 
            # Recurse and add current player points to it
            this_max, this_chosen = choose_roster(this_chosen, this_positions, players)
            this_max += p["pts"]
 
            # Keep track of highest points
            max_pts, chosen_players = get_max(max_pts, chosen_players, this_max, this_chosen)
    
    memo[uuid] = (max_pts, chosen_players)
 
    return max_pts, chosen_players
 
 
# players = get_players()
# print(players)
 
# forwards = filter_players(players, [1,1,1,0,0,0])
# defence = filter_players(players, [0,0,0,1,0,0])
# goalies = filter_players(players, [0,0,0,0,0,1])
# print("Number of forwards: ", len(forwards))
# print("Number of defence: ",  len(defence))
# print("Number of goalies: ",  len(goalies))
 
# forward_sols = []
# defence_sols = []
# # Loop through number of utils 0,1,2
# for num_util in range(3):
#     print("Forwards: ", num_util)
#     forward_sols.append(choose_roster([],[2,2,2,0,num_util,0], forwards))
 
#     print("Defence: ", num_util)
#     defence_sols.append(choose_roster([], [0,0,0,4,num_util,0], defence))
 
# print("Goalies")
# goalie_sols = choose_roster([], [0,0,0,0,0,2], goalies)
 
# for num_util in range(3):
#     print("Forward util positions: ", num_util, "  -  Defence util positions: ", 2-num_util)
 
#     forward_choice = forward_sols[num_util]
#     defence_choice = defence_sols[2-num_util]
 
#     print("    Forward Points: ", forward_choice[0])
#     print("    Defence Points: ", defence_choice[0])
#     print("    Goalie  Points: ", goalie_sols[0])
#     print("    Total Points: ", forward_choice[0]+defence_choice[0]+goalie_sols[0])
#     print("        Player Choices: ", forward_choice[1], defence_choice[1], goalie_sols[1])
 
 
# chosen_list = choose_roster([], POS_MAX, players)
# print(chosen_list)