import xml.etree.ElementTree as ET
import pandas as pd
import rapidjson
import re
import psycopg2
from YahooAPI.yahoo_connect import YahooCon
import unidecode

YAHOO_CREDENTIALS = rapidjson.load(open('/Users/joelhoward/repos/NHLFantasyPy/YAHOO_CREDENTIALS.json'))
PSQL_CREDENTIALS = rapidjson.load(open('/Users/joelhoward/repos/NHLFantasyPy/PSQL_CREDENTIALS.json'))

yahoo = YahooCon(
	access_token = YAHOO_CREDENTIALS['access_token'], 
	refresh_token =  YAHOO_CREDENTIALS['refresh_token'], 
	client_id = YAHOO_CREDENTIALS['client_id'], 
	client_secret = YAHOO_CREDENTIALS['client_secret'], 
	league_id = YAHOO_CREDENTIALS['league_id']
	)

teams = yahoo.get_teams()

date_1 = '2021-01-13'
date_2 = '2021-04-11'

conn = psycopg2.connect("dbname=" + PSQL_CREDENTIALS['dbname'] + " user=" + PSQL_CREDENTIALS['user'] +  " password=" + PSQL_CREDENTIALS['password'])

query = "SELECT c.*, COALESCE(d.fanpts, 0) AS fanpts \
FROM \
(SELECT b.player_id, player_info.name AS player_name, b.team_id, b.team_name \
FROM \
(SELECT a.player_id, a.team_id, team_info.name AS team_name \
FROM \
(SELECT DISTINCT ON (player_id) date, player_id, team_id \
FROM game_logs \
ORDER BY player_id, date DESC) AS a \
JOIN team_info ON a.team_id = team_info.team_id) AS b \
JOIN player_info ON b.player_id = player_info.player_id) AS c \
LEFT JOIN \
(SELECT  player_id, SUM(fanpts) AS fanpts \
 FROM game_logs \
 WHERE date >= '" + date_1 + "' AND date <= '" + date_2 + "' \
 GROUP BY player_id \
) AS d ON c.player_id = d.player_id;"

fanpt_df = pd.read_sql_query(sql = query, con = conn)

fanpt_df['player_name'] = [unidecode.unidecode(pn.lower()) for pn in fanpt_df['player_name']]
fanpt_df['team_name'] = [unidecode.unidecode(pn.lower()) for pn in fanpt_df['team_name']]

fanpt_df['player_name'][fanpt_df['player_name'] == 'tim stutzle'] = 'tim stuetzle'

conn.close()

draft_results = ET.fromstring(yahoo.endpoint_xml('https://fantasysports.yahooapis.com/fantasy/v2/league/nhl.l.17580/draftresults')).find(yahoo.namespace + 'league').find(yahoo.namespace + 'draft_results')

df = pd.DataFrame(columns=['pick', 'round', 'team_key', 'team_name', 'player_key', 'player_name', 'player_team', 'fanpts'])
for draf_result in draft_results:
	pick = draf_result.find(yahoo.namespace + 'pick').text
	round = draf_result.find(yahoo.namespace + 'round').text
	team_key = draf_result.find(yahoo.namespace + 'team_key').text
	player_key = draf_result.find(yahoo.namespace + 'player_key').text
	team_name = teams['name'][teams['id'] == re.sub(r'403.l.17580.t.', '', team_key)].iloc[0]
	player = ET.fromstring(yahoo.con.get('https://fantasysports.yahooapis.com/fantasy/v2/player/' + player_key).text)[0]
	player_name = player.find(yahoo.namespace + 'name').find(yahoo.namespace + 'full').text
	player_team = player.find(yahoo.namespace + 'editorial_team_full_name').text
	try:
		fanpts = fanpt_df['fanpts'][(fanpt_df['player_name'] == unidecode.unidecode(player_name.lower())) & (fanpt_df['team_name'] == player_team.lower())].iloc[0]
	except:
		print('Error at: ' + player_name)
		fanpts = 0
	df = df.append(pd.Series({'pick': pick, 'round': round, 'team_key': team_key, 'team_name': team_name,'player_key': player_key, 'player_name': player_name, 'player_team': player_team, 'fanpts': fanpts}), ignore_index = True)






