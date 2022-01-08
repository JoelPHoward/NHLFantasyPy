from datetime import timedelta, datetime, date as sysDate
import requests
import rapidjson
import time
import pandas as pd
import numpy as np
import asyncio
import aiohttp
import re
import numba
import os
import shutil
from termcolor import cprint
import psycopg2
from io import StringIO
from tabulate import tabulate

text_col1 = 'green'
text_col2 = 'yellow'
text_col3 = 'red'
locations = pd.DataFrame(data = {'state_prov': ['New Jersey', 'New York', 'New York', 'Pennsylvania', 'Pennsylvania', 'Massachusetts', 'New York', 'Quebec', 'Ontario', 'Ontario', 'North Carolina', 'Florida', 'Florida', 'District of Columbia', 'Illinois', 'Michigan', 'Tennessee', 'Missouri', 'Alberta', 'Colorado', 'Alberta', 'British Colombia', 'California', 'Texas', 'California', 'California', 'Ohio', 'Minnesota', 'Manitoba', 'Arizona', 'Nevada', 'Washington'], 
	'country': ['USA', 'USA', 'USA', 'USA', 'USA', 'USA', 'USA', 'CAN', 'CAN', 'CAN', 'USA', 'USA', 'USA', 'USA', 'USA', 'USA', 'USA', 'USA', 'CAN', 'USA', 'CAN', 'CAN', 'USA', 'USA', 'USA', 'USA', 'USA', 'USA', 'CAN', 'USA', 'USA', 'USA']})


PARAMETERS_TO_SCRAPE = rapidjson.load(open('/Users/joelhoward/repos/NHLFantasyPy/Scrape/parameters_to_scrape.json'))
FANPT_PARAMS = rapidjson.load(open('/Users/joelhoward/repos/NHLFantasyPy/Scrape/fanpt_parameters.json'))

historical = pd.read_csv('/Users/joelhoward/repos/NHLFantasyPy/data/historical_player_ids.csv')
historical_ids = [i[0] for i in historical.values]
historical_names = [i[1] for i in historical.values]

def print_colour(x, colour, end = "\n"):
	cprint(x, colour, end = end)

def progbar(curr, total, full_progbar):
	frac = curr/total
	filled_progbar = round(frac*full_progbar)
	x = '\r' + '#'*filled_progbar + '-'*(full_progbar-filled_progbar) + '[{:>7.2%}]'.format(frac)
	print_colour(x, colour = "green", end = "")

def dateToSplit(date = None):
	if date == None:
		date = sysDate.today()
	date = str(date).split("-")
	year = int(date[0])
	month = int(date[1])
	if month >= 10 and month <= 12:
		split = int(str(year) + str(year + 1))
	else:
		split = int(str(year - 1) + str(year))
	return split

def getTeamIDs(team):
	return {"id": team["id"], "name": team["name"]}

def getTeamLocations(nhl_teams):
	team_ids = [0]*len(nhl_teams)
	team_ids = pd.DataFrame(map(getTeamIDs, nhl_teams))
	team_locations = pd.concat([team_ids.reset_index(drop=True), locations], axis=1)
	return team_locations

def getNHLTeamInfo(teams = None, verbose = False):
	nhl_teams = rapidjson.loads(requests.get("https://statsapi.web.nhl.com/api/v1/teams").text)["teams"]
	team_locations = getTeamLocations(nhl_teams)
	teamInfo_df = pd.DataFrame(index = range(len(nhl_teams)), columns = ("team_id", "team_name", "city", "state_prov", "country", "division", "conference"))
	for i in range(len(nhl_teams)):
		teamInfo_df.iloc[i] = [nhl_teams[i]["id"], nhl_teams[i]["name"], nhl_teams[i]["locationName"], team_locations.iloc[i]["state_prov"], team_locations.iloc[i]["country"], nhl_teams[i]["division"]["name"], nhl_teams[i]["conference"]["name"]]
	if teams is not None:
		if len(teams) > 1:
			teamInfo_df = teamInfo_df[teamInfo_df["id"].isin(teams)]
		else:
			teamInfo_df = teamInfo_df[teamInfo_df["id"] == teams]
	return teamInfo_df

async def getCurrentRosters(team_ids, verbose = False):
	async with aiohttp.ClientSession() as session:
		rosters = await asyncio.gather(*[fetch(session = session, url = "https://statsapi.web.nhl.com/api/v1/teams/" + str(i) + "?expand=team.roster") for i in team_ids])
	rosters = [rapidjson.loads(r)["teams"][0]["roster"]["roster"] for r in rosters]
	return rosters

def getPlayerIds(nhl_rosters):
	ids = []
	names = []
	for i in range(len(nhl_rosters)):
		for j in range(len(nhl_rosters[i])):
			ids.append(nhl_rosters[i][j]["person"]["id"])
			names.append(nhl_rosters[i][j]["person"]["fullName"])
	for i in range(len(historical_ids)):
		if historical_ids[i] not in ids:
			ids.append(historical_ids[i])
			names.append(historical_names[i])
	return pd.DataFrame(data = {"player_id": ids, "name": names[i]})

def makePlayerInfoDf(player):
	keys = list(player.keys())
	
	if "shootsCatches" in keys:
		shoots_catches = player["shootsCatches"]
	else:
		shoots_catches = "U"
	if "birthCity" in keys:
		birth_city = player["birthCity"]
		if len(re.findall(',',birth_city)) > 0:
			if len(re.findall(', ',birth_city)) > 0:
				birth_city = re.sub(', ', '-', birth_city)
			else:
				birth_city = re.sub(',', '-', birth_city)
	else:
		birth_city = "UNK"
	if "birthStateProvince" in keys:
		birth_sp = player["birthStateProvince"]
	else:
		birth_sp = "OTHER"
	if "nationality" in keys:
		nationality = player["nationality"]
	elif "birthCountry" in keys:
		nationality = player["birthCountry"]
	else:
		nationality = "UNK"
	if player["active"]:
		team_id = player["currentTeam"]["id"]
		team_name = player["currentTeam"]["name"]
	else:
		team_id = 0
		team_name = "None"
	if "alternateCaptain" in keys:
		alternateCaptain = player["alternateCaptain"]
	else:
		alternateCaptain = False
	if "captain" in keys:
		captain = player["captain"]
	else:
		captain = False
	if "height" in keys:
		height = float(player["height"].replace('"',"").replace("'","").replace(" ","."))
	else:
		height = 0.0
	if "weight" in keys:
		weight = player["weight"]
	else:
		weight = 0.0
	return {"player_id": player["id"], "first_name": player["firstName"], \
	"last_name": player["lastName"], "name": player["firstName"] + " " + player["lastName"], \
	"position": player["primaryPosition"]["abbreviation"], "shoots_catches": shoots_catches, \
	"birth_city": birth_city, \
	"birth_sp": birth_sp, "nationality": nationality, \
	"height": height, \
	"weight": weight, "active": player["active"], \
	"rookie": player["rookie"], "alternate_captain": alternateCaptain, \
	"captain": captain, "status": player["rosterStatus"], \
	"team_id": team_id, "team_name": team_name, \
	"birth_date": player["birthDate"]}

async def getNHLPlayerInfo(player_ids, verbose = False):
	async with aiohttp.ClientSession() as session:
		nhl_players = await asyncio.gather(*[fetch(session = session, url = "https://statsapi.web.nhl.com/api/v1/people/" + str(i)) for i in player_ids])
	nhl_players = [rapidjson.loads(p)["people"][0] for p in nhl_players]
	player_info = pd.DataFrame(data = map(makePlayerInfoDf, nhl_players))
	player_info.index = player_info["player_id"]
	return player_info

def getSplits(from_year, to_year):
	years = range(from_year, to_year+1)
	splits = []
	for year in years:
		splits.append(str(year) + str(year+1))
	return splits

async def fetch(session, url):
	async with session.get(url) as response:
		return await response.text()

async def append_id(session, id, split, position):
	raw = await fetch(session , url = "https://statsapi.web.nhl.com/api/v1/people/" + str(id) + "/stats?stats=gameLog&season=" + str(split))
	json = rapidjson.loads(raw)["stats"][0]["splits"]
	if json is dict:
		json = list(json)
	for i in range(len(json)):
		if json[i] != []:
			json[i]["player_id"] = id
			json[i]["position"] = position
			json[i]["split"] = split
	if json == []:
		return None
	else:
		return json

async def getGameLogs(ids, splits, player_info, dates = None):
	async with aiohttp.ClientSession() as session:
		player_logs_raw = await asyncio.gather(*[append_id(session = session, id = id, split = split, position = player_info.loc[id]["position"]) for id in ids for split in splits])
	if dates is not None:
		player_logs = []
		for logs in player_logs_raw:
			add_logs = []
			for game in logs:
				if game["date"] in dates:
					add_logs.append(game)
			player_logs.append(add_logs)
	else:
		player_logs = player_logs_raw
	player_logs = [logs for logs in player_logs if logs != []]
	return player_logs

async def getBoxScores(game_feeds):
	async with aiohttp.ClientSession() as session:
		data = await asyncio.gather(*[fetch(session = session, url = "https://statsapi.web.nhl.com" + game) for game in game_feeds])
	data_json = []
	err = []
	for i in range(len(data)):
		try:
			data_json.append(rapidjson.loads(data[i])['liveData']['boxscore']["teams"])
		except:
			err.append(i)
			game_feeds.pop(i)
	game_keys = [re.search("(?<=game\/)(.*)(?=\/feed)", x).string for x in game_feeds]
	data_dict = {}
	for i in range(len(game_feeds)):
		data_dict[game_keys[i]] = data_json[i]
	return data_dict, err

def home_away(x):
	if x:
		return "home"
	else:
		return "away"

def getFaceOffWins(games, boxscores):
	# faceoff wins only recorded after 1997-10-01
	fws = []
	for game in games:
		x = re.search("(?<=game\/)(.*)(?=\/feed)", game[0]).string
		if x in boxscores.keys():
			player_stats = boxscores[x][game[1]]["players"]
			if "ID" + str(game[2]) in player_stats.keys():
				if "skaterStats" in player_stats["ID" + str(game[2])]["stats"].keys():
					fws.append(player_stats["ID" + str(game[2])]["stats"]["skaterStats"]["faceOffWins"])
				else:
					fws.append(0)
			else:
				fws.append(0)
		else:
			fws.append(0)
	return fws

def stat_df(game_logs, df_keys, fws, file_name):
	text_file = open(file_name, "a")
	for i in range(len(df_keys)):
		text_file.write(str(df_keys[i]))
		if(i < len(df_keys) - 1):
			text_file.write(",")
	text_file.write("\n")
	for i in range(len(game_logs)):
		info = [
			game_logs[i]["split"],
			game_logs[i]["date"],
			game_logs[i]["game"]["gamePk"],
			game_logs[i]["player_id"],
			game_logs[i]["position"],
			game_logs[i]["team"]["id"],
			game_logs[i]["opponent"]["id"],
			game_logs[i]["isHome"],
			game_logs[i]["isWin"],
			game_logs[i]["isOT"],
			fws[i]
		]
		for j in df_keys[11:]:
			if j in list(game_logs[i]["stat"].keys()):
				info.append(game_logs[i]["stat"][j])
			else:
				info.append(0)
		for j in range(len(info)):
			text_file.write(str(info[j]))
			if(j < len(info) - 1):
				text_file.write(",")
		if(i < len(game_logs) - 1):
			text_file.write(",")
		text_file.write("\n")
		progbar(i, len(game_logs)-1, 100)
	print('\n')
	text_file.close()

def calc_fanpts(x):
	fanpts = 0
	for p in list(FANPT_PARAMS.keys()):
		fanpts += FANPT_PARAMS[p] * x[p]
	if x['position'] != "G" and x['isWin'] is True:
		fanpts -= 3
	return fanpts

def data_scrape(from_year = None, to_year = None, teams = None, players = None, do_update = False, from_date = None, keep_tmp = False, verbose = True):
	loop = asyncio.get_event_loop()
	if verbose:
		if teams is None:
			print_colour("Fetching information for all teams...", colour = text_col1, end = "\n")
		else:
			print_colour("Fetching information for specified teams...", colour = text_col1, end = "\n")
	team_info = getNHLTeamInfo(teams = teams, verbose = verbose)
	if verbose:
		print_colour("Fetching team rosters...", colour = text_col1, end = "\n")
	rosters = loop.run_until_complete(getCurrentRosters(team_ids = team_info["team_id"], verbose = verbose))
	if verbose:
		print_colour("Extracting specified players on all rosters...", colour = text_col1, end = "\n")
	player_ids = getPlayerIds(rosters)
	if players is not None:
		player_ids = player_ids[player_ids["player_id"].isin(players)]
	if verbose:
		print_colour("Fetching player information...", colour = text_col1, end = "\n")
	player_info = loop.run_until_complete(getNHLPlayerInfo(list(player_ids["player_id"]), verbose = verbose))
	dates = None
	if do_update:
		if from_date is not None:
			prev_day = sysDate.today() - timedelta(days = 1)
			if from_date == prev_day:
				print_colour("Data is already up to date.", colour = text_col2, end = "\n")
				exit()
			if verbose:
				print_colour("Getting game dates since last update...", colour = text_col1, end = "")
			schedule = rapidjson.loads(requests.get("https://statsapi.web.nhl.com/api/v1/schedule?startDate=" + str(from_date + timedelta(days = 1)) + "&endDate=" + str(prev_day + timedelta(days = 1)) + "&gameType=R").text)["dates"]
			dates = pd.Series([datetime.strptime(x["date"], '%Y-%m-%d').date() for x in schedule])
			n_games = pd.Series([x["totalGames"] for x in schedule])
			idx = dates <= prev_day
			dates = list(dates[idx])
			n_games = sum(n_games[idx])
			assert isinstance(dates, list) and len(dates) > 0, "dates should be a list with > 0 elements" 
			all_splits = [dateToSplit(date) for date in dates]
			splits = []
			for split in all_splits:
				if split not in splits:
					splits.append(split)
			dates = [datetime.strftime(date, '%Y-%m-%d') for date in dates]
			if verbose:
				# would be nice to also print a table that has info on all of these games || date | game_id | Team_1 name (record) - score | Team_2 name (record) - score ||
				print_colour(str(n_games) + " games found since last update (between " + str(from_date + timedelta(days = 1)) + " and " + str(prev_day) + ").", colour = text_col1, end = "\n")
				game_res = [(i['date'], str(j['teams']['home']['team']['name']) + " (" + str(j['teams']['home']['leagueRecord']['wins']) + "-" + str(j['teams']['home']['leagueRecord']['losses']) + "-" + str(j['teams']['home']['leagueRecord']['ot']) + ")", j['teams']['home']['score'], str(j['teams']['away']['team']['name']) + " (" + str(j['teams']['away']['leagueRecord']['wins']) + "-" + str(j['teams']['away']['leagueRecord']['losses']) + "-" + str(j['teams']['away']['leagueRecord']['ot']) + ")", j['teams']['away']['score']) for i in schedule[0:len(idx[idx==True])] for j in i['games']]
				print_colour(tabulate(game_res, headers=['Date', 'Home Team','Score','Away Team','Score'], tablefmt = 'fancy_grid'), colour = text_col1, end = "\n")
		else:
			print_colour("ERROR: If you want to update Game Logs, you need to provide from_date (the most recent date in the data to be updated).", colour = text_col2, end = "\n")
			exit()
	else:
		splits = getSplits(from_year = from_year, to_year = to_year)
	if isinstance(splits, int):
		splits = [splits]
	tmp_dir = "tmp_"
	for i in np.random.choice(range(9),15):
		tmp_dir += str(i)
	os.mkdir(tmp_dir)
	df_keys = list(PARAMETERS_TO_SCRAPE.keys())
	if verbose:
		print_colour("Getting Game Logs:", colour = text_col1, end = "\n")
	for s in range(len(splits)):
		curr_file = "chunk_" + str(s+1) + "_of_" + str(len(splits)) + ".csv"
		if verbose:
			print_colour("Chunk " + str(s + 1) + "/" + str(len(splits)) + "...", colour = text_col1, end = "\n")
		game_logs = loop.run_until_complete(getGameLogs(ids = player_ids["player_id"], splits = [splits[s]], player_info = player_info, dates = dates))
		if verbose:
			print_colour("Getting Boxscores...", colour = text_col1, end = "\n")
		player_input = [[game["game"]["link"], home_away(game["isHome"]), game["player_id"]] for split in game_logs if split is not None for game in split]
		game_feeds = []
		for i in player_input:
			if i[0] not in game_feeds:
				game_feeds.append(i[0])
		loop = asyncio.get_event_loop()
		boxscores, err = loop.run_until_complete(getBoxScores(game_feeds))
		if verbose:
			print_colour("Compiling stats...", colour = text_col1, end = "\n")
		if len(err) > 0:
			for index in sorted(boxscores[1], reverse=True):
				del player_input[index]
		if int(splits[s]) > 19981999:
			fws = getFaceOffWins(player_input, boxscores)
		else:
			fws = [0]*len(player_input)
		game_logs_exp = []
		for i in game_logs:
			if type(i) is list:
				for j in i:
					game_logs_exp.append(j)
			elif i is not None:
				game_logs_exp.append(i)
		del game_logs
		stat_df(game_logs = game_logs_exp, df_keys = df_keys, fws = fws, file_name = os.path.join(tmp_dir, curr_file))
	df = pd.read_csv(
			os.path.join(tmp_dir, "chunk_1_of_" + str(len(splits)) + ".csv"), 
			index_col=False, 
			dtype = PARAMETERS_TO_SCRAPE
		)
	df["date"] = pd.to_datetime(df["date"]) 
	for s in range(1,len(splits)):
		curr_file = "chunk_" + str(s+1) + "_of_" + str(len(splits)) + ".csv"
		df_tmp = pd.read_csv(
					os.path.join(tmp_dir, curr_file), 
					index_col=False, 
					dtype = PARAMETERS_TO_SCRAPE
				)
		df_tmp["date"] = pd.to_datetime(df_tmp["date"]) 
		df = df.append(df_tmp)
	if verbose:
		print_colour("Calculating Fantasy Points...", colour = text_col1, end = "\n")
	df["fanpts"] = list(df.apply(calc_fanpts, 1))
	if keep_tmp is False:
		shutil.rmtree(tmp_dir)
	if verbose:
		print_colour("DONE.", colour = text_col1, end = "\n")
	return df, player_info, team_info

def copy_from_stringio(conn, df, table):
	# save dataframe to an in memory buffer
	buffer = StringIO()
	df.to_csv(buffer, index = False, header=False)
	buffer.seek(0)
	cur = conn.cursor()
	try:
		cur.copy_from(buffer, table, sep=",")
		conn.commit()
	except (Exception, psycopg2.DatabaseError) as error:
		print("Error: %s" % error)
		conn.rollback()
		cur.close()
		return 1

def update_postgres():
	PSQL_CREDENTIALS = rapidjson.load(open('/Users/joelhoward/repos/NHLFantasyPy/PSQL_CREDENTIALS.json'))
	conn = psycopg2.connect("dbname=" + PSQL_CREDENTIALS['dbname'] + " user=" + PSQL_CREDENTIALS['user'] +  " password=" + PSQL_CREDENTIALS['password'])
	cur = conn.cursor()
	cur.execute("SELECT date FROM game_logs;")
	from_date = max([d[0] for d in cur.fetchall()])
	game_logs, player_info, team_info = data_scrape(do_update = True, from_date = from_date)
	copy_from_stringio(conn, game_logs, 'game_logs')
	cur.execute("SELECT player_id FROM player_info;")
	ids = [id[0] for id in cur.fetchall()]
	new_ids = []
	for id in list(player_info['player_id']):
		if id not in ids:
			new_ids.append(id)
	if len(new_ids) > 0:
		copy_from_stringio(conn, player_info[player_info['player_id'].isin(new_ids)], 'player_info')
	cur.execute("DELETE FROM team_info;")
	copy_from_stringio(conn, team_info, 'team_info')
	conn.commit()
	cur.close()
	conn.close()
